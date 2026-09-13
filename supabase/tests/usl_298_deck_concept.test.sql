-- USL-298: デッキが世界観（concept_id）を持てること。
-- 既存行が simple で埋まり、新しい行も simple になり、公開範囲が広がらないことを確かめる。
begin;
select plan(8);

select col_not_null('public', 'decks', 'concept_id', 'decks.concept_id is NOT NULL');

select fk_ok(
  'public', 'decks', 'concept_id',
  'public', 'content_concepts', 'id',
  'decks.concept_id references content_concepts'
);

select is_empty(
  $$select 1 from public.decks as deck
    join public.content_concepts as concept on concept.id = deck.concept_id
    where concept.concept_code <> 'simple'$$,
  'existing decks default to simple'
);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('29829829-8298-2982-9829-829829829829', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'usl-298@example.test', '', now(), now())
on conflict (id) do nothing;

insert into public.users (id, email)
values ('29829829-8298-2982-9829-829829829829', 'usl-298@example.test')
on conflict (id) do nothing;

-- 世界観を指定しない公式デッキも simple になる。
insert into public.decks (deck_name, description, owner_id)
values ('USL-298 Official Deck', 'official', null);

select results_eq(
  $$select concept.concept_code from public.decks as deck
    join public.content_concepts as concept on concept.id = deck.concept_id
    where deck.deck_name = 'USL-298 Official Deck'$$,
  array['simple'],
  'a new official deck defaults to simple'
);

select throws_ok(
  $$insert into public.decks (deck_name, owner_id, concept_id) values ('USL-298 Bad Deck', null, -1)$$,
  '23503',
  null,
  'an unknown concept is rejected'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"29829829-8298-2982-9829-829829829829","role":"authenticated"}';

-- 利用者が作る個人デッキも、既定値の関数を通って simple になる。
select lives_ok(
  $$insert into public.decks (deck_name, owner_id)
    values ('USL-298 Personal Deck', '29829829-8298-2982-9829-829829829829')$$,
  'an authenticated user can create a deck without naming a concept'
);

select results_eq(
  $$select concept.concept_code from public.decks as deck
    join public.content_concepts as concept on concept.id = deck.concept_id
    where deck.deck_name = 'USL-298 Personal Deck'$$,
  array['simple'],
  'a new personal deck defaults to simple'
);

reset role;

select ok(
  not has_table_privilege('anon', 'public.decks', 'select')
    and not has_function_privilege('anon', 'public.default_content_concept_id()', 'execute'),
  'anon still cannot read decks or call the default function'
);

select * from finish();
rollback;
