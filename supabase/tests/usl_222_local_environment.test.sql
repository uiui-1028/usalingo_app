begin;

create extension if not exists pgtap with schema extensions;

select plan(35);

select ok(to_regclass('auth.users') is not null, 'Auth schema is available');
select ok(to_regclass('public.users') is not null, 'users exists');
select ok(to_regclass('public.user_profiles') is not null, 'user_profiles exists');
select ok(to_regclass('public.words') is not null, 'words exists');
select ok(to_regclass('public.word_meanings') is not null, 'word_meanings exists');
select ok(to_regclass('public.example_contents') is not null, 'example_contents exists');
select ok(to_regclass('public.decks') is not null, 'decks exists');
select ok(to_regclass('public.deck_words') is not null, 'deck_words exists');
select ok(to_regclass('public.card_templates') is not null, 'card_templates exists');
select ok(to_regclass('public.cards') is not null, 'cards exists');
select ok(to_regclass('public.user_card_progress') is not null, 'user_card_progress exists');
select ok(to_regclass('public.user_word_tags') is not null, 'user_word_tags exists');
select ok(to_regclass('public.user_word_overrides') is not null, 'user_word_overrides exists');
select ok(to_regclass('public.user_learning_progress') is not null, 'legacy progress exists for migration verification');

select results_eq(
  $$select count(*)
    from pg_class
    where oid in (
      'public.users'::regclass,
      'public.user_profiles'::regclass,
      'public.words'::regclass,
      'public.word_meanings'::regclass,
      'public.example_contents'::regclass,
      'public.decks'::regclass,
      'public.deck_words'::regclass,
      'public.card_templates'::regclass,
      'public.cards'::regclass,
      'public.user_card_progress'::regclass,
      'public.user_word_tags'::regclass,
      'public.user_word_overrides'::regclass,
      'public.user_learning_progress'::regclass
    )
      and relrowsecurity$$,
  array[13::bigint],
  'RLS is enabled on all app tables'
);

select ok(
  not has_table_privilege('anon', 'public.words', 'select')
  and not has_table_privilege('anon', 'public.word_meanings', 'select')
  and not has_table_privilege('anon', 'public.example_contents', 'select')
  and not has_table_privilege('anon', 'public.decks', 'select')
  and not has_table_privilege('anon', 'public.deck_words', 'select')
  and not has_table_privilege('anon', 'public.card_templates', 'select')
  and not has_table_privilege('anon', 'public.cards', 'select'),
  'anon cannot read official content'
);

select ok(
  has_table_privilege('authenticated', 'public.words', 'select')
  and has_table_privilege('authenticated', 'public.word_meanings', 'select')
  and has_table_privilege('authenticated', 'public.example_contents', 'select')
  and has_table_privilege('authenticated', 'public.decks', 'select')
  and has_table_privilege('authenticated', 'public.card_templates', 'select')
  and has_table_privilege('authenticated', 'public.cards', 'select'),
  'authenticated can read current official content'
);

select ok(
  has_table_privilege('authenticated', 'public.user_card_progress', 'select')
  and has_table_privilege('authenticated', 'public.user_card_progress', 'insert')
  and has_table_privilege('authenticated', 'public.user_card_progress', 'update'),
  'card progress baseline grants support the iOS app'
);

select ok(
  has_table_privilege('authenticated', 'public.user_word_tags', 'select')
  and has_table_privilege('authenticated', 'public.user_word_tags', 'insert')
  and has_table_privilege('authenticated', 'public.user_word_tags', 'delete')
  and not has_table_privilege('authenticated', 'public.user_word_tags', 'update'),
  'tag grants match the iOS app'
);

select ok(
  has_table_privilege('authenticated', 'public.user_word_overrides', 'select')
  and has_table_privilege('authenticated', 'public.user_word_overrides', 'insert')
  and has_table_privilege('authenticated', 'public.user_word_overrides', 'update')
  and not has_table_privilege('authenticated', 'public.user_word_overrides', 'delete'),
  'override grants match the iOS app'
);

select results_eq(
  $$select prosecdef
    from pg_proc
    where oid = 'public.ensure_current_user_row()'::regprocedure$$,
  array[true],
  'ensure_current_user_row is SECURITY DEFINER'
);

select ok(
  not has_function_privilege('public', 'public.ensure_current_user_row()', 'execute')
  and not has_function_privilege('anon', 'public.ensure_current_user_row()', 'execute')
  and has_function_privilege('authenticated', 'public.ensure_current_user_row()', 'execute'),
  'RPC execute privilege is authenticated-only'
);

select results_eq(
  $$select count(*) from storage.buckets
    where id in ('content-images', 'content-audio')
      and public = true$$,
  array[2::bigint],
  'both public content buckets exist'
);

select is(
  (
    select allowed_mime_types
    from storage.buckets
    where id = 'content-images'
  ),
  array['image/webp']::text[],
  'content-images accepts only WebP'
);

select is(
  (
    select allowed_mime_types
    from storage.buckets
    where id = 'content-audio'
  ),
  array['audio/mpeg']::text[],
  'content-audio accepts only MPEG audio'
);

select is_empty(
  $$select id from storage.objects$$,
  'local DB tests contain no image or audio objects'
);

select results_eq(
  $$select count(*)
    from pg_constraint
    where conrelid = 'public.example_contents'::regclass
      and conname in (
        'example_contents_image_asset_path_contract',
        'example_contents_audio_asset_path_contract'
      )
      and convalidated$$,
  array[2::bigint],
  'asset path constraints exist and are validated'
);

select results_eq(
  $$select count(*) from public.words where word_text = 'local-example'$$,
  array[1::bigint],
  'local word seed exists'
);
select results_eq(
  $$select count(*) from public.word_meanings where definition_jp = 'ローカル検証用の例'$$,
  array[1::bigint],
  'local meaning seed exists'
);
select results_eq(
  $$select count(*) from public.example_contents where sentence_en = 'This is local test data.'$$,
  array[1::bigint],
  'local example seed exists'
);
select results_eq(
  $$select count(*) from public.decks where deck_name = 'Local Verification Deck'$$,
  array[1::bigint],
  'local deck seed exists'
);
select results_eq(
  $$select count(*) from public.deck_words$$,
  array[1::bigint],
  'local deck membership seed exists'
);
select results_eq(
  $$select count(*) from public.cards where is_active$$,
  array[1::bigint],
  'local active card seed exists'
);
select results_eq(
  $$select count(*)
    from public.cards c
    join public.deck_words dw
      on dw.word_id = c.word_id
     and dw.deck_id = c.deck_id
    join public.card_templates ct
      on ct.id = c.card_template_id
    where ct.template_code = 'basic_en_to_ja'$$,
  array[1::bigint],
  'local card points to the seeded word, deck, and template'
);
select results_eq(
  $$select count(*) from public.users$$,
  array[0::bigint],
  'seed contains no copied user data'
);

select * from finish();

rollback;
