-- USL-286: 手作業で入れた 51-1000 の950語を本番から消す。
--
-- 残すもの: words.id 1-50（2026-09-04に正本JSONへ差し替えた50語）とその学習履歴。
-- 消すもの: words.id 51-1000 と、そこにぶら下がる意味・例文・音声・カード・
--           デッキ紐付け、そして その950語についた学習履歴。
--
-- 権利者の判断:
--   「残り950語は削除して。原本は他にあるからいつでも復元できる」
--   「その単語についた学習履歴は基本的にテストのものです。削除して良い」
--
-- 単語の中身はAnki原本から作り直せるが、学習履歴（いつ・どれくらい覚えたか）は
-- Ankiに無いため戻せない。テストデータであることを確認したうえで消している。
--
-- Storageのファイルはこのスクリプトでは消えない。DBを消したあとに未参照となる
-- objectを別途まとめて削除する。

begin;

do $$
declare
  target_words bigint;
  keep_words bigint;
  keep_progress bigint;
begin
  select count(*) into target_words from public.words where id between 51 and 1000;
  select count(*) into keep_words from public.words where id between 1 and 50;
  select count(*) into keep_progress
  from public.user_card_progress p join public.cards c on c.id = p.card_id
  where c.word_id between 1 and 50;

  if target_words <> 950 then
    raise exception 'USL-286 delete stopped: expected 950 words in 51-1000, found %.', target_words;
  end if;
  -- 残す50語がそろっていること。ここが欠けていたら、消す前に止める。
  if keep_words <> 50 then
    raise exception 'USL-286 delete stopped: words 1-50 should be 50 rows, found %.', keep_words;
  end if;
  raise notice 'keeping % learning-progress rows on words 1-50', keep_progress;
end
$$;

-- user_card_progress -> cards は RESTRICT なので、カードより先に消す。
delete from public.user_card_progress p
using public.cards c
where c.id = p.card_id and c.word_id between 51 and 1000;

-- cards は decks/words に対して RESTRICT。words より先に消す。
delete from public.cards where word_id between 51 and 1000;
delete from public.deck_words where word_id between 51 and 1000;

-- words を消すと、意味・例文・例文音声・発音・活用・関連が CASCADE で消える。
delete from public.words where id between 51 and 1000;

do $$
declare
  leftover bigint;
  kept_words bigint;
  kept_progress bigint;
begin
  select
    (select count(*) from public.words where id between 51 and 1000)
  + (select count(*) from public.word_meanings where word_id between 51 and 1000)
  + (select count(*) from public.word_pronunciations where word_id between 51 and 1000)
  + (select count(*) from public.cards where word_id between 51 and 1000)
  + (select count(*) from public.deck_words where word_id between 51 and 1000)
  into leftover;
  if leftover <> 0 then
    raise exception 'USL-286 delete incomplete: % rows remain', leftover;
  end if;

  -- 残すはずのものが巻き込まれていないこと。
  select count(*) into kept_words from public.words where id between 1 and 50;
  select count(*) into kept_progress
  from public.user_card_progress p join public.cards c on c.id = p.card_id
  where c.word_id between 1 and 50;
  if kept_words <> 50 then
    raise exception 'USL-286 delete damaged the kept words: % remain, expected 50', kept_words;
  end if;
  if kept_progress = 0 then
    raise exception 'USL-286 delete removed the learning history of the kept words';
  end if;
end
$$;

commit;
