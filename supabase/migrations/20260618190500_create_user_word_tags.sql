create table if not exists public.user_word_tags (
  user_id uuid not null references public.users(id) on delete cascade,
  word_id integer not null references public.words(id) on delete cascade,
  tag text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (user_id, word_id, tag),
  constraint user_word_tags_tag_not_blank check (length(trim(tag)) > 0)
);

alter table public.user_word_tags enable row level security;

create index if not exists idx_user_word_tags_user_word
  on public.user_word_tags (user_id, word_id);

create index if not exists idx_user_word_tags_tag
  on public.user_word_tags (tag);

create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_user_word_tags_updated_at on public.user_word_tags;
create trigger update_user_word_tags_updated_at
  before update on public.user_word_tags
  for each row
  execute function public.update_updated_at_column();

drop policy if exists "user_word_tags_select_own" on public.user_word_tags;
create policy "user_word_tags_select_own"
  on public.user_word_tags
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_word_tags_insert_own" on public.user_word_tags;
create policy "user_word_tags_insert_own"
  on public.user_word_tags
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_word_tags_update_own" on public.user_word_tags;
create policy "user_word_tags_update_own"
  on public.user_word_tags
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_word_tags_delete_own" on public.user_word_tags;
create policy "user_word_tags_delete_own"
  on public.user_word_tags
  for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.user_word_tags is 'User-specific tags attached to vocabulary words.';
