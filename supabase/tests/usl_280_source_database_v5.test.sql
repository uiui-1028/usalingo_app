-- USL-280 V5原本の配信用構造と既存SwiftUI互換を固定する。

begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

select ok(to_regclass('public.content_concepts') is not null, 'content_concepts exists');
select ok(to_regclass('public.word_pronunciations') is not null, 'word_pronunciations exists');
select ok(to_regclass('public.example_audio') is not null, 'example_audio exists');
select ok(to_regclass('public.word_forms') is not null, 'word_forms exists');
select ok(to_regclass('public.word_relations') is not null, 'word_relations exists');

select results_eq(
  $$select count(*) from information_schema.columns
    where table_schema = 'public'
      and table_name = 'words'
      and column_name in ('source_note_guid', 'source_deck_code', 'source_position')$$,
  array[3::bigint],
  'words stores stable source identity and order'
);

select results_eq(
  $$select count(*) from public.content_concepts where concept_code = 'simple'$$,
  array[1::bigint],
  'simple concept exists exactly once'
);

select results_eq(
  $$select count(*) from public.example_contents
    where concept_id is not null and image_state is not null and display_order = 1$$,
  array[(select count(*) from public.example_contents)],
  'all seeded examples have V5 fields'
);

select results_eq(
  $$select count(*) from pg_class
    where oid in (
      'public.content_concepts'::regclass,
      'public.word_pronunciations'::regclass,
      'public.example_audio'::regclass,
      'public.word_forms'::regclass,
      'public.word_relations'::regclass
    ) and relrowsecurity$$,
  array[5::bigint],
  'RLS is enabled on every new official-content table'
);

select ok(
  not has_table_privilege('anon', 'public.content_concepts', 'select')
    and not has_table_privilege('anon', 'public.word_pronunciations', 'select')
    and not has_table_privilege('anon', 'public.example_audio', 'select')
    and not has_table_privilege('anon', 'public.word_forms', 'select')
    and not has_table_privilege('anon', 'public.word_relations', 'select'),
  'anon cannot read V5 official content'
);

select ok(
  has_table_privilege('authenticated', 'public.content_concepts', 'select')
    and has_table_privilege('authenticated', 'public.word_pronunciations', 'select')
    and has_table_privilege('authenticated', 'public.example_audio', 'select')
    and has_table_privilege('authenticated', 'public.word_forms', 'select')
    and has_table_privilege('authenticated', 'public.word_relations', 'select'),
  'authenticated can read V5 official content'
);

select ok(
  not has_table_privilege('authenticated', 'public.content_concepts', 'insert')
    and not has_table_privilege('authenticated', 'public.word_pronunciations', 'update')
    and not has_table_privilege('authenticated', 'public.example_audio', 'delete')
    and not has_table_privilege('authenticated', 'public.word_forms', 'insert')
    and not has_table_privilege('authenticated', 'public.word_relations', 'update'),
  'authenticated cannot write V5 official content'
);

select ok(
  has_table_privilege('service_role', 'public.content_concepts', 'insert')
    and has_table_privilege('service_role', 'public.word_pronunciations', 'update')
    and has_table_privilege('service_role', 'public.example_audio', 'delete')
    and has_table_privilege('service_role', 'public.word_forms', 'insert')
    and has_table_privilege('service_role', 'public.word_relations', 'update'),
  'service_role keeps operator write access'
);

select ok(
  not has_function_privilege('anon', 'public.set_example_content_v5_defaults()', 'execute')
    and not has_function_privilege(
      'authenticated',
      'public.set_example_content_v5_defaults()',
      'execute'
    ),
  'client roles cannot execute the compatibility trigger function'
);

insert into public.words (word_text, source_note_guid, source_deck_code, source_position)
values ('usl-280-compat', 'usl-280-guid', 'usl-280-test', 1);

insert into public.word_meanings (
  word_id, priority, part_of_speech_en, definition_jp
)
select id, 1, 'noun', '互換確認'
from public.words
where source_note_guid = 'usl-280-guid';

-- Old writers provide theme and compatibility columns only. The trigger must
-- fill the new required V5 columns during the transition.
insert into public.example_contents (
  meaning_id, theme, sentence_en, sentence_jp, image_asset_path, audio_asset_path
)
select id, 'シンプル', 'Compatibility remains.', '互換性を保つ。', null, null
from public.word_meanings
where definition_jp = '互換確認';

select results_eq(
  $$select count(*)
    from public.example_contents example
    join public.content_concepts concept on concept.id = example.concept_id
    where example.sentence_en = 'Compatibility remains.'
      and concept.concept_code = 'simple'
      and example.image_state = 'blank'
      and example.display_order = 1$$,
  array[1::bigint],
  'legacy example inserts receive safe V5 defaults'
);

update public.example_contents
set image_asset_path = (
  'content-images/simple/'
  || lpad(((id / 500) * 500)::text, 4, '0')
  || '-'
  || lpad((((id / 500) * 500) + 499)::text, 4, '0')
  || '/'
  || id::text
  || '.webp'
)
where sentence_en = 'Compatibility remains.';

select results_eq(
  $$select count(*) from public.example_contents
    where sentence_en = 'Compatibility remains.'
      and image_asset_path is not null
      and image_state = 'present'$$,
  array[1::bigint],
  'legacy image-path updates keep V5 state in sync'
);

select throws_ok(
  $$insert into public.words (word_text, source_note_guid, source_deck_code, source_position)
    values ('usl-280-duplicate', 'usl-280-guid', 'usl-280-test', 2)$$,
  '23505',
  null,
  'source note GUID is unique'
);

select throws_ok(
  $$insert into public.words (word_text, source_note_guid, source_deck_code, source_position)
    values ('usl-280-duplicate-position', 'usl-280-guid-2', 'usl-280-test', 1)$$,
  '23505',
  null,
  'source deck position is unique'
);

select throws_ok(
  $$insert into public.word_forms (word_id, forms_json)
    select id, '[]'::jsonb from public.words where source_note_guid = 'usl-280-guid'$$,
  '23514',
  null,
  'word forms require a JSON object'
);

select * from finish();

rollback;
