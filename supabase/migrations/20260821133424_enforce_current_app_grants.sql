-- Keep Data API exposure explicit for every table used by the current iOS app.
-- RLS controls rows; these GRANTs separately control which operations exist.

begin;

alter function public.ensure_current_user_row() set search_path = '';
revoke all on function public.ensure_current_user_row() from public, anon;
grant execute on function public.ensure_current_user_row() to authenticated;

revoke all on table public.user_profiles from public, anon, authenticated;
revoke all on table public.user_word_tags from public, anon, authenticated;
revoke all on table public.user_word_overrides from public, anon, authenticated;

grant select, insert, update on table public.user_profiles to authenticated;
grant select, insert, delete on table public.user_word_tags to authenticated;
grant select, insert, update on table public.user_word_overrides to authenticated;

grant select, insert, update, delete on table public.user_profiles to service_role;
grant select, insert, update, delete on table public.user_word_tags to service_role;
grant select, insert, update, delete on table public.user_word_overrides to service_role;

do $$
begin
  if has_table_privilege('anon', 'public.user_profiles', 'select')
     or has_table_privilege('anon', 'public.user_word_tags', 'select')
     or has_table_privilege('anon', 'public.user_word_overrides', 'select') then
    raise exception 'App grant verification failed: anon can read user-owned data.';
  end if;

  if not has_table_privilege('authenticated', 'public.user_profiles', 'select')
     or not has_table_privilege('authenticated', 'public.user_profiles', 'insert')
     or not has_table_privilege('authenticated', 'public.user_profiles', 'update')
     or not has_table_privilege('authenticated', 'public.user_word_tags', 'select')
     or not has_table_privilege('authenticated', 'public.user_word_tags', 'insert')
     or not has_table_privilege('authenticated', 'public.user_word_tags', 'delete')
     or not has_table_privilege('authenticated', 'public.user_word_overrides', 'select')
     or not has_table_privilege('authenticated', 'public.user_word_overrides', 'insert')
     or not has_table_privilege('authenticated', 'public.user_word_overrides', 'update') then
    raise exception 'App grant verification failed: authenticated is missing an app privilege.';
  end if;

  if has_table_privilege('authenticated', 'public.user_profiles', 'delete')
     or has_table_privilege('authenticated', 'public.user_word_tags', 'update')
     or has_table_privilege('authenticated', 'public.user_word_overrides', 'delete') then
    raise exception 'App grant verification failed: authenticated has an extra privilege.';
  end if;
end
$$;

commit;
