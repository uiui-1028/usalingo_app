-- G-4 学習記録バックアップ表の権限確認。
-- 実行計画書 docs/plans/guest-study-handoff-plan.md の受け入れ条件3点を実際に触って確かめる。
begin;
select plan(9);

-- 検証用の利用者を3人作る。C は退会手続き中とする。
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'a@example.test', '', now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'b@example.test', '', now(), now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c@example.test', '', now(), now())
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'c@example.test')
on conflict (id) do nothing;

insert into private.account_deletions (user_id, request_id, status, requested_at, reauthenticated_at, restorable_until)
values (
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  'disabled',
  now(), now(), now() + interval '365 days'
);

-- B の控えを1件、権限の効かない立場で置いておく（A から見えないことの確認用）。
insert into public.user_local_study_backups (user_id, schema_version, device_name, payload)
values ('22222222-2222-2222-2222-222222222222', 1, 'iPhone-B', '{"owner":"b"}'::jsonb);

-- ① 自分の行を保存・取得・更新・削除できる
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$insert into public.user_local_study_backups (user_id, schema_version, device_name, payload)
    values ('11111111-1111-1111-1111-111111111111', 1, 'iPhone-A', '{"owner":"a"}'::jsonb)$$,
  'A can save its own backup'
);

select results_eq(
  $$select payload->>'owner' from public.user_local_study_backups$$,
  array['a'],
  'A reads only its own backup'
);

select lives_ok(
  $$update public.user_local_study_backups
      set payload = '{"owner":"a","v":2}'::jsonb
    where user_id = '11111111-1111-1111-1111-111111111111'$$,
  'A can replace its own backup'
);

-- ② 他人の user_id の行は読めない／書けない
select is_empty(
  $$select 1 from public.user_local_study_backups
    where user_id = '22222222-2222-2222-2222-222222222222'$$,
  'A cannot read another user backup'
);

select throws_ok(
  $$insert into public.user_local_study_backups (user_id, schema_version, payload)
    values ('22222222-2222-2222-2222-222222222222', 1, '{"owner":"spoofed"}'::jsonb)$$,
  '42501',
  null,
  'A cannot write a backup for another user'
);

select results_eq(
  $$with removed as (
      delete from public.user_local_study_backups
      where user_id = '22222222-2222-2222-2222-222222222222'
      returning 1
    ) select count(*) from removed$$,
  array[0::bigint],
  'A cannot delete another user backup'
);

-- ③ 退会手続き中のアカウントからは読み書きできない
set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

select is_empty(
  $$select 1 from public.user_local_study_backups$$,
  'a withdrawn account reads nothing'
);

select throws_ok(
  $$insert into public.user_local_study_backups (user_id, schema_version, payload)
    values ('33333333-3333-3333-3333-333333333333', 1, '{"owner":"c"}'::jsonb)$$,
  '42501',
  null,
  'a withdrawn account cannot save a backup'
);

-- anon は表そのものへ届かない。
set local role anon;
select ok(
  not has_table_privilege('anon', 'public.user_local_study_backups', 'select'),
  'anonymous users cannot reach backups'
);

reset role;
select * from finish();
rollback;
