-- 公式デッキを10枚ずつに分ける。
--
-- これまで公式デッキは「Starter Deck」1つに50枚まとめて入っていた。
-- 1回で終わる量に区切るため、10枚ずつの公式デッキを6つにする。
--
--   Starter Deck  … 1〜10語目
--   デッキ 2      … 11〜20語目
--   デッキ 3      … 21〜30語目
--   デッキ 4      … 31〜40語目
--   デッキ 5      … 41〜50語目
--   デッキ 6      … 1〜10語目（Starter Deck と同じ10語）
--
-- 単語は50語しかないため、6つ目だけ Starter Deck と同じ語を使い回す。
--
-- Starter Deck の11枚目以降は**消さない**。`cards` は
-- `user_card_progress` から参照されており、消すと学習記録ごと消えるか、
-- 外部キー（restrict）で止まる。出題から外すだけにして `is_active` を false にする。

begin;

-- 1. Starter Deck を先頭10枚だけ出題する形にする。

with ranked as (
  select c.id, row_number() over (order by c.sort_order, c.id) as rn
  from public.cards c
  join public.decks d on d.id = c.deck_id
  where d.owner_id is null and d.deck_name = 'Starter Deck'
)
update public.cards c
set is_active = (ranked.rn <= 10)
from ranked
where ranked.id = c.id
  and c.is_active <> (ranked.rn <= 10);

-- 2. 残り5つの公式デッキを作る。名前は中身を主張しない仮名にする。
--    テーマ分けは教材が増えてから決める。

insert into public.decks (deck_name, description, owner_id)
values
  ('デッキ 2', '本番の単語を10枚ずつに分けたもの。テーマ分けはまだ仮です。', null),
  ('デッキ 3', '本番の単語を10枚ずつに分けたもの。テーマ分けはまだ仮です。', null),
  ('デッキ 4', '本番の単語を10枚ずつに分けたもの。テーマ分けはまだ仮です。', null),
  ('デッキ 5', '本番の単語を10枚ずつに分けたもの。テーマ分けはまだ仮です。', null),
  ('デッキ 6', 'Starter Deck と同じ10語。単語が増えるまでの仮の並びです。', null)
on conflict on constraint decks_owner_deck_name_key do nothing;

-- 3. それぞれへ10枚ずつ入れる。
--    語の順番は Starter Deck の並び（sort_order, id）をそのまま使う。

with source as (
  select c.word_id, c.card_template_id,
         row_number() over (order by c.sort_order, c.id) as rn
  from public.cards c
  join public.decks d on d.id = c.deck_id
  where d.owner_id is null and d.deck_name = 'Starter Deck'
),
assignment as (
  select * from (values
    ('デッキ 2', 10, 20),
    ('デッキ 3', 20, 30),
    ('デッキ 4', 30, 40),
    ('デッキ 5', 40, 50),
    ('デッキ 6', 0, 10)
  ) as t(deck_name, rn_from, rn_to)
)
insert into public.cards (word_id, card_template_id, deck_id, sort_order, is_active)
select source.word_id,
       source.card_template_id,
       d.id,
       (source.rn - assignment.rn_from - 1)::integer,
       true
from assignment
join source
  on source.rn > assignment.rn_from and source.rn <= assignment.rn_to
join public.decks d
  on d.owner_id is null and d.deck_name = assignment.deck_name
on conflict on constraint cards_word_template_deck_key do nothing;

-- 4. 検証。出題される枚数がデッキごとに10枚を超えていないこと。

do $$
declare
  offending text;
begin
  select string_agg(deck_name || '=' || active_count, ', ')
  into offending
  from (
    select d.deck_name,
           (select count(*) from public.cards c
            where c.deck_id = d.id and c.is_active) as active_count
    from public.decks d
    where d.owner_id is null
  ) as counts
  where active_count > 10;

  if offending is not null then
    raise exception 'An official deck still exposes more than 10 cards: %', offending;
  end if;
end;
$$;

commit;
