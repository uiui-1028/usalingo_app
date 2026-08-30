-- USL-224 本番だけに存在したオブジェクトの公開が閉じたままであることを固定する。
-- 20260830150000_close_production_only_exposure.sql が回帰した場合に落ちる。

begin;

create extension if not exists pgtap with schema extensions;

select plan(26);

-- ---------------------------------------------------------------------------
-- 1. Storage policy を作り直せる SECURITY DEFINER 関数
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.setup_content_images_policies()', 'execute'),
  'anon cannot execute setup_content_images_policies'
);
select ok(
  not has_function_privilege('authenticated', 'public.setup_content_images_policies()', 'execute'),
  'authenticated cannot execute setup_content_images_policies'
);
select ok(
  not has_function_privilege('anon', 'public.optimize_content_audio_policies()', 'execute'),
  'anon cannot execute optimize_content_audio_policies'
);
select ok(
  not has_function_privilege('authenticated', 'public.optimize_content_audio_policies()', 'execute'),
  'authenticated cannot execute optimize_content_audio_policies'
);
select ok(
  not has_function_privilege('anon', 'public.get_index_recommendations()', 'execute'),
  'anon cannot execute get_index_recommendations'
);
select ok(
  not has_function_privilege('authenticated', 'public.get_performance_summary()', 'execute'),
  'authenticated cannot execute get_performance_summary'
);

-- 壊れた関数は USL-276 で削除済み。復活していないことを確かめる。
select ok(
  to_regprocedure('public.sync_existing_images()') is null,
  'sync_existing_images stays dropped'
);

-- ---------------------------------------------------------------------------
-- 2. asset_processing_queue
-- ---------------------------------------------------------------------------

select ok(
  (select relrowsecurity from pg_class where oid = 'public.asset_processing_queue'::regclass),
  'asset_processing_queue has RLS enabled'
);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'asset_processing_queue'),
  0,
  'asset_processing_queue has no policy, so client roles see no rows'
);

select ok(
  not has_table_privilege('anon', 'public.asset_processing_queue', 'select'),
  'anon cannot read asset_processing_queue'
);
select ok(
  not has_table_privilege('anon', 'public.asset_processing_queue', 'insert'),
  'anon cannot insert into asset_processing_queue'
);
select ok(
  not has_table_privilege('anon', 'public.asset_processing_queue', 'update'),
  'anon cannot update asset_processing_queue'
);
select ok(
  not has_table_privilege('anon', 'public.asset_processing_queue', 'delete'),
  'anon cannot delete from asset_processing_queue'
);
select ok(
  not has_table_privilege('authenticated', 'public.asset_processing_queue', 'select'),
  'authenticated cannot read asset_processing_queue'
);
select ok(
  not has_table_privilege('authenticated', 'public.asset_processing_queue', 'insert'),
  'authenticated cannot insert into asset_processing_queue'
);
select ok(
  has_table_privilege('service_role', 'public.asset_processing_queue', 'select'),
  'service_role keeps access to asset_processing_queue'
);

-- ---------------------------------------------------------------------------
-- 3. view
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::int
     from pg_class c
    where c.oid in (
      'public.v_word_meanings_with_paths'::regclass,
      'public.v_example_contents_with_paths'::regclass,
      'public.v_index_usage_stats'::regclass,
      'public.v_index_monitoring'::regclass,
      'public.v_database_size_monitoring'::regclass,
      'public.v_table_stats_monitoring'::regclass
    )
      and 'security_invoker=true' = any(coalesce(c.reloptions, array[]::text[]))),
  6,
  'all six production-only views run as the invoker'
);

select ok(
  has_table_privilege('anon', 'public.v_word_meanings_with_paths', 'select'),
  'anon keeps read access to v_word_meanings_with_paths'
);
select ok(
  has_table_privilege('anon', 'public.v_example_contents_with_paths', 'select'),
  'anon keeps read access to v_example_contents_with_paths'
);
select ok(
  not has_table_privilege('anon', 'public.v_word_meanings_with_paths', 'insert'),
  'anon cannot write through v_word_meanings_with_paths'
);
select ok(
  not has_table_privilege('anon', 'public.v_example_contents_with_paths', 'update'),
  'anon cannot write through v_example_contents_with_paths'
);
select ok(
  not has_table_privilege('authenticated', 'public.v_word_meanings_with_paths', 'delete'),
  'authenticated cannot write through v_word_meanings_with_paths'
);

select ok(
  not has_table_privilege('anon', 'public.v_index_usage_stats', 'select'),
  'anon cannot read v_index_usage_stats'
);
select ok(
  not has_table_privilege('anon', 'public.v_table_stats_monitoring', 'select'),
  'anon cannot read v_table_stats_monitoring'
);
select ok(
  not has_table_privilege('authenticated', 'public.v_database_size_monitoring', 'select'),
  'authenticated cannot read v_database_size_monitoring'
);
select ok(
  not has_table_privilege('authenticated', 'public.v_index_monitoring', 'select'),
  'authenticated cannot read v_index_monitoring'
);

select * from finish();

rollback;
