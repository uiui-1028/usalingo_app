-- USL-286: 手作業版50語への差し替え（render-merge-sql）を取り消す。
--
-- 戻す先は public.usl286_pre_merge_snapshot に控えた「差し替え前の値」。
-- この控えは差し替えSQLが同じトランザクションの中で作る。控えが無い、または
-- 50件そろっていない場合は何もしない。
--
-- 消えるもの: 差し替えで追加した2つ目以降の意味（2001-2510）、活用、関連。
-- 戻るもの:   words の Anki 追跡情報、priority 1 の意味、例文の本文、単語音声。
--
-- 画像と例文音声のパスは差し替えSQLが触っていないので、ここでも触らない。
--
-- 利用者データについて:
--   この操作は words 行を消さないため、user_word_overrides / user_word_tags /
--   user_card_progress は CASCADE で消えない。単語を丸ごと消す
--   usl-286-rollback-production.sql とは別物。

begin;

do $$
declare
  snapshot_rows bigint;
begin
  if to_regclass('public.usl286_pre_merge_snapshot') is null then
    raise exception 'USL-286 merge rollback stopped: the pre-merge snapshot table does not exist.';
  end if;

  select count(*) into snapshot_rows from public.usl286_pre_merge_snapshot;
  if snapshot_rows <> 50 then
    raise exception
      'USL-286 merge rollback stopped: the snapshot holds % rows, expected 50.', snapshot_rows;
  end if;

  -- 控えた単語が、いまも同じidで存在すること。
  if exists (
    select 1 from public.usl286_pre_merge_snapshot s
    left join public.words w on w.id = s.word_id
    where w.id is null
  ) then
    raise exception 'USL-286 merge rollback stopped: some snapshot words no longer exist.';
  end if;
end
$$;

-- 差し替えで足した2つ目以降の意味を消す。
-- example_contents は priority 1 の意味（id = word_id）を指しているので、
-- ここで例文が巻き込まれることはない。
delete from public.word_meanings
where id between 2001 and 2510
  and word_id between 1 and 50;

update public.word_meanings m set
  priority = s.meaning_priority,
  part_of_speech_en = s.meaning_part_of_speech_en,
  part_of_speech_jp = s.meaning_part_of_speech_jp,
  definition_jp = s.meaning_definition_jp,
  etymology = s.meaning_etymology,
  updated_at = now()
from public.usl286_pre_merge_snapshot s
where m.id = s.word_id;

update public.words w set
  source_note_guid = s.source_note_guid,
  source_deck_code = s.source_deck_code,
  source_position = s.source_position,
  updated_at = now()
from public.usl286_pre_merge_snapshot s
where w.id = s.word_id;

update public.example_contents e set
  sentence_en = s.sentence_en,
  sentence_jp = s.sentence_jp,
  updated_at = now()
from public.usl286_pre_merge_snapshot s
where e.id = s.word_id;

update public.word_pronunciations p set
  audio_asset_path = s.word_audio_asset_path,
  audio_state = s.word_audio_state,
  updated_at = now()
from public.usl286_pre_merge_snapshot s
where p.id = s.word_id;

-- 差し替え前は0件だったので消す。
delete from public.word_forms where word_id between 1 and 50;
delete from public.word_relations where word_id between 1 and 50;

do $$
declare
  wrong bigint;
begin
  select count(*) into wrong
  from public.usl286_pre_merge_snapshot s
  join public.words w on w.id = s.word_id
  join public.word_meanings m on m.id = s.word_id
  join public.word_pronunciations p on p.id = s.word_id
  where w.source_deck_code is distinct from s.source_deck_code
     or w.source_position is distinct from s.source_position
     or m.definition_jp is distinct from s.meaning_definition_jp
     or p.audio_state is distinct from s.word_audio_state;
  if wrong <> 0 then
    raise exception 'USL-286 merge rollback incomplete: % rows do not match the snapshot.', wrong;
  end if;

  if (select count(*) from public.word_meanings where word_id between 1 and 50) <> 50 then
    raise exception 'USL-286 merge rollback incomplete: meanings for 1-50 are not back to 50 rows.';
  end if;
end
$$;

commit;

-- 戻し終えて内容を確認したら、控えの表は落としてよい。落とすと二度目の切り戻しはできない。
--   drop table public.usl286_pre_merge_snapshot;
