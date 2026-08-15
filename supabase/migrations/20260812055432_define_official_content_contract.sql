-- Define the hand-off contract for operator-managed images and audio.
--
-- It configures Storage, validates asset paths, and narrows official-content DB
-- access. Existing content rows and Storage objects are never rewritten here.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Existing non-null paths must already follow the contract. Stop before changing
-- bucket configuration when production data needs a separate cleanup plan.
do $$
begin
  if exists (
    select 1
    from public.example_contents
    where image_asset_path is not null
      and (
        image_asset_path !~ '^content-images/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]webp$'
        or image_asset_path not like (
          '%/'
          || lpad(((id / 500) * 500)::text, 4, '0')
          || '-'
          || lpad((((id / 500) * 500) + 499)::text, 4, '0')
          || '/'
          || id::text
          || '.webp'
        )
      )
  ) then
    raise exception 'Official content contract stopped: an image_asset_path is invalid.';
  end if;

  if exists (
    select 1
    from public.example_contents
    where audio_asset_path is not null
      and (
        audio_asset_path !~ '^content-audio/example/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]mp3$'
        or audio_asset_path not like (
          '%/'
          || lpad(((id / 500) * 500)::text, 4, '0')
          || '-'
          || lpad((((id / 500) * 500) + 499)::text, 4, '0')
          || '/'
          || id::text
          || '.mp3'
        )
      )
  ) then
    raise exception 'Official content contract stopped: an audio_asset_path is invalid.';
  end if;

  -- Only the known legacy content-bucket policies may be replaced here. Stop
  -- when an unknown policy needs a separate human-reviewed decision.
  if exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (
        coalesce(qual, '') like '%content-images%'
        or coalesce(with_check, '') like '%content-images%'
        or coalesce(qual, '') like '%content-audio%'
        or coalesce(with_check, '') like '%content-audio%'
      )
      and policyname not in (
        'content_images_select_policy',
        'content_images_insert_policy',
        'content_images_update_policy',
        'content_images_delete_policy',
        'content_audio_select_policy',
        'content_audio_insert_policy',
        'content_audio_update_policy',
        'content_audio_delete_policy'
      )
  ) then
    raise exception 'Official content contract stopped: an unknown content bucket policy exists.';
  end if;
end
$$;

-- Public buckets are deliberate: the iOS app constructs stable public URLs and
-- the assets contain no user data. Public delivery does not grant upload,
-- replacement, move, or delete access.
insert into storage.buckets (id, name, public, allowed_mime_types)
values
  ('content-images', 'content-images', true, array['image/webp']::text[]),
  ('content-audio', 'content-audio', true, array['audio/mpeg']::text[])
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public delivery bypasses object SELECT policies. Remove the legacy policies,
-- especially authenticated writes based on email addresses or user folders.
drop policy if exists content_images_select_policy on storage.objects;
drop policy if exists content_images_insert_policy on storage.objects;
drop policy if exists content_images_update_policy on storage.objects;
drop policy if exists content_images_delete_policy on storage.objects;
drop policy if exists content_audio_select_policy on storage.objects;
drop policy if exists content_audio_insert_policy on storage.objects;
drop policy if exists content_audio_update_policy on storage.objects;
drop policy if exists content_audio_delete_policy on storage.objects;

alter table public.example_contents
  add constraint example_contents_image_asset_path_contract
  check (
    image_asset_path is null
    or (
      image_asset_path ~ '^content-images/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]webp$'
      and image_asset_path like (
        '%/'
        || lpad(((id / 500) * 500)::text, 4, '0')
        || '-'
        || lpad((((id / 500) * 500) + 499)::text, 4, '0')
        || '/'
        || id::text
        || '.webp'
      )
    )
  ),
  add constraint example_contents_audio_asset_path_contract
  check (
    audio_asset_path is null
    or (
      audio_asset_path ~ '^content-audio/example/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]mp3$'
      and audio_asset_path like (
        '%/'
        || lpad(((id / 500) * 500)::text, 4, '0')
        || '-'
        || lpad((((id / 500) * 500) + 499)::text, 4, '0')
        || '/'
        || id::text
        || '.mp3'
      )
    )
  );

comment on column public.example_contents.image_asset_path is
  'Optional public Storage path: content-images/<theme-slug>/<range>/<example-id>.webp.';
comment on column public.example_contents.audio_asset_path is
  'Optional public Storage path: content-audio/example/<theme-slug>/<range>/<example-id>.mp3.';

-- Official DB content is readable only after sign-in. Broad table grants and
-- write-deny policies from the old setup are replaced with one explicit SELECT
-- policy per table. Operators write with service_role outside the iOS app.
alter table public.words enable row level security;
alter table public.word_meanings enable row level security;
alter table public.example_contents enable row level security;
alter table public.decks enable row level security;
alter table public.deck_words enable row level security;

drop policy if exists words_select_policy on public.words;
drop policy if exists words_insert_policy on public.words;
drop policy if exists words_update_policy on public.words;
drop policy if exists words_delete_policy on public.words;
drop policy if exists word_meanings_select_policy on public.word_meanings;
drop policy if exists word_meanings_insert_policy on public.word_meanings;
drop policy if exists word_meanings_update_policy on public.word_meanings;
drop policy if exists word_meanings_delete_policy on public.word_meanings;
drop policy if exists example_contents_select_policy on public.example_contents;
drop policy if exists example_contents_insert_policy on public.example_contents;
drop policy if exists example_contents_update_policy on public.example_contents;
drop policy if exists example_contents_delete_policy on public.example_contents;
drop policy if exists decks_select_policy on public.decks;
drop policy if exists decks_insert_policy on public.decks;
drop policy if exists decks_update_policy on public.decks;
drop policy if exists decks_delete_policy on public.decks;
drop policy if exists deck_words_select_policy on public.deck_words;
drop policy if exists deck_words_insert_policy on public.deck_words;
drop policy if exists deck_words_update_policy on public.deck_words;
drop policy if exists deck_words_delete_policy on public.deck_words;

create policy words_select_authenticated
  on public.words for select to authenticated using (true);
create policy word_meanings_select_authenticated
  on public.word_meanings for select to authenticated using (true);
create policy example_contents_select_authenticated
  on public.example_contents for select to authenticated using (true);
create policy decks_select_authenticated
  on public.decks for select to authenticated using (true);
create policy deck_words_select_authenticated
  on public.deck_words for select to authenticated using (true);

revoke all on table public.words from public, anon, authenticated;
revoke all on table public.word_meanings from public, anon, authenticated;
revoke all on table public.example_contents from public, anon, authenticated;
revoke all on table public.decks from public, anon, authenticated;
revoke all on table public.deck_words from public, anon, authenticated;

grant select on table public.words to authenticated;
grant select on table public.word_meanings to authenticated;
grant select on table public.example_contents to authenticated;
grant select on table public.decks to authenticated;
grant select on table public.deck_words to authenticated;

grant select, insert, update, delete on table public.words to service_role;
grant select, insert, update, delete on table public.word_meanings to service_role;
grant select, insert, update, delete on table public.example_contents to service_role;
grant select, insert, update, delete on table public.decks to service_role;
grant select, insert, update, delete on table public.deck_words to service_role;

-- No anon/authenticated write policy is created on storage.objects. Operators
-- upload from a trusted environment with service_role, which bypasses RLS. This
-- key must never be embedded in the iOS app.

-- Migration-level verification: bucket access model and constraints must exist.
do $$
declare
  target_table text;
begin
  if (
    select count(*)
    from storage.buckets
    where id in ('content-images', 'content-audio')
      and public = true
  ) <> 2 then
    raise exception 'Official content contract verification failed: public buckets are missing.';
  end if;

  if (
    select count(*)
    from pg_constraint
    where conrelid = 'public.example_contents'::regclass
      and conname in (
        'example_contents_image_asset_path_contract',
        'example_contents_audio_asset_path_contract'
      )
      and contype = 'c'
      and convalidated = true
  ) <> 2 then
    raise exception 'Official content contract verification failed: path constraints are missing.';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (
        coalesce(qual, '') like '%content-images%'
        or coalesce(with_check, '') like '%content-images%'
        or coalesce(qual, '') like '%content-audio%'
        or coalesce(with_check, '') like '%content-audio%'
      )
  ) then
    raise exception 'Official content contract verification failed: a client Storage policy remains.';
  end if;

  foreach target_table in array array[
    'words',
    'word_meanings',
    'example_contents',
    'decks',
    'deck_words'
  ] loop
    if has_table_privilege('anon', format('public.%I', target_table), 'select')
       or not has_table_privilege('authenticated', format('public.%I', target_table), 'select')
       or has_table_privilege('authenticated', format('public.%I', target_table), 'insert')
       or has_table_privilege('authenticated', format('public.%I', target_table), 'update')
       or has_table_privilege('authenticated', format('public.%I', target_table), 'delete')
       or not has_table_privilege('service_role', format('public.%I', target_table), 'select')
       or not has_table_privilege('service_role', format('public.%I', target_table), 'insert')
       or not has_table_privilege('service_role', format('public.%I', target_table), 'update')
       or not has_table_privilege('service_role', format('public.%I', target_table), 'delete') then
      raise exception 'Official content contract verification failed: grants for % are incorrect.', target_table;
    end if;
  end loop;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'words',
        'word_meanings',
        'example_contents',
        'decks',
        'deck_words'
      )
      and cmd = 'SELECT'
      and 'authenticated' = any(roles)
  ) <> 5
  or exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'words',
        'word_meanings',
        'example_contents',
        'decks',
        'deck_words'
      )
      and cmd <> 'SELECT'
  ) then
    raise exception 'Official content contract verification failed: DB policies are not read-only.';
  end if;
end
$$;

commit;
