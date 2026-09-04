-- 退会は「その場で全部消す」方式（2026-09-04 改定）。
-- 停止状態を持たないため、DBには退会専用のテーブルもRPCもポリシーも無い。
-- 代わりに、auth.users を1件消せば利用者データが連鎖して消えることを確かめる。
begin;
select plan(10);

-- 旧方式（365日保持）の名残が残っていないこと。
select ok(to_regnamespace('private') is null, 'no private lifecycle schema remains');
select hasnt_table('private', 'account_deletions', 'no withdrawal state table remains');
select hasnt_function('public', 'is_current_user_active', 'no active-account gate remains');
select hasnt_function('public', 'request_account_deletion', 'no withdrawal RPC remains');
select is_empty(
  $$select policyname from pg_policies
    where schemaname = 'public' and policyname like '%require_active_account%'$$,
  'no active-account policies remain on user tables'
);

-- 連鎖削除で本当に消えることを、実際の行で確かめる。
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'purge@example.test', '', now(), now());
insert into public.users (id, email)
values ('55555555-5555-5555-5555-555555555555', 'purge@example.test');
insert into public.user_profiles (user_id, nickname)
values ('55555555-5555-5555-5555-555555555555', 'purge-me');
insert into public.user_local_study_backups (user_id, schema_version, payload)
values ('55555555-5555-5555-5555-555555555555', 1, '{"owner":"purge"}'::jsonb);

select isnt_empty(
  $$select 1 from public.users where id = '55555555-5555-5555-5555-555555555555'$$,
  'the account exists before deletion'
);

delete from auth.users where id = '55555555-5555-5555-5555-555555555555';

select is_empty(
  $$select 1 from public.users where id = '55555555-5555-5555-5555-555555555555'$$,
  'public.users is removed with the auth user'
);
select is_empty(
  $$select 1 from public.user_profiles where user_id = '55555555-5555-5555-5555-555555555555'$$,
  'the profile is removed with the auth user'
);
select is_empty(
  $$select 1 from public.user_local_study_backups where user_id = '55555555-5555-5555-5555-555555555555'$$,
  'the study backup is removed with the auth user'
);
select is_empty(
  $$select 1 from public.user_card_progress where user_id = '55555555-5555-5555-5555-555555555555'$$,
  'card progress is removed with the auth user'
);

select * from finish();
rollback;
