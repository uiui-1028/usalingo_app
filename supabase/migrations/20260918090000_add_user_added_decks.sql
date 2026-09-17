-- 公式デッキは「最初から出すもの」と「ギャラリーから追加するもの」に分ける。
--
-- 学習タブに並ぶ公式デッキ = is_starter の公式デッキ + 本人が追加した公式デッキ。
-- ギャラリーは、これまでどおり公式デッキ全件を読む（decks の select 権限は変えない）。
--
-- 最初から出すのは「大学受験1000語A」だけにする。
-- 追加の記録は本人だけが読み書きでき、公式デッキ以外は追加できない。

begin;

alter table public.decks
  add column is_starter boolean not null default false;

comment on column public.decks.is_starter is
  'True for official decks shown to every account without adding them from the gallery.';

update public.decks
set is_starter = true
where owner_id is null and deck_name = '大学受験1000語A';

create table public.user_added_decks (
  user_id uuid not null references public.users(id) on delete cascade,
  deck_id integer not null references public.decks(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, deck_id)
);

comment on table public.user_added_decks is
  'Official decks each account added from the deck gallery.';

create index user_added_decks_deck_id_idx on public.user_added_decks (deck_id);

alter table public.user_added_decks enable row level security;

revoke all on public.user_added_decks from anon, authenticated;
grant select, insert on public.user_added_decks to authenticated;

create policy user_added_decks_select_own
  on public.user_added_decks
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy user_added_decks_insert_own_official
  on public.user_added_decks
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.decks d
      where d.id = user_added_decks.deck_id and d.owner_id is null
    )
  );

-- すでに学習記録がある公式デッキは、追加済みとして扱う。
-- 一覧から消えて記録が見えなくなることを防ぐ。
insert into public.user_added_decks (user_id, deck_id)
select distinct p.user_id, c.deck_id
from public.user_card_progress p
join public.cards c on c.id = p.card_id
join public.decks d on d.id = c.deck_id
where d.owner_id is null and not d.is_starter
on conflict do nothing;

commit;
