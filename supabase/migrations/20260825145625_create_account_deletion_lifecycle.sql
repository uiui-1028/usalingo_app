begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table private.account_deletions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  request_id uuid not null unique,
  status text not null default 'requested',
  requested_at timestamptz not null default now(),
  reauthenticated_at timestamptz not null,
  disabled_at timestamptz,
  sessions_revoked_at timestamptz,
  restorable_until timestamptz not null,
  purge_started_at timestamptz,
  purged_at timestamptz,
  failed_step text,
  failure_code text,
  retry_count integer not null default 0,
  next_retry_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint account_deletions_status_allowed check (
    status in ('requested', 'disabled', 'purging', 'purged', 'restore_requested', 'restored', 'failed')
  ),
  constraint account_deletions_retry_count_nonnegative check (retry_count >= 0),
  constraint account_deletions_restoration_window check (
    restorable_until = requested_at + interval '365 days'
  )
);

revoke all on table private.account_deletions from public, anon, authenticated;
grant select, insert, update, delete on table private.account_deletions to service_role;

create or replace function public.request_account_deletion(
  p_user_id uuid,
  p_request_id uuid,
  p_reauthenticated_at timestamptz
)
returns table (
  request_id uuid,
  status text,
  restorable_until timestamptz,
  disabled_at timestamptz,
  sessions_revoked_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  deletion private.account_deletions%rowtype;
begin
  if p_reauthenticated_at < now() - interval '5 minutes'
     or p_reauthenticated_at > now() + interval '30 seconds' then
    raise exception using errcode = '22023', message = 'recent reauthentication required';
  end if;

  insert into private.account_deletions (
    user_id, request_id, reauthenticated_at, restorable_until
  ) values (
    p_user_id, p_request_id, p_reauthenticated_at, now() + interval '365 days'
  )
  on conflict (user_id) do nothing;

  select * into strict deletion
  from private.account_deletions
  where user_id = p_user_id;

  return query select deletion.request_id, deletion.status,
    deletion.restorable_until, deletion.disabled_at, deletion.sessions_revoked_at;
end;
$$;

create or replace function public.advance_account_deletion(
  p_user_id uuid,
  p_request_id uuid,
  p_step text,
  p_failure_code text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if p_step = 'auth_banned' then
    update private.account_deletions
       set status = 'disabled', disabled_at = coalesce(disabled_at, now()),
           failed_step = null, failure_code = null, next_retry_at = null, updated_at = now()
     where user_id = p_user_id and request_id = p_request_id;
  elsif p_step = 'sessions_revoked' then
    update private.account_deletions
       set status = 'disabled', sessions_revoked_at = coalesce(sessions_revoked_at, now()),
           failed_step = null, failure_code = null, next_retry_at = null, updated_at = now()
     where user_id = p_user_id and request_id = p_request_id;
  elsif p_step = 'failed' and p_failure_code is not null then
    update private.account_deletions
       set status = case when disabled_at is null then 'failed' else 'disabled' end,
           failed_step = 'withdrawal', failure_code = left(p_failure_code, 80),
           retry_count = retry_count + 1,
           next_retry_at = now() + least(interval '1 hour', interval '1 minute' * power(2, least(retry_count, 6))),
           updated_at = now()
     where user_id = p_user_id and request_id = p_request_id;
  else
    raise exception using errcode = '22023', message = 'invalid account deletion step';
  end if;

  if not found then
    raise exception using errcode = 'P0002', message = 'account deletion request not found';
  end if;
end;
$$;

create or replace function public.get_account_deletion(
  p_user_id uuid,
  p_request_id uuid
)
returns table (
  request_id uuid,
  status text,
  restorable_until timestamptz,
  disabled_at timestamptz,
  sessions_revoked_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, private
as $$
  select deletion.request_id, deletion.status, deletion.restorable_until,
    deletion.disabled_at, deletion.sessions_revoked_at
  from private.account_deletions as deletion
  where deletion.user_id = p_user_id
    and deletion.request_id = p_request_id;
$$;

create or replace function public.claim_expired_account_purge(p_user_id uuid)
returns table (request_id uuid, user_id uuid)
language plpgsql
security definer
set search_path = pg_catalog, private, storage
as $$
declare
  deletion private.account_deletions%rowtype;
begin
  select * into strict deletion
  from private.account_deletions
  where account_deletions.user_id = p_user_id
  for update;

  if deletion.restorable_until >= now()
     or deletion.status not in ('disabled', 'purging')
     or deletion.disabled_at is null
     or deletion.sessions_revoked_at is null then
    raise exception using errcode = '55000', message = 'account is not eligible for final deletion';
  end if;
  if exists (select 1 from storage.objects where owner_id = p_user_id::text) then
    raise exception using errcode = '55000', message = 'owned storage objects must be removed first';
  end if;

  update private.account_deletions
     set status = 'purging', purge_started_at = coalesce(purge_started_at, now()),
         failed_step = null, failure_code = null, updated_at = now()
   where account_deletions.user_id = p_user_id;

  return query select deletion.request_id, deletion.user_id;
end;
$$;

revoke all on function public.request_account_deletion(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.advance_account_deletion(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.get_account_deletion(uuid, uuid) from public, anon, authenticated;
revoke all on function public.claim_expired_account_purge(uuid) from public, anon, authenticated;
grant execute on function public.request_account_deletion(uuid, uuid, timestamptz) to service_role;
grant execute on function public.advance_account_deletion(uuid, uuid, text, text) to service_role;
grant execute on function public.get_account_deletion(uuid, uuid) to service_role;
grant execute on function public.claim_expired_account_purge(uuid) to service_role;

create or replace function public.is_current_user_active()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private
as $$
  select not exists (
    select 1 from private.account_deletions
    where user_id = (select auth.uid())
      and status in ('disabled', 'purging', 'purged', 'failed')
  );
$$;

revoke all on function public.is_current_user_active() from public, anon;
grant execute on function public.is_current_user_active() to authenticated, service_role;

create policy users_require_active_account
  on public.users as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));
create policy user_profiles_require_active_account
  on public.user_profiles as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));
create policy user_learning_progress_require_active_account
  on public.user_learning_progress as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));
create policy user_word_tags_require_active_account
  on public.user_word_tags as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));
create policy user_word_overrides_require_active_account
  on public.user_word_overrides as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));
create policy user_card_progress_require_active_account
  on public.user_card_progress as restrictive for all to authenticated
  using ((select public.is_current_user_active()))
  with check ((select public.is_current_user_active()));

commit;
