-- 利用者が自分のデッキを持てるようにする。
-- 計画: docs/plans/user-owned-decks-plan.md
--
-- 公式デッキは decks.owner_id IS NULL のままとし、認証利用者からは
-- これまでどおり読み取りだけにする。公式コンテンツ契約は変えない。
-- 個人デッキは owner_id = auth.uid() の行だけとし、本人だけが読み書きできる。
-- カードの所有者は decks.owner_id から引き、cards には所有者列を置かない。

begin;

-- 所有者ごとのデッキ名ユニークに UNIQUE NULLS NOT DISTINCT を使う。
-- PostgreSQL 15 以上でないと、公式デッキ（NULL）の重複を防げない。
do $$
begin
  if current_setting('server_version_num')::integer < 150000 then
    raise exception
      'This migration requires PostgreSQL 15 or newer (UNIQUE NULLS NOT DISTINCT); found %',
      current_setting('server_version');
  end if;
end;
$$;

-- 1. 所有者列

alter table public.decks
  add column if not exists owner_id uuid
    references public.users(id) on delete cascade;

comment on column public.decks.owner_id is
  'NULL は運営が配る公式デッキ。値があるときは、その利用者だけが読み書きできる個人デッキ。';

-- デッキ名の一意性は全体ではなく所有者ごとにする。
-- 公式どうし（NULL）も重複させないため NULLS NOT DISTINCT を使う。
alter table public.decks drop constraint if exists decks_deck_name_key;
alter table public.decks drop constraint if exists decks_owner_deck_name_key;
alter table public.decks
  add constraint decks_owner_deck_name_key
  unique nulls not distinct (owner_id, deck_name);

create index if not exists decks_owner_id_idx on public.decks (owner_id);

-- 2. 上限。1人が無制限に作れると、共有テーブルが1人の都合で膨らむ。

create or replace function public.enforce_user_deck_limit()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  deck_limit constant integer := 50;
  current_count integer;
begin
  if new.owner_id is null then
    return new;
  end if;

  select count(*) into current_count
  from public.decks
  where owner_id = new.owner_id;

  if current_count >= deck_limit then
    raise exception 'Deck limit reached: a user may own at most % decks', deck_limit
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_user_deck_limit on public.decks;
create trigger enforce_user_deck_limit
  before insert on public.decks
  for each row
  execute function public.enforce_user_deck_limit();

create or replace function public.enforce_user_deck_card_limit()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  card_limit constant integer := 2000;
  deck_owner uuid;
  current_count integer;
begin
  select owner_id into deck_owner from public.decks where id = new.deck_id;

  if deck_owner is null then
    return new;
  end if;

  select count(*) into current_count
  from public.cards
  where deck_id = new.deck_id;

  if current_count >= card_limit then
    raise exception 'Card limit reached: a personal deck may hold at most % cards', card_limit
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_user_deck_card_limit on public.cards;
create trigger enforce_user_deck_card_limit
  before insert on public.cards
  for each row
  execute function public.enforce_user_deck_card_limit();

-- 3. RLS。公式行は読むだけ、本人行は読み書き。

drop policy if exists decks_select_authenticated on public.decks;
drop policy if exists decks_select_official_or_own on public.decks;
drop policy if exists decks_insert_own on public.decks;
drop policy if exists decks_update_own on public.decks;
drop policy if exists decks_delete_own on public.decks;

create policy decks_select_official_or_own
  on public.decks
  for select
  to authenticated
  using (owner_id is null or owner_id = (select auth.uid()));

-- with check だけを持たせ、公式行（owner_id is null）は作らせない。
create policy decks_insert_own
  on public.decks
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

-- using と with check の両方を本人に固定し、自分の行を公式行へ
-- 昇格させたり、他人へ渡したりできないようにする。
create policy decks_update_own
  on public.decks
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy decks_delete_own
  on public.decks
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists cards_select_authenticated on public.cards;
drop policy if exists cards_select_official_or_own on public.cards;
drop policy if exists cards_insert_own on public.cards;
drop policy if exists cards_update_own on public.cards;
drop policy if exists cards_delete_own on public.cards;

create policy cards_select_official_or_own
  on public.cards
  for select
  to authenticated
  using (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and (d.owner_id is null or d.owner_id = (select auth.uid()))
    )
  );

create policy cards_insert_own
  on public.cards
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

create policy cards_update_own
  on public.cards
  for update
  to authenticated
  using (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

create policy cards_delete_own
  on public.cards
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.decks d
      where d.id = cards.deck_id
        and d.owner_id = (select auth.uid())
    )
  );

-- 個人デッキを消すときは、そのカードの進捗も消す必要がある。
drop policy if exists user_card_progress_delete_own on public.user_card_progress;
create policy user_card_progress_delete_own
  on public.user_card_progress
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 4. GRANT。RLSとGRANTは別の門なので、両方を開けないと機能しない。

grant insert, update, delete on table public.decks to authenticated;
grant insert, update, delete on table public.cards to authenticated;
grant delete on table public.user_card_progress to authenticated;

-- identity 列へ書き込むにはシーケンスの使用権が要る。
grant usage, select on sequence public.decks_id_seq to authenticated;
grant usage, select on sequence public.cards_id_seq to authenticated;

-- 5. 検証。ここまでの結果が揃っていなければ、適用せずに止める。

do $$
declare
  missing text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'decks' and column_name = 'owner_id'
  ) then
    raise exception 'decks.owner_id was not created';
  end if;

  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.decks'::regclass and conname = 'decks_deck_name_key'
  ) then
    raise exception 'decks_deck_name_key still blocks per-user deck names';
  end if;

  for missing in
    select expected.name
    from (values
      ('decks_select_official_or_own'),
      ('decks_insert_own'),
      ('decks_update_own'),
      ('decks_delete_own')
    ) as expected(name)
    where not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'decks' and policyname = expected.name
    )
  loop
    raise exception 'Missing policy on public.decks: %', missing;
  end loop;

  for missing in
    select expected.name
    from (values
      ('cards_select_official_or_own'),
      ('cards_insert_own'),
      ('cards_update_own'),
      ('cards_delete_own')
    ) as expected(name)
    where not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'cards' and policyname = expected.name
    )
  loop
    raise exception 'Missing policy on public.cards: %', missing;
  end loop;

  for missing in
    select expected.relname || '.' || expected.privilege
    from (values
      ('decks', 'INSERT'), ('decks', 'UPDATE'), ('decks', 'DELETE'),
      ('cards', 'INSERT'), ('cards', 'UPDATE'), ('cards', 'DELETE')
    ) as expected(relname, privilege)
    where not has_table_privilege('authenticated', 'public.' || expected.relname, expected.privilege)
  loop
    raise exception 'authenticated is missing a required table privilege: %', missing;
  end loop;

  -- 公式行が書けないままであることを、権限ではなくポリシー式で確かめる。
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'decks'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')
      and coalesce(qual, '') || coalesce(with_check, '') not like '%owner_id%'
  ) then
    raise exception 'A write policy on public.decks does not restrict owner_id';
  end if;
end;
$$;

commit;
