-- シート → Supabase の同期（USL-308）に必要な形をそろえる。
-- 使い方: docs/operations/sync-sheet-to-supabase.md

-- 1. 古い自動パス付与トリガーを外す。
--    本番だけに残っていた（migration には無い）。存在しない列 illustration_asset_path へ書くため、
--    例文を新しく入れると失敗する。意味を入れるたびに、Storageに無い
--    content-audio/audio_meaning_<id>.mp3 を audio_asset_path へ書いていた。
--    パスはシートと同期が決める（docs/decisions/audio-path-built-by-import-20260915.md）。
drop trigger if exists trigger_example_contents_asset_linking_corrected on public.example_contents;
drop trigger if exists trigger_example_contents_set_path_immediate on public.example_contents;
drop trigger if exists trigger_example_contents_queue_verification on public.example_contents;
drop trigger if exists trigger_word_meanings_asset_linking_corrected on public.word_meanings;
drop trigger if exists trigger_word_meanings_set_path_immediate on public.word_meanings;
drop trigger if exists trigger_word_meanings_queue_verification on public.word_meanings;

-- 2. 関連語。01_core_senses.related を ` /&/ ` で区切って入れる。
alter table public.word_meanings
  add column if not exists related text[];

grant select (related) on public.word_meanings to authenticated;

comment on column public.word_meanings.related is
  'Related words from 01_core_senses.related. Each item is "word :: translation :: note".';

-- 3. デッキごとの主の意味（docs/decisions/deck-primary-sense-20260914.md）。
--    カードの単語の意味しか指せないよう、(id, word_id) への外部キーで止める。
alter table public.word_meanings
  add constraint word_meanings_id_word_id_key unique (id, word_id);

alter table public.cards
  add column if not exists primary_meaning_id integer;

update public.cards as card
set primary_meaning_id = (
  select meaning.id
  from public.word_meanings as meaning
  where meaning.word_id = card.word_id
  order by meaning.priority, meaning.id
  limit 1
)
where card.primary_meaning_id is null;

alter table public.cards
  add constraint cards_primary_meaning_belongs_to_word
  foreign key (primary_meaning_id, word_id)
  references public.word_meanings (id, word_id);

grant select (primary_meaning_id) on public.cards to authenticated;

comment on column public.cards.primary_meaning_id is
  'Primary sense shown large on this card. Set from 04_deck_words.sense_id; null falls back to the lowest priority.';
