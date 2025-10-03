-- ===============================================
-- Usalingo Storage バケット設定
-- ===============================================
-- 目的: アセット紐付け機能に必要なStorageバケットを作成・設定する

-- ===============================================
-- Storage バケット作成
-- ===============================================

-- asset-inbox バケット（非公開）
-- 紐付け処理前の元ファイルをアップロードするための待機領域
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'asset-inbox',
    'asset-inbox',
    false, -- 非公開
    10485760, -- 10MB制限
    ARRAY['image/webp', 'image/png', 'image/jpeg', 'audio/mpeg', 'audio/mp3']
);

-- public バケット（公開）
-- 紐付け処理が完了したアセットの格納場所
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'public',
    'public',
    true, -- 公開
    10485760, -- 10MB制限
    ARRAY['image/webp', 'image/png', 'image/jpeg', 'audio/mpeg', 'audio/mp3']
);

-- ===============================================
-- Storage ポリシー設定
-- ===============================================

-- asset-inbox バケットのポリシー（管理者のみアクセス可能）
CREATE POLICY "asset-inbox-upload-policy" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'asset-inbox' AND
        auth.role() = 'service_role'
    );

CREATE POLICY "asset-inbox-select-policy" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'asset-inbox' AND
        auth.role() = 'service_role'
    );

CREATE POLICY "asset-inbox-delete-policy" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'asset-inbox' AND
        auth.role() = 'service_role'
    );

-- public バケットのポリシー（全ユーザーが読み取り可能）
CREATE POLICY "public-select-policy" ON storage.objects
    FOR SELECT USING (bucket_id = 'public');

CREATE POLICY "public-upload-policy" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'public' AND
        auth.role() = 'service_role'
    );

CREATE POLICY "public-delete-policy" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'public' AND
        auth.role() = 'service_role'
    );

-- Storage設定完了の確認メッセージ
SELECT 'Storage buckets and policies setup completed successfully.' as status;
-- =============================================
-- ストレージ階層化の実装
-- =============================================
-- 作成日: 2025-10-01
-- 目的: アセットファイルをテーマとIDに基づいた階層構造で管理

-- =============================================
-- 1. 現状と課題
-- =============================================

-- 現状:
-- - Supabase GUIは1フォルダあたり200件までしか表示されない
-- - 現在1000件以上のアセットがフラット構造で管理されている
-- - テーマ: 「シンプル」のみ（1000件）

-- 改善後の構造:
-- content-images/
--   └── {theme}/          ← テーマ（例: シンプル、ビジネス、カジュアル）
--       └── {id_range}/   ← 500件区切り（例: 0000-0499, 0500-0999）
--           └── {id}.{ext}
--
-- 例: content-images/シンプル/0000-0499/350.webp

-- =============================================
-- 2. パス生成関数の実装
-- =============================================

-- 2-1. ID範囲フォルダ名を生成する基本関数
CREATE OR REPLACE FUNCTION public.get_asset_folder_path(
    asset_id INTEGER,
    bucket_size INTEGER DEFAULT 500
)
RETURNS TEXT AS $$
DECLARE
    folder_start INTEGER;
    folder_end INTEGER;
BEGIN
    -- フォルダの開始・終了IDを計算
    folder_start := (asset_id / bucket_size) * bucket_size;
    folder_end := folder_start + bucket_size - 1;
    
    -- 4桁ゼロ埋めでフォルダパスを返す（例: "0000-0499", "0500-0999"）
    RETURN LPAD(folder_start::TEXT, 4, '0') || '-' || LPAD(folder_end::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.get_asset_folder_path(INTEGER, INTEGER) IS 
'アセットIDから500件区切りのフォルダ名を生成する（4桁ゼロ埋め）。
例: get_asset_folder_path(350) → "0000-0499"';

-- 2-2. 例文イラストの完全パスを生成
CREATE OR REPLACE FUNCTION public.get_example_illustration_path(
    example_id INTEGER,
    theme TEXT,
    file_extension TEXT DEFAULT 'webp'
)
RETURNS TEXT AS $$
DECLARE
    folder_range TEXT;
BEGIN
    -- ID範囲フォルダ名を取得
    folder_range := public.get_asset_folder_path(example_id);
    
    -- content-images/{theme}/{id_range}/{id}.{ext} の形式で返す
    RETURN 'content-images/' || 
           theme || '/' ||
           folder_range || '/' ||
           example_id || '.' || file_extension;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.get_example_illustration_path(INTEGER, TEXT, TEXT) IS 
'例文イラストの完全ストレージパスを生成する。
例: get_example_illustration_path(350, ''シンプル'', ''webp'') 
  → "content-images/シンプル/0000-0499/350.webp"';

-- 2-3. 例文音声の完全パスを生成
CREATE OR REPLACE FUNCTION public.get_example_audio_path(
    example_id INTEGER,
    theme TEXT,
    file_extension TEXT DEFAULT 'mp3'
)
RETURNS TEXT AS $$
DECLARE
    folder_range TEXT;
BEGIN
    -- ID範囲フォルダ名を取得
    folder_range := public.get_asset_folder_path(example_id);
    
    -- content-audio/example/{theme}/{id_range}/{id}.{ext} の形式で返す
    RETURN 'content-audio/example/' || 
           theme || '/' ||
           folder_range || '/' ||
           example_id || '.' || file_extension;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.get_example_audio_path(INTEGER, TEXT, TEXT) IS 
'例文音声の完全ストレージパスを生成する。
例: get_example_audio_path(350, ''シンプル'', ''mp3'') 
  → "content-audio/example/シンプル/0000-0499/350.mp3"';

-- 2-4. 単語音声の完全パスを生成（テーマなし）
CREATE OR REPLACE FUNCTION public.get_word_audio_path(
    word_meaning_id INTEGER,
    file_extension TEXT DEFAULT 'mp3'
)
RETURNS TEXT AS $$
DECLARE
    folder_range TEXT;
BEGIN
    -- ID範囲フォルダ名を取得
    folder_range := public.get_asset_folder_path(word_meaning_id);
    
    -- content-audio/word/{id_range}/{id}.{ext} の形式で返す
    RETURN 'content-audio/word/' || 
           folder_range || '/' ||
           word_meaning_id || '.' || file_extension;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.get_word_audio_path(INTEGER, TEXT) IS 
'単語音声の完全ストレージパスを生成する。
例: get_word_audio_path(350, ''mp3'') 
  → "content-audio/word/0000-0499/350.mp3"';

-- =============================================
-- 3. スキーマ変更（拡張子カラムの追加）
-- =============================================

-- 3-1. example_contentsテーブルに拡張子カラムを追加
ALTER TABLE public.example_contents 
ADD COLUMN IF NOT EXISTS illustration_ext TEXT DEFAULT 'webp',
ADD COLUMN IF NOT EXISTS audio_ext TEXT DEFAULT 'mp3';

COMMENT ON COLUMN public.example_contents.illustration_ext IS 
'イラストファイルの拡張子（例: webp, jpg, png）';

COMMENT ON COLUMN public.example_contents.audio_ext IS 
'音声ファイルの拡張子（例: mp3, wav, ogg）';

-- 3-2. word_meaningsテーブルに拡張子カラムを追加
ALTER TABLE public.word_meanings 
ADD COLUMN IF NOT EXISTS audio_ext TEXT DEFAULT 'mp3';

COMMENT ON COLUMN public.word_meanings.audio_ext IS 
'音声ファイルの拡張子（例: mp3, wav, ogg）';

-- 3-3. 既存の*_asset_pathカラムを非推奨としてマーク（削除は後で検討）
COMMENT ON COLUMN public.example_contents.illustration_asset_path IS 
'【非推奨】旧パス保存用カラム。新規はillustration_extとget_example_illustration_path関数を使用。';

COMMENT ON COLUMN public.example_contents.audio_asset_path IS 
'【非推奨】旧パス保存用カラム。新規はaudio_extとget_example_audio_path関数を使用。';

COMMENT ON COLUMN public.word_meanings.audio_asset_path IS 
'【非推奨】旧パス保存用カラム。新規はaudio_extとget_word_audio_path関数を使用。';

-- =============================================
-- 4. ビューの作成（アプリケーション用）
-- =============================================

-- 4-1. 例文コンテンツ用ビュー（完全パス付き）
CREATE OR REPLACE VIEW public.v_example_contents_with_paths AS
SELECT 
    ec.*,
    -- 新しいパス生成関数を使用
    public.get_example_illustration_path(
        ec.id, 
        ec.theme, 
        ec.illustration_ext
    ) as illustration_path,
    public.get_example_audio_path(
        ec.id, 
        ec.theme, 
        ec.audio_ext
    ) as audio_path,
    -- 互換性のため旧カラムも保持
    ec.illustration_asset_path as illustration_path_legacy,
    ec.audio_asset_path as audio_path_legacy
FROM public.example_contents ec;

COMMENT ON VIEW public.v_example_contents_with_paths IS 
'例文コンテンツに完全ストレージパスを付与したビュー。
アプリケーションはこのビューを使用してアセットパスを取得する。';

-- 4-2. 単語の意味用ビュー（完全パス付き）
CREATE OR REPLACE VIEW public.v_word_meanings_with_paths AS
SELECT 
    wm.*,
    -- 新しいパス生成関数を使用
    public.get_word_audio_path(
        wm.id, 
        wm.audio_ext
    ) as audio_path,
    -- 互換性のため旧カラムも保持
    wm.audio_asset_path as audio_path_legacy
FROM public.word_meanings wm;

COMMENT ON VIEW public.v_word_meanings_with_paths IS 
'単語の意味に完全ストレージパスを付与したビュー。
アプリケーションはこのビューを使用してアセットパスを取得する。';

-- =============================================
-- 5. ヘルパー関数（管理用）
-- =============================================

-- 5-1. テーマ別のフォルダ構造を一覧表示
CREATE OR REPLACE FUNCTION public.get_storage_structure_summary()
RETURNS TABLE (
    theme TEXT,
    folder_range TEXT,
    expected_file_count BIGINT,
    example_file_paths TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH folder_examples AS (
        SELECT 
            ec.theme,
            public.get_asset_folder_path(ec.id) as folder_range,
            public.get_example_illustration_path(ec.id, ec.theme, ec.illustration_ext) as path,
            ROW_NUMBER() OVER (PARTITION BY ec.theme, public.get_asset_folder_path(ec.id) ORDER BY ec.id) as rn
        FROM public.example_contents ec
    )
    SELECT 
        fe.theme,
        fe.folder_range,
        COUNT(*) as expected_file_count,
        ARRAY_AGG(fe.path ORDER BY fe.path) FILTER (WHERE fe.rn <= 3) as example_file_paths
    FROM folder_examples fe
    GROUP BY fe.theme, fe.folder_range
    ORDER BY fe.theme, fe.folder_range;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.get_storage_structure_summary() IS 
'ストレージ構造のサマリーを表示する管理用関数。
各テーマ・フォルダ範囲ごとのファイル数と例を確認できる。';

-- 5-2. 欠損しているアセットを検出
CREATE OR REPLACE FUNCTION public.find_missing_assets()
RETURNS TABLE (
    content_type TEXT,
    record_id INTEGER,
    theme TEXT,
    expected_illustration_path TEXT,
    expected_audio_path TEXT,
    has_illustration_filename BOOLEAN,
    has_audio_filename BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'example_content'::TEXT as content_type,
        ec.id as record_id,
        ec.theme,
        public.get_example_illustration_path(ec.id, ec.theme, ec.illustration_ext) as expected_illustration_path,
        public.get_example_audio_path(ec.id, ec.theme, ec.audio_ext) as expected_audio_path,
        (ec.illustration_filename IS NOT NULL) as has_illustration_filename,
        (ec.audio_filename IS NOT NULL) as has_audio_filename
    FROM public.example_contents ec
    WHERE ec.illustration_filename IS NULL 
       OR ec.audio_filename IS NULL
    
    UNION ALL
    
    SELECT 
        'word_meaning'::TEXT as content_type,
        wm.id as record_id,
        NULL as theme,
        NULL as expected_illustration_path,
        public.get_word_audio_path(wm.id, wm.audio_ext) as expected_audio_path,
        NULL as has_illustration_filename,
        (wm.audio_filename IS NOT NULL) as has_audio_filename
    FROM public.word_meanings wm
    WHERE wm.audio_filename IS NULL
    
    ORDER BY content_type, record_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.find_missing_assets() IS 
'アセットファイル名が登録されていないレコードを検出する。
ファイル移行の進捗確認に使用。';

-- =============================================
-- 6. テスト用クエリ（コメントアウト）
-- =============================================

/*
-- テスト1: パス生成関数の動作確認
SELECT 
    public.get_asset_folder_path(1) as test1,      -- 期待値: "0000-0499"
    public.get_asset_folder_path(500) as test2,    -- 期待値: "0500-0999"
    public.get_asset_folder_path(999) as test3;    -- 期待値: "0500-0999"

-- テスト2: 例文イラストパス生成
SELECT 
    id,
    theme,
    illustration_ext,
    public.get_example_illustration_path(id, theme, illustration_ext) as full_path
FROM example_contents
LIMIT 5;

-- テスト3: ビューの動作確認
SELECT 
    id,
    theme,
    illustration_path,
    audio_path
FROM v_example_contents_with_paths
LIMIT 5;

-- テスト4: ストレージ構造サマリー
SELECT * FROM public.get_storage_structure_summary();

-- テスト5: 欠損アセットの確認
SELECT * FROM public.find_missing_assets() LIMIT 10;
*/

-- =============================================
-- 7. 完了メッセージ
-- =============================================

SELECT 'ストレージ階層化のセットアップが完了しました。' as status;

