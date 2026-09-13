-- デッキ（箱）が世界観を1つ持てるようにする。USL-298
--
-- 1単語の意味ごとに、世界観（simple / horror / …）別の例文がある。
-- どの例文を出すかは箱が決める。cards に example_id を持たせると、例文を
-- 作り直すたびにカードIDが変わり user_card_progress が孤児になるため採用しない。
-- cards と user_card_progress はこの migration で変えない。
--
-- 公開範囲は広げない。decks の RLS と GRANT はそのまま。
-- content_concepts は既に authenticated から読めるので、参照先も増えない。

begin;

-- 1. 既定値。DEFAULT に副問い合わせは書けないため、simple の id を返す関数を使う。
--    id を定数で書くと、環境ごとに採番が違ったときに別の世界観を指してしまう。

create or replace function public.default_content_concept_id()
returns integer
language sql
stable
security invoker
set search_path = ''
as $$
  select id from public.content_concepts where concept_code = 'simple'
$$;

revoke all on function public.default_content_concept_id() from public, anon;
grant execute on function public.default_content_concept_id() to authenticated, service_role;

comment on function public.default_content_concept_id() is
  'decks.concept_id の既定値。標準の世界観 simple の id を返す。';

-- 2. 列。既存行を simple で埋めてから NOT NULL にする。

alter table public.decks
  add column if not exists concept_id integer;

update public.decks
set concept_id = public.default_content_concept_id()
where concept_id is null;

alter table public.decks
  alter column concept_id set default public.default_content_concept_id(),
  alter column concept_id set not null,
  add constraint decks_concept_id_fkey
    foreign key (concept_id) references public.content_concepts(id) on delete restrict;

create index if not exists decks_concept_id_idx on public.decks (concept_id);

comment on column public.decks.concept_id is
  'このデッキで出す例文・画像の世界観。既定は simple。';

-- 3. 検証。揃っていなければ適用せずに止める。

do $$
begin
  if public.default_content_concept_id() is null then
    raise exception 'USL-298 stopped: simple concept is missing.';
  end if;
  if exists (select 1 from public.decks where concept_id is null) then
    raise exception 'USL-298 stopped: a deck row was not backfilled.';
  end if;
  if has_function_privilege('anon', 'public.default_content_concept_id()', 'execute')
    or not has_function_privilege('authenticated', 'public.default_content_concept_id()', 'execute') then
    raise exception 'USL-298 stopped: grants for default_content_concept_id are incorrect.';
  end if;
  if has_table_privilege('anon', 'public.decks', 'select') then
    raise exception 'USL-298 stopped: anon can read decks.';
  end if;
end
$$;

commit;
