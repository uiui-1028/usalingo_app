-- USL-308 シート同期に必要な列・権限・外部キーと、古いトリガーが無いことを固定する。

begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select has_column('public', 'word_meanings', 'related', 'word_meanings has related');
select col_type_is('public', 'word_meanings', 'related', 'text[]', 'related is text[]');
select ok(
  has_column_privilege('authenticated', 'public.word_meanings', 'related', 'select')
    and has_column_privilege('authenticated', 'public.cards', 'primary_meaning_id', 'select'),
  'the app can read related and primary_meaning_id'
);

select is_empty(
  $$select trigger_name from information_schema.triggers
    where event_object_schema = 'public'
      and action_statement ilike any (array[
        '%asset_linking_corrected%', '%set_asset_path_immediate%', '%queue_asset_verification%'
      ])$$,
  'legacy asset path triggers are gone'
);

insert into public.words (word_text) values ('usl-308-a'), ('usl-308-b');

insert into public.word_meanings (word_id, priority, part_of_speech_en, definition_jp)
select id, 1, 'noun', word_text from public.words where word_text in ('usl-308-a', 'usl-308-b');

insert into public.decks (deck_name) values ('usl-308-deck');

insert into public.cards (word_id, card_template_id, deck_id, sort_order)
select word.id, (select min(id) from public.card_templates), deck.id, 0
from public.words as word, public.decks as deck
where word.word_text = 'usl-308-a' and deck.deck_name = 'usl-308-deck';

select lives_ok(
  $$update public.cards
    set primary_meaning_id = (
      select meaning.id from public.word_meanings meaning
      join public.words word on word.id = meaning.word_id
      where word.word_text = 'usl-308-a'
    )
    where deck_id = (select id from public.decks where deck_name = 'usl-308-deck')$$,
  'a card can point to a meaning of its own word'
);

select throws_ok(
  $$update public.cards
    set primary_meaning_id = (
      select meaning.id from public.word_meanings meaning
      join public.words word on word.id = meaning.word_id
      where word.word_text = 'usl-308-b'
    )
    where deck_id = (select id from public.decks where deck_name = 'usl-308-deck')$$,
  '23503',
  null,
  'a card cannot point to a meaning of another word'
);

select lives_ok(
  $$insert into public.word_meanings (word_id, priority, part_of_speech_en, definition_jp, related)
    select id, 2, 'noun', 'related check', array['invent :: 発明する', 'design :: 設計する']
    from public.words where word_text = 'usl-308-a'$$,
  'related accepts a list of "word :: translation" items'
);

select * from finish();

rollback;
