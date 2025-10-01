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
