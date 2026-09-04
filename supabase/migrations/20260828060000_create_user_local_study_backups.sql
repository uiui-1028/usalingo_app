-- ゲスト学習記録の引き継ぎ（G-2）。
-- 学習の正は端末側であり、この表は復元のためのバックアップだけを持つ。
-- カードIDの対応付けを必要としないため、同梱デッキを正本データへ差し替えても影響を受けない。
-- 1ユーザー1行とし、最後に保存した内容で置き換える。

begin;

create table if not exists public.user_local_study_backups (
  user_id uuid primary key references public.users(id) on delete cascade,
  schema_version integer not null,
  device_name text,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_local_study_backups_schema_version_positive
    check (schema_version > 0),
  constraint user_local_study_backups_payload_is_object
    check (jsonb_typeof(payload) = 'object'),
  -- 端末の記録が肥大化してもDBを壊さないための上限。1件あたり4MiBまで。
  constraint user_local_study_backups_payload_size
    check (pg_column_size(payload) <= 4194304),
  constraint user_local_study_backups_device_name_length
    check (device_name is null or length(device_name) <= 100)
);

alter table public.user_local_study_backups enable row level security;

drop trigger if exists update_user_local_study_backups_updated_at
  on public.user_local_study_backups;
create trigger update_user_local_study_backups_updated_at
  before update on public.user_local_study_backups
  for each row
  execute function public.update_updated_at_column();

-- 自分の行だけを読み書きできる。
drop policy if exists "user_local_study_backups_select_own"
  on public.user_local_study_backups;
create policy "user_local_study_backups_select_own"
  on public.user_local_study_backups
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "user_local_study_backups_insert_own"
  on public.user_local_study_backups;
create policy "user_local_study_backups_insert_own"
  on public.user_local_study_backups
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "user_local_study_backups_update_own"
  on public.user_local_study_backups;
create policy "user_local_study_backups_update_own"
  on public.user_local_study_backups
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "user_local_study_backups_delete_own"
  on public.user_local_study_backups;
create policy "user_local_study_backups_delete_own"
  on public.user_local_study_backups
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.user_local_study_backups from public, anon, authenticated;
grant select, insert, update, delete
  on table public.user_local_study_backups to authenticated;
grant select, insert, update, delete
  on table public.user_local_study_backups to service_role;

comment on table public.user_local_study_backups is
  'Device-owned study records kept only for restore. The device is the source of truth.';
comment on column public.user_local_study_backups.schema_version is
  'Snapshot format version written by the app. The app refuses versions it does not know.';
comment on column public.user_local_study_backups.payload is
  'One LocalStudySnapshot as written by the app. Not read or aggregated server-side.';

-- 権限が意図どおりかをその場で確かめる。既存の enforce_current_app_grants と同じ考え方。
do $$
begin
  if has_table_privilege('anon', 'public.user_local_study_backups', 'select')
     or has_table_privilege('anon', 'public.user_local_study_backups', 'insert')
  then
    raise exception 'App grant verification failed: anon can reach user-owned backups.';
  end if;

  if not has_table_privilege('authenticated', 'public.user_local_study_backups', 'select')
     or not has_table_privilege('authenticated', 'public.user_local_study_backups', 'insert')
     or not has_table_privilege('authenticated', 'public.user_local_study_backups', 'update')
     or not has_table_privilege('authenticated', 'public.user_local_study_backups', 'delete')
  then
    raise exception 'App grant verification failed: authenticated is missing a backup privilege.';
  end if;
end;
$$;

commit;
