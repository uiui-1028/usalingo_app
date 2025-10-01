-- ===============================================
-- 既存ファイルの命名規則対応リネーム処理
-- ===============================================
-- 目的: 既存のランダムファイル名を命名規則に合わせてリネームする
-- 実行前: 必ずバックアップを取得してください

-- ===============================================
-- RPC関数: リネーム対象のファイル情報を取得
-- ===============================================

CREATE OR REPLACE FUNCTION public.get_rename_operations()
RETURNS TABLE(
    action TEXT,
    bucket TEXT,
    old_path TEXT,
    new_path TEXT,
    source_table TEXT,
    record_id INTEGER
) AS $$
BEGIN
    RETURN QUERY
    -- word_meaningsのファイルリネーム情報
    SELECT 
        'RENAME'::TEXT as action,
        'content-audio'::TEXT as bucket,
        audio_asset_path as old_path,
        ('content-audio/word_' || word_id || '_' || id || '.mp3')::TEXT as new_path,
        'word_meanings'::TEXT as source_table,
        id as record_id
    FROM public.word_meanings 
    WHERE audio_url IS NOT NULL 
    AND audio_asset_path IS NOT NULL
    AND audio_asset_path NOT LIKE 'content-audio/word_%'

    UNION ALL

    -- example_contentsのイラストファイルリネーム情報
    SELECT 
        'RENAME'::TEXT as action,
        'content-images'::TEXT as bucket,
        illustration_asset_path as old_path,
        ('content-images/example_' || id || '.webp')::TEXT as new_path,
        'example_contents'::TEXT as source_table,
        id as record_id
    FROM public.example_contents 
    WHERE illustration_url IS NOT NULL 
    AND illustration_asset_path IS NOT NULL
    AND illustration_asset_path NOT LIKE 'content-images/example_%'

    UNION ALL

    -- example_contentsの音声ファイルリネーム情報
    SELECT 
        'RENAME'::TEXT as action,
        'content-audio'::TEXT as bucket,
        audio_asset_path as old_path,
        ('content-audio/example_' || id || '.mp3')::TEXT as new_path,
        'example_contents'::TEXT as source_table,
        id as record_id
    FROM public.example_contents 
    WHERE audio_url IS NOT NULL 
    AND audio_asset_path IS NOT NULL
    AND audio_asset_path NOT LIKE 'content-audio/example_%'

    ORDER BY source_table, record_id;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- 1. word_meaningsテーブルの音声ファイルリネーム
-- ===============================================

-- 現在の状況確認
SELECT 
    'word_meanings' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN audio_url IS NOT NULL THEN 1 END) as with_audio,
    COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END) as with_asset_path
FROM public.word_meanings;

-- リネーム処理（命名規則: word_{word_id}_{meaning_id}.mp3）
UPDATE public.word_meanings 
SET audio_asset_path = 'content-audio/word_' || word_id || '_' || id || '.mp3'
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/word_%';

-- リネーム結果確認
SELECT 
    id,
    word_id,
    audio_url,
    audio_asset_path,
    'word_' || word_id || '_' || id || '.mp3' as expected_filename
FROM public.word_meanings 
WHERE audio_url IS NOT NULL
ORDER BY id
LIMIT 10;

-- ===============================================
-- 2. example_contentsテーブルのイラストファイルリネーム
-- ===============================================

-- 現在の状況確認
SELECT 
    'example_contents' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN illustration_url IS NOT NULL THEN 1 END) as with_illustration,
    COUNT(CASE WHEN illustration_asset_path IS NOT NULL THEN 1 END) as with_illustration_path,
    COUNT(CASE WHEN audio_url IS NOT NULL THEN 1 END) as with_audio,
    COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END) as with_audio_path
FROM public.example_contents;

-- イラストファイルのリネーム処理（命名規則: example_{example_id}.webp）
UPDATE public.example_contents 
SET illustration_asset_path = 'content-images/example_' || id || '.webp'
WHERE illustration_url IS NOT NULL 
AND illustration_asset_path IS NOT NULL
AND illustration_asset_path NOT LIKE 'content-images/example_%';

-- 音声ファイルのリネーム処理（命名規則: example_{example_id}.mp3）
UPDATE public.example_contents 
SET audio_asset_path = 'content-audio/example_' || id || '.mp3'
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/example_%';

-- リネーム結果確認
SELECT 
    id,
    meaning_id,
    illustration_url,
    illustration_asset_path,
    audio_url,
    audio_asset_path,
    'example_' || id || '.webp' as expected_illustration_filename,
    'example_' || id || '.mp3' as expected_audio_filename
FROM public.example_contents 
WHERE illustration_url IS NOT NULL OR audio_url IS NOT NULL
ORDER BY id
LIMIT 10;

-- ===============================================
-- 3. リネーム処理の完了確認
-- ===============================================

-- 命名規則に従っていないレコードの確認
SELECT 
    'word_meanings' as table_name,
    COUNT(*) as non_compliant_records
FROM public.word_meanings 
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/word_%'

UNION ALL

SELECT 
    'example_contents_illustration' as table_name,
    COUNT(*) as non_compliant_records
FROM public.example_contents 
WHERE illustration_url IS NOT NULL 
AND illustration_asset_path IS NOT NULL
AND illustration_asset_path NOT LIKE 'content-images/example_%'

UNION ALL

SELECT 
    'example_contents_audio' as table_name,
    COUNT(*) as non_compliant_records
FROM public.example_contents 
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/example_%';

-- ===============================================
-- 4. 実際のファイルリネーム用の情報出力
-- ===============================================

-- word_meaningsのファイルリネーム情報
SELECT 
    'RENAME' as action,
    'content-audio' as bucket,
    audio_asset_path as old_path,
    'content-audio/word_' || word_id || '_' || id || '.mp3' as new_path,
    'word_meanings' as source_table,
    id as record_id
FROM public.word_meanings 
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/word_%'

UNION ALL

-- example_contentsのイラストファイルリネーム情報
SELECT 
    'RENAME' as action,
    'content-images' as bucket,
    illustration_asset_path as old_path,
    'content-images/example_' || id || '.webp' as new_path,
    'example_contents' as source_table,
    id as record_id
FROM public.example_contents 
WHERE illustration_url IS NOT NULL 
AND illustration_asset_path IS NOT NULL
AND illustration_asset_path NOT LIKE 'content-images/example_%'

UNION ALL

-- example_contentsの音声ファイルリネーム情報
SELECT 
    'RENAME' as action,
    'content-audio' as bucket,
    audio_asset_path as old_path,
    'content-audio/example_' || id || '.mp3' as new_path,
    'example_contents' as source_table,
    id as record_id
FROM public.example_contents 
WHERE audio_url IS NOT NULL 
AND audio_asset_path IS NOT NULL
AND audio_asset_path NOT LIKE 'content-audio/example_%'

ORDER BY source_table, record_id;

-- ===============================================
-- 5. ロールバック用のSQL（必要時）
-- ===============================================

-- 注意: 以下のSQLは実際のファイルリネーム後に実行してください
-- データベースのパスを元のファイル名に戻す場合

/*
-- word_meaningsのロールバック
UPDATE public.word_meanings 
SET audio_asset_path = 'content-audio/' || audio_url
WHERE audio_url IS NOT NULL;

-- example_contentsのロールバック
UPDATE public.example_contents 
SET illustration_asset_path = 'content-images/' || illustration_url
WHERE illustration_url IS NOT NULL;

UPDATE public.example_contents 
SET audio_asset_path = 'content-audio/' || audio_url
WHERE audio_url IS NOT NULL;
*/
