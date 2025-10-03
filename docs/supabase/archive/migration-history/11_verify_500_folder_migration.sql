-- ===============================================
-- フォルダ分割数移行後の整合性確認クエリ
-- ===============================================
-- 目的: 200→500ファイル/フォルダ移行後の整合性を確認する

-- ===============================================
-- 1. パス生成関数の動作確認
-- ===============================================

-- テスト1: 基本パス生成関数の動作確認
SELECT 
    'パス生成関数テスト' as test_name,
    public.get_asset_folder_path(1) as test1_result,      -- 期待値: "0000-0499"
    public.get_asset_folder_path(500) as test2_result,     -- 期待値: "0500-0999"
    public.get_asset_folder_path(999) as test3_result,     -- 期待値: "0500-0999"
    public.get_asset_folder_path(1000) as test4_result,    -- 期待値: "1000-1499"
    public.get_asset_folder_path(1500) as test5_result;    -- 期待値: "1500-1999"

-- テスト2: 例文イラストパス生成の確認
SELECT 
    '例文イラストパス生成テスト' as test_name,
    id,
    theme,
    illustration_ext,
    public.get_example_illustration_path(id, theme, illustration_ext) as generated_path
FROM public.example_contents
WHERE id IN (1, 250, 500, 750, 1000)
ORDER BY id;

-- テスト3: 例文音声パス生成の確認
SELECT 
    '例文音声パス生成テスト' as test_name,
    id,
    theme,
    audio_ext,
    public.get_example_audio_path(id, theme, audio_ext) as generated_path
FROM public.example_contents
WHERE id IN (1, 250, 500, 750, 1000)
ORDER BY id;

-- テスト4: 単語音声パス生成の確認
SELECT 
    '単語音声パス生成テスト' as test_name,
    id,
    audio_ext,
    public.get_word_audio_path(id, audio_ext) as generated_path
FROM public.word_meanings
WHERE id IN (1, 250, 500, 750, 1000)
ORDER BY id;

-- ===============================================
-- 2. ビューの動作確認
-- ===============================================

-- テスト5: 例文コンテンツビューの確認
SELECT 
    '例文コンテンツビューテスト' as test_name,
    id,
    theme,
    illustration_path,
    audio_path,
    illustration_path_legacy,
    audio_path_legacy
FROM public.v_example_contents_with_paths
WHERE id IN (1, 250, 500, 750, 1000)
ORDER BY id;

-- テスト6: 単語の意味ビューの確認
SELECT 
    '単語の意味ビューテスト' as test_name,
    id,
    audio_path,
    audio_path_legacy
FROM public.v_word_meanings_with_paths
WHERE id IN (1, 250, 500, 750, 1000)
ORDER BY id;

-- ===============================================
-- 3. ストレージ構造の確認
-- ===============================================

-- テスト7: ストレージ構造サマリーの確認
SELECT 
    'ストレージ構造サマリー' as test_name,
    *
FROM public.get_storage_structure_summary()
ORDER BY theme, folder_range;

-- テスト8: フォルダ範囲の分布確認
SELECT 
    'フォルダ範囲分布確認' as test_name,
    theme,
    folder_range,
    expected_file_count,
    CASE 
        WHEN expected_file_count <= 500 THEN '✅ 適切'
        WHEN expected_file_count <= 1000 THEN '⚠️  注意'
        ELSE '❌ 超過'
    END as status
FROM public.get_storage_structure_summary()
ORDER BY theme, folder_range;

-- ===============================================
-- 4. 欠損アセットの確認
-- ===============================================

-- テスト9: 欠損アセットの確認
SELECT 
    '欠損アセット確認' as test_name,
    content_type,
    COUNT(*) as missing_count
FROM public.find_missing_assets()
GROUP BY content_type
ORDER BY content_type;

-- テスト10: 欠損アセットの詳細
SELECT 
    '欠損アセット詳細' as test_name,
    content_type,
    record_id,
    theme,
    expected_illustration_path,
    expected_audio_path,
    has_illustration_filename,
    has_audio_filename
FROM public.find_missing_assets()
ORDER BY content_type, record_id
LIMIT 20;

-- ===============================================
-- 5. パフォーマンステスト
-- ===============================================

-- テスト11: パス生成関数のパフォーマンステスト
EXPLAIN ANALYZE
SELECT 
    id,
    theme,
    public.get_example_illustration_path(id, theme, illustration_ext) as path
FROM public.example_contents
WHERE id BETWEEN 1 AND 100;

-- テスト12: ビューのパフォーマンステスト
EXPLAIN ANALYZE
SELECT 
    id,
    theme,
    illustration_path,
    audio_path
FROM public.v_example_contents_with_paths
WHERE id BETWEEN 1 AND 100;

-- ===============================================
-- 6. データ整合性の確認
-- ===============================================

-- テスト13: 新旧パスの整合性確認
SELECT 
    '新旧パス整合性確認' as test_name,
    COUNT(*) as total_records,
    COUNT(illustration_path) as new_path_count,
    COUNT(illustration_path_legacy) as legacy_path_count,
    COUNT(*) - COUNT(illustration_path) as missing_new_path
FROM public.v_example_contents_with_paths;

-- テスト14: テーマ別のレコード数確認
SELECT 
    'テーマ別レコード数確認' as test_name,
    theme,
    COUNT(*) as record_count,
    MIN(id) as min_id,
    MAX(id) as max_id
FROM public.example_contents
GROUP BY theme
ORDER BY theme;

-- ===============================================
-- 7. 移行後の期待値確認
-- ===============================================

-- テスト15: フォルダ分割数の期待値確認
WITH folder_analysis AS (
    SELECT 
        theme,
        public.get_asset_folder_path(id) as folder_range,
        COUNT(*) as file_count
    FROM public.example_contents
    GROUP BY theme, public.get_asset_folder_path(id)
)
SELECT 
    'フォルダ分割数期待値確認' as test_name,
    theme,
    folder_range,
    file_count,
    CASE 
        WHEN file_count <= 500 THEN '✅ 適切（500以下）'
        WHEN file_count <= 1000 THEN '⚠️  注意（500-1000）'
        ELSE '❌ 超過（1000以上）'
    END as status
FROM folder_analysis
ORDER BY theme, folder_range;

-- ===============================================
-- 8. 完了メッセージ
-- ===============================================

SELECT 'フォルダ分割数移行後の整合性確認が完了しました。' as status;
