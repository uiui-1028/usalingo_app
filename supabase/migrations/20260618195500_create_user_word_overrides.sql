create table if not exists public.user_word_overrides (
  user_id uuid not null references public.users(id) on delete cascade,
  word_id integer not null references public.words(id) on delete cascade,
  word_text text,
  definition_jp text,
  sentence_en text,
  sentence_jp text,
  image_asset_path text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (user_id, word_id)
);

alter table public.user_word_overrides enable row level security;

create index if not exists idx_user_word_overrides_user_word
  on public.user_word_overrides (user_id, word_id);

create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_user_word_overrides_updated_at on public.user_word_overrides;
create trigger update_user_word_overrides_updated_at
  before update on public.user_word_overrides
  for each row
  execute function public.update_updated_at_column();

drop policy if exists "user_word_overrides_select_own" on public.user_word_overrides;
create policy "user_word_overrides_select_own"
  on public.user_word_overrides
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_word_overrides_insert_own" on public.user_word_overrides;
create policy "user_word_overrides_insert_own"
  on public.user_word_overrides
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_word_overrides_update_own" on public.user_word_overrides;
create policy "user_word_overrides_update_own"
  on public.user_word_overrides
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_word_overrides_delete_own" on public.user_word_overrides;
create policy "user_word_overrides_delete_own"
  on public.user_word_overrides
  for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.user_word_overrides is 'User-specific vocabulary edits layered on top of canonical content.';
