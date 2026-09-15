-- 1. 活用と関連語は word_meanings の列に収めるため、V5で足した2表をやめる。
--    決定記録: docs/decisions/senses-hold-forms-and-relations-20260914.md
-- 2. 画像と音声のパスを、種類と6けたの番号を付けた名前へ置き換える。
--    決定記録: docs/decisions/content-file-naming-padded-with-kind-20260915.md
--
-- 本番の2表は各50行で、すべて空のオブジェクト（{}）だった（2026-09-15に確認し、控えを保存）。
-- 新しい名前のファイルは、このmigrationより前にStorageへ置いてある。古いファイルはあとで片付ける。
-- 元に戻すときは scripts/sql/content-media-rename-20260915-rollback.sql を使う。

-- 1. 2表をやめる。中身のある行が1件でもあれば止める。
do $$
begin
  if to_regclass('public.word_forms') is not null then
    execute $q$
      do $inner$
      begin
        if exists (select 1 from public.word_forms where forms_json <> '{}'::jsonb) then
          raise exception 'word_forms has non-empty data; move it to word_meanings first.';
        end if;
      end $inner$
    $q$;
  end if;
  if to_regclass('public.word_relations') is not null then
    execute $q$
      do $inner$
      begin
        if exists (select 1 from public.word_relations where relations_json <> '{}'::jsonb) then
          raise exception 'word_relations has non-empty data; move it to word_meanings first.';
        end if;
      end $inner$
    $q$;
  end if;
end $$;

drop table if exists public.word_forms;
drop table if exists public.word_relations;

-- 2. パスの決まりを新しい形にする。
alter table public.example_contents
  drop constraint example_contents_image_asset_path_contract,
  drop constraint example_contents_audio_asset_path_contract;

-- 書き換える前に、古いパスの番号が行のIDと合っているかを確かめる。
do $$
begin
  if exists (
    select 1 from public.example_contents
    where image_asset_path is not null
      and image_asset_path <> format(
        'content-images/simple/%s-%s/%s.webp',
        lpad(((id / 500) * 500)::text, 4, '0'), lpad((((id / 500) * 500) + 499)::text, 4, '0'), id)
  ) then
    raise exception 'example_contents.image_asset_path does not match example id';
  end if;
  if exists (
    select 1 from public.example_contents
    where audio_asset_path is not null
      and audio_asset_path <> format(
        'content-audio/example/simple/%s-%s/%s.mp3',
        lpad(((id / 500) * 500)::text, 4, '0'), lpad((((id / 500) * 500) + 499)::text, 4, '0'), id)
  ) then
    raise exception 'example_contents.audio_asset_path does not match example id';
  end if;
  if exists (
    select 1 from public.example_audio
    where audio_asset_path is not null
      and audio_asset_path <> format(
        'content-audio/example/simple/%s-%s/%s.mp3',
        lpad(((example_id / 500) * 500)::text, 4, '0'),
        lpad((((example_id / 500) * 500) + 499)::text, 4, '0'), example_id)
  ) then
    raise exception 'example_audio.audio_asset_path does not match example id';
  end if;
  if exists (
    select 1 from public.word_pronunciations
    where audio_asset_path is not null
      and audio_asset_path <> format('content-audio/word/4000-4499/%s.mp3', 4000 + id)
  ) then
    raise exception 'word_pronunciations.audio_asset_path does not match pronunciation id';
  end if;
  if exists (
    select 1 from public.user_word_overrides
    where image_asset_path is not null
      and image_asset_path !~ '^content-images/simple/[0-9]{4}-[0-9]{4}/[0-9]+\.webp$'
  ) then
    raise exception 'user_word_overrides.image_asset_path has an unexpected form';
  end if;
end $$;

update public.example_contents
set image_asset_path = format(
  'content-images/simple/%s/example-%s.webp', lpad((id / 1000)::text, 3, '0'), lpad(id::text, 6, '0'))
where image_asset_path is not null;

update public.example_contents
set audio_asset_path = format(
  'content-audio/example/simple/%s/example-%s.mp3', lpad((id / 1000)::text, 3, '0'), lpad(id::text, 6, '0'))
where audio_asset_path is not null;

update public.example_audio
set audio_asset_path = format(
  'content-audio/example/simple/%s/example-%s.mp3',
  lpad((example_id / 1000)::text, 3, '0'), lpad(example_id::text, 6, '0'))
where audio_asset_path is not null;

update public.word_pronunciations
set audio_asset_path = format(
  'content-audio/word/%s/pron-%s.mp3', lpad((id / 1000)::text, 3, '0'), lpad(id::text, 6, '0'))
where audio_asset_path is not null;

update public.user_word_overrides
set image_asset_path = format(
  'content-images/simple/%s/example-%s.webp',
  lpad((substring(image_asset_path from '/([0-9]+)\.webp$')::int / 1000)::text, 3, '0'),
  lpad(substring(image_asset_path from '/([0-9]+)\.webp$'), 6, '0'))
where image_asset_path is not null;

alter table public.example_contents
  add constraint example_contents_image_asset_path_contract
  check (
    image_asset_path is null
    or (
      image_asset_path ~ '^content-images/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{3}/example-[0-9]{6}[.]webp$'
      and image_asset_path like (
        '%/' || lpad((id / 1000)::text, 3, '0') || '/example-' || lpad(id::text, 6, '0') || '.webp'
      )
    )
  ),
  add constraint example_contents_audio_asset_path_contract
  check (
    audio_asset_path is null
    or (
      audio_asset_path ~ '^content-audio/example/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{3}/example-[0-9]{6}[.]mp3$'
      and audio_asset_path like (
        '%/' || lpad((id / 1000)::text, 3, '0') || '/example-' || lpad(id::text, 6, '0') || '.mp3'
      )
    )
  );
