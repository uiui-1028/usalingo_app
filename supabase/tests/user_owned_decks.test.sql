-- 個人デッキの権限確認。
-- 計画書 docs/plans/user-owned-decks-plan.md の「8. 検証項目」を実際に触って確かめる。
-- 公式デッキ（owner_id is null）は読むだけ、本人デッキは読み書きできることが要点。
begin;
select plan(13);

-- 検証用の利用者を2人と、公式デッキを1件用意する。
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'deck-a@example.test', '', now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'deck-b@example.test', '', now(), now())
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'deck-a@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'deck-b@example.test')
on conflict (id) do nothing;

insert into public.decks (deck_name, description, owner_id)
values ('Official Test Deck', 'official', null);

-- B の個人デッキ。A から見えないこと・触れないことの確認用。
insert into public.decks (deck_name, description, owner_id)
values ('B Personal Deck', 'owned by b', '22222222-2222-2222-2222-222222222222');

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

-- ① 本人は自分のデッキを作れる
select lives_ok(
  $$insert into public.decks (deck_name, description, owner_id)
    values ('A Personal Deck', 'owned by a', '11111111-1111-1111-1111-111111111111')$$,
  'A can create its own deck'
);

-- ② 見えるのは公式と自分のものだけ
select results_eq(
  $$select deck_name from public.decks
    where deck_name in ('Official Test Deck', 'A Personal Deck', 'B Personal Deck')
    order by deck_name$$,
  array['A Personal Deck', 'Official Test Deck'],
  'A sees official decks and its own deck only'
);

-- ③ 自分のデッキは改名できる
select lives_ok(
  $$update public.decks set deck_name = 'A Renamed Deck'
    where owner_id = '11111111-1111-1111-1111-111111111111'$$,
  'A can rename its own deck'
);

-- ④ 公式デッキは作れない・書き換えられない・消せない
select throws_ok(
  $$insert into public.decks (deck_name, owner_id) values ('Fake Official', null)$$,
  '42501',
  null,
  'A cannot create an official deck'
);

with updated as (
  update public.decks set deck_name = 'Hijacked'
  where deck_name = 'Official Test Deck'
  returning 1
)
select is(
  (select count(*)::integer from updated),
  0,
  'A cannot update an official deck'
);

with deleted as (
  delete from public.decks where deck_name = 'Official Test Deck' returning 1
)
select is(
  (select count(*)::integer from deleted),
  0,
  'A cannot delete an official deck'
);

-- ⑤ 他人のデッキは読めない・触れない
select is_empty(
  $$select 1 from public.decks where deck_name = 'B Personal Deck'$$,
  'A cannot read another user deck'
);

select throws_ok(
  $$insert into public.decks (deck_name, owner_id)
    values ('Spoofed', '22222222-2222-2222-2222-222222222222')$$,
  '42501',
  null,
  'A cannot create a deck owned by another user'
);

-- ⑥ 自分のデッキを公式行へ昇格させられない
select throws_ok(
  $$update public.decks set owner_id = null
    where owner_id = '11111111-1111-1111-1111-111111111111'$$,
  '42501',
  null,
  'A cannot promote its own deck to an official deck'
);

-- ⑦ カードは所属デッキの持ち主で決まる
select lives_ok(
  $$insert into public.cards (word_id, card_template_id, deck_id, sort_order)
    select w.id, t.id, d.id, 0
    from public.words w, public.card_templates t, public.decks d
    where d.owner_id = '11111111-1111-1111-1111-111111111111'
    order by w.id, t.id
    limit 1$$,
  'A can add a card to its own deck'
);

with deleted as (
  delete from public.cards c
  using public.decks d
  where c.deck_id = d.id and d.owner_id is null
  returning 1
)
select is(
  (select count(*)::integer from deleted),
  0,
  'A cannot delete a card in an official deck'
);

-- ⑧ 1人あたりのデッキ数に上限がある（共有テーブルが1人の都合で膨らまないように）
insert into public.decks (deck_name, owner_id)
select 'A Bulk Deck ' || i, '11111111-1111-1111-1111-111111111111'
from generate_series(1, 49) as i;

select throws_ok(
  $$insert into public.decks (deck_name, owner_id)
    values ('A Deck 51', '11111111-1111-1111-1111-111111111111')$$,
  '23514',
  null,
  'A cannot own more than 50 decks'
);

-- ⑨ 同じ名前でも、持ち主が違えば作れる
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select lives_ok(
  $$insert into public.decks (deck_name, owner_id)
    values ('A Renamed Deck', '22222222-2222-2222-2222-222222222222')$$,
  'B can use a deck name that A already uses'
);

select * from finish();
rollback;
