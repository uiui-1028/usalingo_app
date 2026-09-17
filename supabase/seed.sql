-- Local-only sample content. No production data, credentials, or user records.

with inserted_word as (
  insert into public.words (word_text)
  values ('local-example')
  returning id
),
inserted_meaning as (
  insert into public.word_meanings (
    word_id,
    priority,
    part_of_speech_en,
    definition_jp
  )
  select id, 1, 'noun', 'ローカル検証用の例'
  from inserted_word
  returning id, word_id
),
inserted_example as (
  insert into public.example_contents (
    meaning_id,
    theme,
    sentence_en,
    sentence_jp
  )
  select id, 'simple', 'This is local test data.', 'これはローカルのテストデータです。'
  from inserted_meaning
  returning id
),
inserted_deck as (
  insert into public.decks (
    deck_name,
    description,
    source_list_name,
    license
  )
  values (
    'Local Verification Deck',
    'USL-222 local-only seed',
    'synthetic',
    'test-only'
  )
  returning id
)
insert into public.cards (
  word_id,
  card_template_id,
  deck_id,
  sort_order,
  is_active
)
select
  inserted_meaning.word_id,
  card_templates.id,
  inserted_deck.id,
  0,
  true
from inserted_deck
cross join inserted_meaning
join public.card_templates
  on card_templates.template_code = 'basic_en_to_ja'
on conflict (word_id, card_template_id, deck_id)
do update set
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();
