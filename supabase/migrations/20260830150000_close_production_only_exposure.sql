-- USL-224 本番だけに存在したオブジェクトの公開を閉じる
--
-- 20260830090000_record_production_only_objects.sql (USL-270) は、本番の姿を
-- そのまま写し取る現状記録であり、既知の危険を意図的に再現している。
-- このmigrationは、その危険を閉じる。USL-244監査の「解除条件」1〜3に対応する。
--
--   1. Storage policyを作り直せる公開SECURITY DEFINER関数のEXECUTEを取り消す
--   2. public.asset_processing_queue のRLSを有効化し、GRANTを最小化する
--   3. 6つのviewを security_invoker = true にし、不要なGRANTを取り消す
--
-- 前提の確認 (2026-08-30):
--   iOSアプリ (apps/ios-swiftui) と Edge Function (delete-user-account) は、
--   ここで扱うtable・view・関数のいずれも参照していない。リポジトリ全体を
--   検索して呼び出し元は0件だった。したがって取り消しても壊れる利用者はいない。
--
-- 本番への適用はこの課題では行わない。適用はUSL-245で、人間の明示承認を得てから行う。

begin;

-- ---------------------------------------------------------------------------
-- 1. Storage policyを作り直せる関数を、クライアントroleから閉じる
--
--    この2関数は SECURITY DEFINER であり、storage.objects のpolicyを
--    DROP して CREATE し直す。anon が実行できる状態は、公開鍵さえあれば
--    誰でもStorageのアクセス制御を書き換えられることを意味する。
--    さらに、後続migrationが削除するクライアント書込policyを、適用後に
--    復活させることもできる。
--
--    運用時に必要になったら、migrationとして書くか、owner権限で実行する。
--    アプリのroleに実行権を残す理由はないため、service_role からも取り消す。
--    search_path は定義側で 'public' に固定済みのため、ここでは触らない。
-- ---------------------------------------------------------------------------

revoke all on function public.setup_content_images_policies()
  from public, anon, authenticated, service_role;
revoke all on function public.optimize_content_audio_policies()
  from public, anon, authenticated, service_role;

-- 監視用の関数は、pg_stat_* 経由でスキーマ構造と統計を露出する。
-- 利用者アプリに必要な情報ではないため、運用roleだけに残す。
revoke all on function public.get_index_recommendations()
  from public, anon, authenticated;
revoke all on function public.get_performance_summary()
  from public, anon, authenticated;

grant execute on function public.get_index_recommendations() to service_role;
grant execute on function public.get_performance_summary() to service_role;

-- ---------------------------------------------------------------------------
-- 2. asset_processing_queue を閉じる
--
--    本番では RLS 無効かつ anon に GRANT ALL だった。つまり匿名の利用者が
--    キューを全件読み、任意の行を挿入・改変・削除できた。
--    このキューはサーバー側のアセット紐付け処理のためのもので、
--    クライアントから触る設計ではない。
--
--    RLSを有効にし、policyは1つも作らない。policyが無いRLS有効tableは、
--    RLSをbypassしないすべてのroleに対して0行になる。GRANTも取り消すため、
--    権限とpolicyの二重で閉じる。service_role は RLS をbypassする。
-- ---------------------------------------------------------------------------

alter table public.asset_processing_queue enable row level security;

revoke all on table public.asset_processing_queue from public, anon, authenticated;
grant select, insert, update, delete on table public.asset_processing_queue to service_role;

comment on table public.asset_processing_queue is
  'アセット紐付け処理の非同期キュー。サーバー側専用。RLS有効・policy無しで、クライアントroleからは到達できない。';

-- ---------------------------------------------------------------------------
-- 3. view を実行者の権限で動かす
--
--    security_invoker が未設定のviewは、参照した利用者ではなく所有者
--    (postgres) の権限で基底tableを読む。つまり基底tableのRLSを迂回する。
--    Security Advisor はこれを6件ERRORとして報告していた。
--
--    security_invoker = true にすると、基底tableのRLSとGRANTがそのまま効く。
-- ---------------------------------------------------------------------------

alter view public.v_word_meanings_with_paths     set (security_invoker = true);
alter view public.v_example_contents_with_paths  set (security_invoker = true);
alter view public.v_index_usage_stats            set (security_invoker = true);
alter view public.v_index_monitoring             set (security_invoker = true);
alter view public.v_database_size_monitoring     set (security_invoker = true);
alter view public.v_table_stats_monitoring       set (security_invoker = true);

-- 公式コンテンツの2つのviewは GRANT ALL だった。単純なviewは自動更新可能なため、
-- INSERT・UPDATE・DELETE は基底tableへの書込経路になりうる。読み取りだけ残す。
revoke all on table public.v_word_meanings_with_paths
  from public, anon, authenticated;
revoke all on table public.v_example_contents_with_paths
  from public, anon, authenticated;

grant select on table public.v_word_meanings_with_paths    to anon, authenticated;
grant select on table public.v_example_contents_with_paths to anon, authenticated;

-- 監視系の4つのviewは、table一覧、index一覧、行数、DBサイズを露出する。
-- 利用者アプリには不要なので、運用roleだけに残す。
revoke all on table public.v_index_usage_stats         from public, anon, authenticated;
revoke all on table public.v_index_monitoring          from public, anon, authenticated;
revoke all on table public.v_database_size_monitoring  from public, anon, authenticated;
revoke all on table public.v_table_stats_monitoring    from public, anon, authenticated;

grant select on table public.v_index_usage_stats         to service_role;
grant select on table public.v_index_monitoring          to service_role;
grant select on table public.v_database_size_monitoring  to service_role;
grant select on table public.v_table_stats_monitoring    to service_role;

-- ---------------------------------------------------------------------------
-- 4. 適用直後の自己検証
--
--    20260821133424_enforce_current_app_grants.sql と同じ方針で、
--    期待どおりに閉じたかをこのmigration自身が確かめ、外れていれば失敗する。
-- ---------------------------------------------------------------------------

do $$
declare
  v_rls_enabled boolean;
  v_policy_count integer;
  v_view text;
  v_invoker text;
  v_role text;
  v_priv text;
begin
  -- 2. queue: RLS有効・policy無し
  select relrowsecurity into v_rls_enabled
  from pg_class where oid = 'public.asset_processing_queue'::regclass;

  if not v_rls_enabled then
    raise exception 'USL-224 verification failed: asset_processing_queue still has RLS disabled.';
  end if;

  select count(*) into v_policy_count
  from pg_policies where schemaname = 'public' and tablename = 'asset_processing_queue';

  if v_policy_count <> 0 then
    raise exception
      'USL-224 verification failed: asset_processing_queue has % policy(ies); expected none.', v_policy_count;
  end if;

  -- 1. 関数: クライアントroleから実行できない
  foreach v_role in array array['public', 'anon', 'authenticated'] loop
    if has_function_privilege(v_role, 'public.setup_content_images_policies()', 'execute')
       or has_function_privilege(v_role, 'public.optimize_content_audio_policies()', 'execute')
       or has_function_privilege(v_role, 'public.get_index_recommendations()', 'execute')
       or has_function_privilege(v_role, 'public.get_performance_summary()', 'execute') then
      raise exception
        'USL-224 verification failed: role % can still execute a SECURITY DEFINER function.', v_role;
    end if;
  end loop;

  -- 2. queue: クライアントroleに権限が残っていない
  foreach v_role in array array['public', 'anon', 'authenticated'] loop
    foreach v_priv in array array['select', 'insert', 'update', 'delete'] loop
      if has_table_privilege(v_role, 'public.asset_processing_queue', v_priv) then
        raise exception
          'USL-224 verification failed: role % still has % on asset_processing_queue.', v_role, v_priv;
      end if;
    end loop;
  end loop;

  -- 3. view: すべて security_invoker = true
  foreach v_view in array array[
    'v_word_meanings_with_paths',
    'v_example_contents_with_paths',
    'v_index_usage_stats',
    'v_index_monitoring',
    'v_database_size_monitoring',
    'v_table_stats_monitoring'
  ] loop
    select option into v_invoker
    from pg_class c, unnest(coalesce(c.reloptions, array[]::text[])) as option
    where c.oid = ('public.' || v_view)::regclass
      and option = 'security_invoker=true';

    if v_invoker is null then
      raise exception 'USL-224 verification failed: view public.% is not security_invoker.', v_view;
    end if;
  end loop;

  -- 3. view: 書込権限が残っていない。監視系は読み取りも残っていない
  foreach v_role in array array['public', 'anon', 'authenticated'] loop
    foreach v_priv in array array['insert', 'update', 'delete'] loop
      if has_table_privilege(v_role, 'public.v_word_meanings_with_paths', v_priv)
         or has_table_privilege(v_role, 'public.v_example_contents_with_paths', v_priv) then
        raise exception
          'USL-224 verification failed: role % still has % on a content view.', v_role, v_priv;
      end if;
    end loop;

    if has_table_privilege(v_role, 'public.v_index_usage_stats', 'select')
       or has_table_privilege(v_role, 'public.v_index_monitoring', 'select')
       or has_table_privilege(v_role, 'public.v_database_size_monitoring', 'select')
       or has_table_privilege(v_role, 'public.v_table_stats_monitoring', 'select') then
      raise exception
        'USL-224 verification failed: role % can still read a monitoring view.', v_role;
    end if;
  end loop;

  -- 3. 公式コンテンツのviewは読み取りを残す。取り消しすぎていないことも確かめる
  if not has_table_privilege('anon', 'public.v_word_meanings_with_paths', 'select')
     or not has_table_privilege('anon', 'public.v_example_contents_with_paths', 'select')
     or not has_table_privilege('authenticated', 'public.v_word_meanings_with_paths', 'select')
     or not has_table_privilege('authenticated', 'public.v_example_contents_with_paths', 'select') then
    raise exception 'USL-224 verification failed: a content view lost its intended read access.';
  end if;
end
$$;

commit;
