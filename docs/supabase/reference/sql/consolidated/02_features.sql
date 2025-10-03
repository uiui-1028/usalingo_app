-- ===============================================
-- Usalingo メディアアセット処理トリガー
-- ===============================================
-- 目的: アセット紐付け処理を自動化するためのトリガー関数を作成する

-- ===============================================
-- アセット紐付け処理のトリガー関数
-- ===============================================

-- アセット紐付け処理を呼び出す関数（命名規則対応版）
CREATE OR REPLACE FUNCTION public.trigger_asset_linking()
RETURNS TRIGGER AS $$
BEGIN
    -- 命名規則に基づくパス生成
    -- word_meaningsテーブルの場合
    IF TG_TABLE_NAME = 'word_meanings' THEN
        IF NEW.audio_url IS NOT NULL AND NEW.audio_asset_path IS NULL THEN
            -- 命名規則: word_{word_id}_{meaning_id}.mp3
            NEW.audio_asset_path := 'content-audio/word_' || NEW.word_id || '_' || NEW.id || '.mp3';
        END IF;
    END IF;
    
    -- example_contentsテーブルの場合
    IF TG_TABLE_NAME = 'example_contents' THEN
        IF NEW.illustration_url IS NOT NULL AND NEW.illustration_asset_path IS NULL THEN
            -- 命名規則: example_{example_id}.webp
            NEW.illustration_asset_path := 'content-images/example_' || NEW.id || '.webp';
        END IF;
        
        IF NEW.audio_url IS NOT NULL AND NEW.audio_asset_path IS NULL THEN
            -- 命名規則: example_{example_id}.mp3
            NEW.audio_asset_path := 'content-audio/example_' || NEW.id || '.mp3';
        END IF;
    END IF;
    
    -- ログ出力
    RAISE LOG 'アセット紐付け処理が実行されました: テーブル=%, レコードID=%, 生成パス=%', 
        TG_TABLE_NAME, COALESCE(NEW.id, OLD.id), 
        COALESCE(NEW.audio_asset_path, NEW.illustration_asset_path);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- トリガーの設定
-- ===============================================

-- word_meaningsテーブルのトリガー
-- audio_urlが更新された時にアセット紐付け処理を実行（BEFOREタイミングでNEW値を変更）
CREATE TRIGGER trigger_word_meanings_asset_linking
    BEFORE INSERT OR UPDATE OF audio_url
    ON public.word_meanings
    FOR EACH ROW
    WHEN (NEW.audio_url IS NOT NULL AND NEW.audio_asset_path IS NULL)
    EXECUTE FUNCTION public.trigger_asset_linking();

-- example_contentsテーブルのトリガー
-- illustration_urlまたはaudio_urlが更新された時にアセット紐付け処理を実行（BEFOREタイミングでNEW値を変更）
CREATE TRIGGER trigger_example_contents_asset_linking
    BEFORE INSERT OR UPDATE OF illustration_url, audio_url
    ON public.example_contents
    FOR EACH ROW
    WHEN (
        (NEW.illustration_url IS NOT NULL AND NEW.illustration_asset_path IS NULL) OR
        (NEW.audio_url IS NOT NULL AND NEW.audio_asset_path IS NULL)
    )
    EXECUTE FUNCTION public.trigger_asset_linking();

-- ===============================================
-- 手動アセット紐付け処理関数
-- ===============================================

-- 管理者が手動でアセット紐付け処理を実行するための関数（命名規則対応版）
CREATE OR REPLACE FUNCTION public.manual_asset_linking()
RETURNS TABLE(
    processed_count INTEGER,
    skipped_count INTEGER,
    error_count INTEGER,
    details TEXT
) AS $$
DECLARE
    processed INTEGER := 0;
    skipped INTEGER := 0;
    error_count INTEGER := 0;
    details TEXT := '';
    rec RECORD;
BEGIN
    -- word_meaningsテーブルの未処理レコードを命名規則に基づいて更新
    FOR rec IN 
        SELECT id, word_id FROM public.word_meanings
        WHERE audio_url IS NOT NULL AND audio_asset_path IS NULL
    LOOP
        UPDATE public.word_meanings 
        SET audio_asset_path = 'content-audio/word_' || rec.word_id || '_' || rec.id || '.mp3'
        WHERE id = rec.id;
        processed := processed + 1;
    END LOOP;
    
    -- example_contentsテーブルの未処理レコードを命名規則に基づいて更新
    FOR rec IN 
        SELECT id FROM public.example_contents
        WHERE (illustration_url IS NOT NULL AND illustration_asset_path IS NULL) OR
              (audio_url IS NOT NULL AND audio_asset_path IS NULL)
    LOOP
        -- illustration_asset_pathの更新
        UPDATE public.example_contents 
        SET illustration_asset_path = 'content-images/example_' || rec.id || '.webp'
        WHERE id = rec.id AND illustration_url IS NOT NULL AND illustration_asset_path IS NULL;
        
        -- audio_asset_pathの更新
        UPDATE public.example_contents 
        SET audio_asset_path = 'content-audio/example_' || rec.id || '.mp3'
        WHERE id = rec.id AND audio_url IS NOT NULL AND audio_asset_path IS NULL;
        
        skipped := skipped + 1;
    END LOOP;
    
    -- 詳細情報を構築
    details := format('word_meanings未処理: %s件, example_contents未処理: %s件', 
                     processed, skipped);
    
    -- 結果を返す
    RETURN QUERY SELECT processed, skipped, error_count, details;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- アセット紐付け状況確認関数
-- ===============================================

-- アセット紐付けの状況を確認する関数
CREATE OR REPLACE FUNCTION public.check_asset_linking_status()
RETURNS TABLE(
    table_name TEXT,
    total_records INTEGER,
    linked_records INTEGER,
    unlinked_records INTEGER,
    link_rate NUMERIC
) AS $$
BEGIN
    -- word_meaningsテーブルの状況
    RETURN QUERY
    SELECT 
        'word_meanings'::TEXT as table_name,
        COUNT(*)::INTEGER as total_records,
        COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END)::INTEGER as linked_records,
        COUNT(CASE WHEN audio_url IS NOT NULL AND audio_asset_path IS NULL THEN 1 END)::INTEGER as unlinked_records,
        ROUND(
            COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN audio_url IS NOT NULL THEN 1 END), 0) * 100, 
            2
        ) as link_rate
    FROM public.word_meanings
    WHERE audio_url IS NOT NULL;
    
    -- example_contentsテーブルの状況（イラスト）
    RETURN QUERY
    SELECT 
        'example_contents_illustration'::TEXT as table_name,
        COUNT(*)::INTEGER as total_records,
        COUNT(CASE WHEN illustration_asset_path IS NOT NULL THEN 1 END)::INTEGER as linked_records,
        COUNT(CASE WHEN illustration_url IS NOT NULL AND illustration_asset_path IS NULL THEN 1 END)::INTEGER as unlinked_records,
        ROUND(
            COUNT(CASE WHEN illustration_asset_path IS NOT NULL THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN illustration_url IS NOT NULL THEN 1 END), 0) * 100, 
            2
        ) as link_rate
    FROM public.example_contents
    WHERE illustration_url IS NOT NULL;
    
    -- example_contentsテーブルの状況（音声）
    RETURN QUERY
    SELECT 
        'example_contents_audio'::TEXT as table_name,
        COUNT(*)::INTEGER as total_records,
        COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END)::INTEGER as linked_records,
        COUNT(CASE WHEN audio_url IS NOT NULL AND audio_asset_path IS NULL THEN 1 END)::INTEGER as unlinked_records,
        ROUND(
            COUNT(CASE WHEN audio_asset_path IS NOT NULL THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN audio_url IS NOT NULL THEN 1 END), 0) * 100, 
            2
        ) as link_rate
    FROM public.example_contents
    WHERE audio_url IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- トリガー設定完了の確認メッセージ
SELECT 'Media trigger functions and triggers setup completed successfully.' as status;
-- =============================================
-- タイムスタンプカラムの追加と自動更新トリガー
-- =============================================
-- 作成日: 2025-01-30
-- 目的: 主要テーブルにcreated_at, updated_atカラムを追加し、
--       データの作成・更新履歴の追跡と監査証跡を確保

-- =============================================
-- 1. 自動更新トリガー関数の作成
-- =============================================

-- updated_atカラムを自動更新するトリガー関数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 2. タイムスタンプカラムの追加
-- =============================================

-- wordsテーブル
ALTER TABLE words 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- word_meaningsテーブル
ALTER TABLE word_meanings 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- example_contentsテーブル
ALTER TABLE example_contents 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- decksテーブル
ALTER TABLE decks 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- deck_wordsテーブル（関連テーブルのためcreated_atのみ）
ALTER TABLE deck_words 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- card_templatesテーブル
ALTER TABLE card_templates 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- =============================================
-- 3. 自動更新トリガーの追加
-- =============================================

-- wordsテーブルのトリガー
DROP TRIGGER IF EXISTS update_words_updated_at ON words;
CREATE TRIGGER update_words_updated_at
    BEFORE UPDATE ON words
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- word_meaningsテーブルのトリガー
DROP TRIGGER IF EXISTS update_word_meanings_updated_at ON word_meanings;
CREATE TRIGGER update_word_meanings_updated_at
    BEFORE UPDATE ON word_meanings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- example_contentsテーブルのトリガー
DROP TRIGGER IF EXISTS update_example_contents_updated_at ON example_contents;
CREATE TRIGGER update_example_contents_updated_at
    BEFORE UPDATE ON example_contents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- decksテーブルのトリガー
DROP TRIGGER IF EXISTS update_decks_updated_at ON decks;
CREATE TRIGGER update_decks_updated_at
    BEFORE UPDATE ON decks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- card_templatesテーブルのトリガー
DROP TRIGGER IF EXISTS update_card_templates_updated_at ON card_templates;
CREATE TRIGGER update_card_templates_updated_at
    BEFORE UPDATE ON card_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 4. 既存テーブルのトリガー確認・追加
-- =============================================

-- 既存のユーザー関連テーブルのトリガーを確認し、必要に応じて追加
-- user_profiles
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- user_settings
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- user_widget_layouts
DROP TRIGGER IF EXISTS update_user_widget_layouts_updated_at ON user_widget_layouts;
CREATE TRIGGER update_user_widget_layouts_updated_at
    BEFORE UPDATE ON user_widget_layouts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- user_learning_progress
DROP TRIGGER IF EXISTS update_user_learning_progress_updated_at ON user_learning_progress;
CREATE TRIGGER update_user_learning_progress_updated_at
    BEFORE UPDATE ON user_learning_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 5. コメントの追加
-- =============================================

-- 関数にコメントを追加
COMMENT ON FUNCTION update_updated_at_column() IS 
'updated_atカラムを自動的に現在のタイムスタンプで更新するトリガー関数';

-- テーブルにコメントを追加
COMMENT ON COLUMN words.created_at IS 'レコード作成日時';
COMMENT ON COLUMN words.updated_at IS 'レコード最終更新日時（自動更新）';

COMMENT ON COLUMN word_meanings.created_at IS 'レコード作成日時';
COMMENT ON COLUMN word_meanings.updated_at IS 'レコード最終更新日時（自動更新）';

COMMENT ON COLUMN example_contents.created_at IS 'レコード作成日時';
COMMENT ON COLUMN example_contents.updated_at IS 'レコード最終更新日時（自動更新）';

COMMENT ON COLUMN decks.created_at IS 'レコード作成日時';
COMMENT ON COLUMN decks.updated_at IS 'レコード最終更新日時（自動更新）';

COMMENT ON COLUMN deck_words.created_at IS 'レコード作成日時';

COMMENT ON COLUMN card_templates.created_at IS 'レコード作成日時';
COMMENT ON COLUMN card_templates.updated_at IS 'レコード最終更新日時（自動更新）';

-- =============================================
-- 6. 既存データのタイムスタンプ初期化
-- =============================================

-- 既存のレコードに現在時刻を設定（created_atがNULLの場合のみ）
UPDATE words SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL;
UPDATE word_meanings SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL;
UPDATE example_contents SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL;
UPDATE decks SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL;
UPDATE deck_words SET created_at = NOW() WHERE created_at IS NULL;
UPDATE card_templates SET created_at = NOW(), updated_at = NOW() WHERE created_at IS NULL;

-- =============================================
-- 完了メッセージ
-- =============================================
SELECT 'タイムスタンプカラムの追加と自動更新トリガーの設定が完了しました。' as status;
