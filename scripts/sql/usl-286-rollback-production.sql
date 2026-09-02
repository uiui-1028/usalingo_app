-- USL-286: 本番へ投入した50語を取り消す。
--
-- 対象は固定ID帯だけ。ほかのデッキ・単語には触らない。
--   decks             id = 286
--   words             id 1001-1050  (word_meanings / example_contents / example_audio /
--                                    word_pronunciations / word_forms / word_relations は CASCADE で消える)
--   deck_words/cards  deck_id = 286
--
-- 実行前に、投入手順書 docs/operations/import-official-content-production.md の
-- 「切り戻し」節を読むこと。1トランザクションで、途中で止まれば何も消えない。
--
-- 利用者データの扱い:
--   user_card_progress.card_id -> cards は RESTRICT。誰かが学習していれば下の番人で停止する。
--   user_word_overrides / user_word_tags -> words は CASCADE。個人の上書きとタグが
--   黙って消えるため、こちらも番人で停止する。
--   どちらも、消してよいと判断できたときだけ、対象を明示して別途承認を得てから外す。

begin;

do $$
declare
  progress_rows bigint;
  override_rows bigint;
  tag_rows bigint;
begin
  select count(*) into progress_rows
  from public.user_card_progress p
  join public.cards c on c.id = p.card_id
  where c.deck_id = 286;

  select count(*) into override_rows
  from public.user_word_overrides
  where word_id between 1001 and 1050;

  select count(*) into tag_rows
  from public.user_word_tags
  where word_id between 1001 and 1050;

  if progress_rows > 0 then
    raise exception
      'USL-286 rollback stopped: % user_card_progress rows depend on deck 286. Deleting user learning history needs separate approval.',
      progress_rows;
  end if;

  if override_rows > 0 or tag_rows > 0 then
    raise exception
      'USL-286 rollback stopped: % user_word_overrides and % user_word_tags rows would be cascade-deleted. Deleting user data needs separate approval.',
      override_rows, tag_rows;
  end if;
end
$$;

-- cards は decks/words に対して RESTRICT なので先に消す。
delete from public.cards where deck_id = 286;
delete from public.deck_words where deck_id = 286;

-- words を消すと、意味・例文・例文音声・発音・活用・関連が CASCADE で消える。
delete from public.words where id between 1001 and 1050;

delete from public.decks where id = 286;

-- 消え残りがないことを、コミット前に確かめる。
do $$
declare
  leftover bigint;
begin
  select
    (select count(*) from public.decks where id = 286)
  + (select count(*) from public.words where id between 1001 and 1050)
  + (select count(*) from public.word_meanings where id between 2001 and 2510)
  + (select count(*) from public.example_contents where id between 3001 and 3050)
  + (select count(*) from public.word_pronunciations where id between 4001 and 4050)
  + (select count(*) from public.example_audio where id between 5001 and 5050)
  + (select count(*) from public.deck_words where deck_id = 286)
  + (select count(*) from public.cards where deck_id = 286)
  into leftover;

  if leftover <> 0 then
    raise exception 'USL-286 rollback incomplete: % rows remain', leftover;
  end if;
end
$$;

commit;

-- Storageの150 objectはこのSQLでは消えない。必要な場合は
-- /private/tmp/usalingo-288-paths.json の一覧を示して別途承認を得る。
