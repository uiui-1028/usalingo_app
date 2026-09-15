-- 20260915090758_drop_extra_word_tables_and_rename_media_paths.sql のパスの置き換えを元に戻す。
-- 古い名前のファイルを Storage に戻してから実行する。
-- 消した word_forms・word_relations は、各50行すべて空のオブジェクトだった。戻すときは
-- 20260831121553_align_source_database_v5.sql の定義で作り直し、word_id 1〜50 に '{}' を入れる。

begin;

alter table public.example_contents
  drop constraint example_contents_image_asset_path_contract,
  drop constraint example_contents_audio_asset_path_contract;

update public.example_contents
set image_asset_path = format('content-images/simple/0000-0499/%s.webp', id)
where image_asset_path = format('content-images/simple/000/example-%s.webp', lpad(id::text, 6, '0'));

update public.example_contents
set audio_asset_path = format('content-audio/example/simple/0000-0499/%s.mp3', id)
where audio_asset_path = format('content-audio/example/simple/000/example-%s.mp3', lpad(id::text, 6, '0'));

update public.example_audio
set audio_asset_path = format('content-audio/example/simple/0000-0499/%s.mp3', example_id)
where audio_asset_path = format('content-audio/example/simple/000/example-%s.mp3', lpad(example_id::text, 6, '0'));

update public.word_pronunciations
set audio_asset_path = format('content-audio/word/4000-4499/%s.mp3', 4000 + id)
where audio_asset_path = format('content-audio/word/000/pron-%s.mp3', lpad(id::text, 6, '0'));

update public.user_word_overrides
set image_asset_path = format(
  'content-images/simple/0000-0499/%s.webp',
  ltrim(substring(image_asset_path from 'example-([0-9]{6})\.webp$'), '0')
)
where image_asset_path ~ '^content-images/simple/000/example-[0-9]{6}\.webp$';

alter table public.example_contents
  add constraint example_contents_image_asset_path_contract
  check (
    image_asset_path is null
    or (
      image_asset_path ~ '^content-images/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]webp$'
      and image_asset_path like (
        '%/' || lpad(((id / 500) * 500)::text, 4, '0') || '-'
        || lpad((((id / 500) * 500) + 499)::text, 4, '0') || '/' || id::text || '.webp'
      )
    )
  ),
  add constraint example_contents_audio_asset_path_contract
  check (
    audio_asset_path is null
    or (
      audio_asset_path ~ '^content-audio/example/[a-z0-9]+(-[a-z0-9]+)*/[0-9]{4}-[0-9]{4}/[0-9]+[.]mp3$'
      and audio_asset_path like (
        '%/' || lpad(((id / 500) * 500)::text, 4, '0') || '-'
        || lpad((((id / 500) * 500) + 499)::text, 4, '0') || '/' || id::text || '.mp3'
      )
    )
  );

commit;
