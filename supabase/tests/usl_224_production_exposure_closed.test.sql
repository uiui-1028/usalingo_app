-- 本番だけに存在した古いオブジェクトが消えたままであることを固定する。
-- USL-224 で公開を閉じ、20260915120000_drop_legacy_objects.sql で削除した。

begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

select ok(to_regprocedure('public.sync_existing_images()') is null, 'sync_existing_images stays dropped');
select ok(to_regprocedure('public.setup_content_images_policies()') is null, 'setup_content_images_policies stays dropped');
select ok(to_regprocedure('public.optimize_content_audio_policies()') is null, 'optimize_content_audio_policies stays dropped');
select ok(to_regprocedure('public.get_index_recommendations()') is null, 'get_index_recommendations stays dropped');
select ok(to_regprocedure('public.get_performance_summary()') is null, 'get_performance_summary stays dropped');
select ok(to_regprocedure('public.handle_storage_upload()') is null, 'handle_storage_upload stays dropped');

select ok(to_regclass('public.asset_processing_queue') is null, 'asset_processing_queue stays dropped');
select ok(to_regclass('public.user_learning_progress') is null, 'user_learning_progress stays dropped');
select ok(to_regclass('public.deck_words') is null, 'deck_words stays dropped');

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v' and c.relname like 'v\_%'),
  0,
  'no production-only v_* views remain'
);

select is(
  (select count(*)::int from storage.buckets
    where id in ('asset-inbox', 'illustrations', 'public', 'user-uploads')),
  0,
  'legacy buckets stay dropped'
);

select is(
  (select count(*)::int from pg_trigger
    where tgrelid = 'storage.objects'::regclass and tgname = 'storage_upload_trigger'),
  0,
  'no trigger rewrites content paths on upload'
);

-- 残すべきトリガー関数は消していない。
select ok(to_regprocedure('public.update_updated_at_column()') is not null, 'update_updated_at_column is kept');
select ok(to_regprocedure('public.set_example_content_v5_defaults()') is not null, 'set_example_content_v5_defaults is kept');

select * from finish();

rollback;
