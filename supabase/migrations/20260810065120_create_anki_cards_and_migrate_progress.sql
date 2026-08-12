-- Build the Anki-aligned Card layer without removing the legacy word-based data.
--
-- Safety properties:
-- - abort before DDL when legacy rows cannot be mapped without loss
-- - keep deck_words and user_learning_progress unchanged for rollback
-- - expose only the minimum Data API privileges
-- - verify every backfilled row before commit

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Phase 0: stop before any schema change if the current data is unsafe to map.
do $$
begin
  if to_regclass('public.cards') is not null then
    raise exception 'Migration stopped: public.cards already exists.';
  end if;

  if to_regclass('public.user_card_progress') is not null then
    raise exception 'Migration stopped: public.user_card_progress already exists.';
  end if;

  if exists (select 1 from public.card_templates) then
    raise exception 'Migration stopped: existing card_templates require an explicit mapping.';
  end if;

  if exists (
    select 1
    from public.deck_words as dw
    left join public.decks as d on d.id = dw.deck_id
    left join public.words as w on w.id = dw.word_id
    where d.id is null or w.id is null
  ) then
    raise exception 'Migration stopped: deck_words contains an orphan deck_id or word_id.';
  end if;

  if exists (
    select 1
    from public.user_learning_progress as ulp
    left join public.words as w on w.id = ulp.word_id
    where w.id is null
  ) then
    raise exception 'Migration stopped: user_learning_progress contains an unknown word_id.';
  end if;

  if exists (
    select 1
    from public.user_learning_progress as ulp
    where not exists (
      select 1
      from public.deck_words as dw
      where dw.word_id = ulp.word_id
    )
  ) then
    raise exception 'Migration stopped: a progress row has no destination deck card.';
  end if;

  if exists (
    select 1
    from public.user_learning_progress as ulp
    where ulp.status is null
       or ulp.status not in ('learning', 'review', 'mastered')
       or ulp.next_review_date is null
       or ulp.srs_level is null
       or ulp.srs_level not between 1 and 5
       or ulp.easiness_factor is null
       or ulp.easiness_factor < 1.3
       or ulp.repetitions is null
       or ulp.repetitions < 0
       or ulp.incorrect_count is null
       or ulp.incorrect_count < 0
       or ulp.interval_days is null
       or ulp.interval_days < 0
       or ulp.created_at is null
       or ulp.updated_at is null
  ) then
    raise exception 'Migration stopped: a progress row violates the target constraints.';
  end if;
end
$$;

-- Phase 1: evolve the existing Card Type table.
alter table public.card_templates
  add column template_code text,
  add column direction text,
  add column is_active boolean not null default true;

insert into public.card_templates (
  template_code,
  template_name,
  direction,
  surface_a_items,
  surface_b_items,
  is_active
)
values (
  'basic_en_to_ja',
  '英語 → 日本語',
  'en_to_ja',
  array['word_text', 'image_asset_path']::text[],
  array['definition_jp', 'sentence_en', 'sentence_jp', 'audio_asset_path']::text[],
  true
);

alter table public.card_templates
  alter column template_code set not null,
  alter column direction set not null,
  add constraint card_templates_template_code_key unique (template_code),
  add constraint card_templates_template_code_not_blank
    check (length(trim(template_code)) > 0),
  add constraint card_templates_direction_allowed
    check (direction in ('en_to_ja', 'ja_to_en')),
  add constraint card_templates_surface_a_items_allowed
    check (
      surface_a_items <@ array[
        'word_text',
        'definition_jp',
        'part_of_speech_en',
        'sentence_en',
        'sentence_jp',
        'image_asset_path',
        'audio_asset_path'
      ]::text[]
    ),
  add constraint card_templates_surface_b_items_allowed
    check (
      surface_b_items <@ array[
        'word_text',
        'definition_jp',
        'part_of_speech_en',
        'sentence_en',
        'sentence_jp',
        'image_asset_path',
        'audio_asset_path'
      ]::text[]
    );

comment on column public.card_templates.template_code is
  'Stable application-facing Card Type identifier.';
comment on column public.card_templates.direction is
  'Question-to-answer direction used by the study client.';
comment on column public.card_templates.is_active is
  'Whether this Card Type can generate and display Cards.';

-- Phase 1: add Card and Card-level progress tables.
create table public.cards (
  id bigint generated always as identity primary key,
  word_id integer not null
    references public.words(id) on delete restrict,
  card_template_id integer not null
    references public.card_templates(id) on delete restrict,
  deck_id integer not null
    references public.decks(id) on delete restrict,
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cards_sort_order_nonnegative check (sort_order >= 0),
  constraint cards_word_template_deck_key
    unique (word_id, card_template_id, deck_id)
);

create table public.user_card_progress (
  user_id uuid not null
    references public.users(id) on delete cascade,
  card_id bigint not null
    references public.cards(id) on delete restrict,
  status text not null default 'learning',
  last_reviewed_at timestamptz,
  next_review_date timestamptz not null,
  srs_level integer not null default 1,
  easiness_factor real not null default 2.5,
  repetitions integer not null default 0,
  incorrect_count integer not null default 0,
  interval_days integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, card_id),
  constraint user_card_progress_status_allowed
    check (status in ('learning', 'review', 'mastered')),
  constraint user_card_progress_srs_level_range
    check (srs_level between 1 and 5),
  -- Existing production rows reach 2.65. Preserve them during migration;
  -- the client-side scheduler will clamp newly calculated values to 2.5.
  constraint user_card_progress_easiness_factor_minimum
    check (easiness_factor >= 1.3),
  constraint user_card_progress_repetitions_nonnegative
    check (repetitions >= 0),
  constraint user_card_progress_incorrect_count_nonnegative
    check (incorrect_count >= 0),
  constraint user_card_progress_interval_days_nonnegative
    check (interval_days >= 0)
);

comment on table public.cards is
  'Operator-managed learning Cards generated from a Note root, Card Type, and Deck.';
comment on table public.user_card_progress is
  'Latest scheduling state for one user and one Card.';

create index cards_deck_active_order_idx
  on public.cards (deck_id, is_active, sort_order, id);
create index cards_card_template_id_idx
  on public.cards (card_template_id);

create index user_card_progress_due_idx
  on public.user_card_progress (user_id, next_review_date, card_id);
create index user_card_progress_status_idx
  on public.user_card_progress (user_id, status);
create index user_card_progress_weak_idx
  on public.user_card_progress (user_id, incorrect_count desc, card_id)
  where incorrect_count >= 3;
create index user_card_progress_card_id_idx
  on public.user_card_progress (card_id);

create trigger update_cards_updated_at
  before update on public.cards
  for each row
  execute function public.update_updated_at_column();

create trigger update_user_card_progress_updated_at
  before update on public.user_card_progress
  for each row
  execute function public.update_updated_at_column();

-- Data API and RLS are separate gates. Grant only what the app needs.
alter table public.card_templates enable row level security;
alter table public.cards enable row level security;
alter table public.user_card_progress enable row level security;

drop policy if exists card_templates_select_policy on public.card_templates;
drop policy if exists card_templates_insert_policy on public.card_templates;
drop policy if exists card_templates_update_policy on public.card_templates;
drop policy if exists card_templates_delete_policy on public.card_templates;

create policy card_templates_select_authenticated
  on public.card_templates
  for select
  to authenticated
  using (is_active = true);

create policy cards_select_authenticated
  on public.cards
  for select
  to authenticated
  using (is_active = true);

create policy user_card_progress_select_own
  on public.user_card_progress
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy user_card_progress_insert_own
  on public.user_card_progress
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy user_card_progress_update_own
  on public.user_card_progress
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.card_templates from public, anon, authenticated;
revoke all on table public.cards from public, anon, authenticated;
revoke all on table public.user_card_progress from public, anon, authenticated;
revoke all on sequence public.card_templates_id_seq from public, anon, authenticated;
revoke all on sequence public.cards_id_seq from public, anon, authenticated;

grant select on table public.card_templates to authenticated;
grant select on table public.cards to authenticated;
grant select, insert, update on table public.user_card_progress to authenticated;

grant select, insert, update, delete on table public.card_templates to service_role;
grant select, insert, update, delete on table public.cards to service_role;
grant select, insert, update, delete on table public.user_card_progress to service_role;
grant usage, select on sequence public.card_templates_id_seq to service_role;
grant usage, select on sequence public.cards_id_seq to service_role;

-- Phase 2: generate one active English-to-Japanese Card per deck_words row.
insert into public.cards (
  word_id,
  card_template_id,
  deck_id,
  sort_order,
  is_active
)
select
  ranked.word_id,
  ct.id,
  ranked.deck_id,
  ranked.sort_order,
  true
from (
  select
    dw.word_id,
    dw.deck_id,
    row_number() over (
      partition by dw.deck_id
      order by dw.word_id
    )::integer - 1 as sort_order
  from public.deck_words as dw
) as ranked
cross join public.card_templates as ct
where ct.template_code = 'basic_en_to_ja'
  and ct.is_active = true
on conflict (word_id, card_template_id, deck_id)
do update set
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

-- Phase 3: fan out legacy word progress to every corresponding Deck Card.
insert into public.user_card_progress (
  user_id,
  card_id,
  status,
  last_reviewed_at,
  next_review_date,
  srs_level,
  easiness_factor,
  repetitions,
  incorrect_count,
  interval_days,
  created_at,
  updated_at
)
select
  ulp.user_id,
  c.id,
  ulp.status,
  ulp.last_reviewed_at,
  ulp.next_review_date,
  ulp.srs_level,
  ulp.easiness_factor,
  ulp.repetitions,
  ulp.incorrect_count,
  ulp.interval_days,
  ulp.created_at,
  ulp.updated_at
from public.user_learning_progress as ulp
join public.cards as c on c.word_id = ulp.word_id
join public.card_templates as ct on ct.id = c.card_template_id
where ct.template_code = 'basic_en_to_ja'
  and c.is_active = true
on conflict (user_id, card_id)
do update set
  status = excluded.status,
  last_reviewed_at = excluded.last_reviewed_at,
  next_review_date = excluded.next_review_date,
  srs_level = excluded.srs_level,
  easiness_factor = excluded.easiness_factor,
  repetitions = excluded.repetitions,
  incorrect_count = excluded.incorrect_count,
  interval_days = excluded.interval_days,
  created_at = excluded.created_at,
  updated_at = excluded.updated_at;

-- Final gate: any mismatch rolls back this entire migration.
do $$
declare
  expected_card_count bigint;
  actual_card_count bigint;
  expected_progress_count bigint;
  actual_progress_count bigint;
begin
  select count(*)
  into expected_card_count
  from public.deck_words;

  select count(*)
  into actual_card_count
  from public.cards as c
  join public.card_templates as ct on ct.id = c.card_template_id
  where ct.template_code = 'basic_en_to_ja'
    and c.is_active = true;

  if actual_card_count <> expected_card_count then
    raise exception
      'Migration verification failed: expected % Cards, found %.',
      expected_card_count,
      actual_card_count;
  end if;

  if exists (
    select 1
    from public.deck_words as dw
    left join public.card_templates as ct
      on ct.template_code = 'basic_en_to_ja'
     and ct.is_active = true
    left join public.cards as c
      on c.word_id = dw.word_id
     and c.deck_id = dw.deck_id
     and c.card_template_id = ct.id
     and c.is_active = true
    where c.id is null
  ) then
    raise exception 'Migration verification failed: a deck_words row has no Card.';
  end if;

  select count(*)
  into expected_progress_count
  from public.user_learning_progress as ulp
  join public.cards as c on c.word_id = ulp.word_id
  join public.card_templates as ct on ct.id = c.card_template_id
  where ct.template_code = 'basic_en_to_ja'
    and c.is_active = true;

  select count(*)
  into actual_progress_count
  from public.user_card_progress;

  if actual_progress_count <> expected_progress_count then
    raise exception
      'Migration verification failed: expected % progress rows, found %.',
      expected_progress_count,
      actual_progress_count;
  end if;

  if exists (
    select 1
    from public.user_learning_progress as ulp
    join public.cards as c on c.word_id = ulp.word_id
    join public.card_templates as ct on ct.id = c.card_template_id
    left join public.user_card_progress as ucp
      on ucp.user_id = ulp.user_id
     and ucp.card_id = c.id
    where ct.template_code = 'basic_en_to_ja'
      and c.is_active = true
      and (
        ucp.card_id is null
        or ucp.status is distinct from ulp.status
        or ucp.last_reviewed_at is distinct from ulp.last_reviewed_at
        or ucp.next_review_date is distinct from ulp.next_review_date
        or ucp.srs_level is distinct from ulp.srs_level
        or ucp.easiness_factor is distinct from ulp.easiness_factor
        or ucp.repetitions is distinct from ulp.repetitions
        or ucp.incorrect_count is distinct from ulp.incorrect_count
        or ucp.interval_days is distinct from ulp.interval_days
        or ucp.created_at is distinct from ulp.created_at
        or ucp.updated_at is distinct from ulp.updated_at
      )
  ) then
    raise exception 'Migration verification failed: a copied progress row differs from legacy data.';
  end if;

  if has_table_privilege('anon', 'public.card_templates', 'select')
     or has_table_privilege('anon', 'public.cards', 'select')
     or has_table_privilege('anon', 'public.user_card_progress', 'select') then
    raise exception 'Migration verification failed: anon can read an Anki core table.';
  end if;

  if not has_table_privilege('authenticated', 'public.card_templates', 'select')
     or not has_table_privilege('authenticated', 'public.cards', 'select')
     or not has_table_privilege('authenticated', 'public.user_card_progress', 'select')
     or not has_table_privilege('authenticated', 'public.user_card_progress', 'insert')
     or not has_table_privilege('authenticated', 'public.user_card_progress', 'update') then
    raise exception 'Migration verification failed: authenticated is missing an app privilege.';
  end if;

  if has_table_privilege('authenticated', 'public.card_templates', 'insert')
     or has_table_privilege('authenticated', 'public.card_templates', 'update')
     or has_table_privilege('authenticated', 'public.card_templates', 'delete')
     or has_table_privilege('authenticated', 'public.cards', 'insert')
     or has_table_privilege('authenticated', 'public.cards', 'update')
     or has_table_privilege('authenticated', 'public.cards', 'delete')
     or has_table_privilege('authenticated', 'public.user_card_progress', 'delete') then
    raise exception 'Migration verification failed: authenticated has an extra write privilege.';
  end if;

  if has_sequence_privilege('anon', 'public.card_templates_id_seq', 'usage')
     or has_sequence_privilege('anon', 'public.cards_id_seq', 'usage')
     or has_sequence_privilege('authenticated', 'public.card_templates_id_seq', 'usage')
     or has_sequence_privilege('authenticated', 'public.cards_id_seq', 'usage') then
    raise exception 'Migration verification failed: an app role can use an operator sequence.';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'card_templates'
      and policyname = 'card_templates_select_authenticated'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ) or not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'cards'
      and policyname = 'cards_select_authenticated'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ) then
    raise exception 'Migration verification failed: an official-content RLS policy is missing.';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_card_progress'
      and policyname = 'user_card_progress_select_own'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  ) or not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_card_progress'
      and policyname = 'user_card_progress_insert_own'
      and cmd = 'INSERT'
      and roles = array['authenticated']::name[]
  ) or not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'user_card_progress'
      and policyname = 'user_card_progress_update_own'
      and cmd = 'UPDATE'
      and roles = array['authenticated']::name[]
  ) then
    raise exception 'Migration verification failed: an ownership RLS policy is missing.';
  end if;
end
$$;

commit;
