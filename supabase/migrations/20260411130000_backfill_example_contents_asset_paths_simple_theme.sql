-- Backfill asset paths for example_contents (シンプル) to match Storage layout.
-- Images: content-images/simple/{range}/{id}.webp
-- Audio:  content-audio/example/simple/{range}/{id}.mp3

UPDATE public.example_contents
SET image_asset_path =
  'content-images/simple/'
  || CASE
    WHEN id BETWEEN 1 AND 499 THEN '0000-0499'
    WHEN id BETWEEN 500 AND 999 THEN '0500-0999'
    WHEN id BETWEEN 1000 AND 1499 THEN '1000-1499'
    WHEN id BETWEEN 1500 AND 1999 THEN '1500-1999'
  END
  || '/' || id::text || '.webp'
WHERE image_asset_path IS NULL
  AND theme = 'シンプル'
  AND (
    id BETWEEN 1 AND 499
    OR id BETWEEN 500 AND 999
    OR id BETWEEN 1000 AND 1499
    OR id BETWEEN 1500 AND 1999
  );

UPDATE public.example_contents
SET audio_asset_path =
  'content-audio/example/simple/'
  || CASE
    WHEN id BETWEEN 1 AND 499 THEN '0000-0499'
    WHEN id BETWEEN 500 AND 999 THEN '0500-0999'
    WHEN id BETWEEN 1000 AND 1499 THEN '1000-1499'
    WHEN id BETWEEN 1500 AND 1999 THEN '1500-1999'
  END
  || '/' || id::text || '.mp3'
WHERE audio_asset_path IS NULL
  AND theme = 'シンプル'
  AND (
    id BETWEEN 1 AND 499
    OR id BETWEEN 500 AND 999
    OR id BETWEEN 1000 AND 1499
    OR id BETWEEN 1500 AND 1999
  );
