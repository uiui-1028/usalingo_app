-- ===============================================
-- Usalingo データベーススキーマ クリーンアップ
-- ===============================================
-- 目的: 既存のコンテンツ関連テーブルを安全に削除する
-- 注意: 依存関係を考慮し、子テーブルから先に削除する

-- 中間テーブル（多対多関係）を最初に削除
DROP TABLE IF EXISTS public.deck_words CASCADE;

-- 例文コンテンツテーブルを削除
DROP TABLE IF EXISTS public.example_contents CASCADE;

-- 単語の意味テーブルを削除
DROP TABLE IF EXISTS public.word_meanings CASCADE;

-- デッキマスターテーブルを削除
DROP TABLE IF EXISTS public.decks CASCADE;

-- 単語マスターテーブルを削除
DROP TABLE IF EXISTS public.words CASCADE;

-- カードテンプレートテーブルを削除（コンテンツ関連）
DROP TABLE IF EXISTS public.card_templates CASCADE;

-- 削除完了の確認メッセージ
SELECT 'Cleanup completed successfully. All content-related tables have been removed.' as status;
