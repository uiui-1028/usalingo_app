-- 公式デッキの追加記録（user_added_decks）の権限確認。
-- 本人の記録だけが見え、公式デッキだけを追加でき、他人の名義では追加できないことが要点。
begin;
select plan(9);

select col_not_null('public', 'decks', 'is_starter', 'decks.is_starter is NOT NULL');
select col_default_is('public', 'decks', 'is_starter', 'false', 'new decks are not starters');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('a1a1a1a1-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'added-a@example.test', '', now(), now()),
  ('a1a1a1a1-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'added-b@example.test', '', now(), now())
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('a1a1a1a1-0000-0000-0000-000000000001', 'added-a@example.test'),
  ('a1a1a1a1-0000-0000-0000-000000000002', 'added-b@example.test')
on conflict (id) do nothing;

insert into public.decks (deck_name, owner_id) values
  ('Added Test Official', null),
  ('Added Test B Personal', 'a1a1a1a1-0000-0000-0000-000000000002');

insert into public.user_added_decks (user_id, deck_id)
select 'a1a1a1a1-0000-0000-0000-000000000002', id
from public.decks where deck_name = 'Added Test Official';

-- 匿名キーのままでは読めない。
set local role anon;
select throws_ok(
  $$select 1 from public.user_added_decks$$,
  '42501',
  null,
  'anon cannot read added decks'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"a1a1a1a1-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$insert into public.user_added_decks (user_id, deck_id)
    select 'a1a1a1a1-0000-0000-0000-000000000001', id
    from public.decks where deck_name = 'Added Test Official'$$,
  'A can add an official deck'
);

select results_eq(
  $$select user_id from public.user_added_decks$$,
  $$values ('a1a1a1a1-0000-0000-0000-000000000001'::uuid)$$,
  'A sees only its own added decks'
);

select throws_ok(
  $$insert into public.user_added_decks (user_id, deck_id)
    select 'a1a1a1a1-0000-0000-0000-000000000002', id
    from public.decks where deck_name = 'Added Test Official'$$,
  '42501',
  null,
  'A cannot add a deck in B''s name'
);

select throws_ok(
  $$insert into public.user_added_decks (user_id, deck_id)
    values ('a1a1a1a1-0000-0000-0000-000000000001', -1)$$,
  null,
  null,
  'A cannot add a deck that does not exist'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"a1a1a1a1-0000-0000-0000-000000000002","role":"authenticated"}';

select throws_ok(
  $$insert into public.user_added_decks (user_id, deck_id)
    select 'a1a1a1a1-0000-0000-0000-000000000002', id
    from public.decks where deck_name = 'Added Test B Personal'$$,
  '42501',
  null,
  'B cannot add a personal deck as an official one'
);

reset role;

delete from auth.users where id = 'a1a1a1a1-0000-0000-0000-000000000001';
select is_empty(
  $$select 1 from public.user_added_decks
    where user_id = 'a1a1a1a1-0000-0000-0000-000000000001'$$,
  'added decks are removed with the account'
);

select * from finish();
rollback;
