-- =============================================
-- Usalingo データベース統合セットアップスクリプト
-- =============================================
-- 作成日: 2025-01-30
-- 目的: データベースの初期セットアップとマイグレーション管理
-- 使用方法: このスクリプトを順次実行してデータベースを構築

-- =============================================
-- 1. セットアップ開始の通知
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Usalingo データベースセットアップを開始します';
    RAISE NOTICE '開始時刻: %', NOW();
    RAISE NOTICE '=============================================';
END $$;

-- =============================================
-- 2. マイグレーション管理システムのセットアップ
-- =============================================

\echo 'ステップ 1/9: マイグレーション管理システムのセットアップ'
\i migrations/000_migration_system.sql

-- =============================================
-- 3. データベースクリーンアップ（開発環境のみ）
-- =============================================

\echo 'ステップ 2/9: 既存オブジェクトのクリーンアップ'
\i 00_cleanup.sql

-- =============================================
-- 4. 基本スキーマの作成
-- =============================================

\echo 'ステップ 3/9: 基本スキーマの作成'
\i 01_schema.sql

-- マイグレーション記録
SELECT apply_migration(
    '001',
    'Basic Schema Creation',
    '基本テーブル構造の作成（users, words, word_meanings等）'
);

-- =============================================
-- 5. インデックスの作成
-- =============================================

\echo 'ステップ 4/9: パフォーマンス用インデックスの作成'
\i 02_indexes.sql

-- マイグレーション記録
SELECT apply_migration(
    '002',
    'Performance Indexes',
    'クエリパフォーマンス向上のためのインデックス作成'
);

-- =============================================
-- 6. RLSポリシーの設定
-- =============================================

\echo 'ステップ 5/9: Row Level Securityポリシーの設定'
\i 03_rls.sql

-- マイグレーション記録
SELECT apply_migration(
    '003',
    'Row Level Security Policies',
    'データアクセス制御のためのRLSポリシー設定'
);

-- =============================================
-- 7. メディアトリガーの設定
-- =============================================

\echo 'ステップ 6/9: メディアファイル自動紐付けトリガーの設定'
\i 04_media_trigger.sql

-- マイグレーション記録
SELECT apply_migration(
    '004',
    'Media Trigger Functions',
    'メディアファイルの自動パス設定トリガー実装'
);

-- =============================================
-- 8. ストレージ設定
-- =============================================

\echo 'ステップ 7/9: Supabase Storage設定'
\i 05_storage_setup.sql

-- マイグレーション記録
SELECT apply_migration(
    '005',
    'Supabase Storage Setup',
    'ファイルストレージバケットとポリシーの設定'
);

-- =============================================
-- 9. タイムスタンプカラムの追加
-- =============================================

\echo 'ステップ 8/9: タイムスタンプカラムと自動更新トリガーの追加'
\i 06_add_timestamps.sql

-- マイグレーション記録
SELECT apply_migration(
    '006',
    'Timestamp Columns and Triggers',
    '全テーブルへのタイムスタンプカラム追加と自動更新トリガー実装'
);

-- =============================================
-- 10. JSONBカラムの構造定義
-- =============================================

\echo 'ステップ 9/9: JSONBカラムの構造定義とバリデーション'
\i 07_jsonb_documentation.sql

-- マイグレーション記録
SELECT apply_migration(
    '007',
    'JSONB Column Documentation',
    'JSONBカラムの構造定義、TypeScript型定義、バリデーション関数の実装'
);

-- =============================================
-- 11. セットアップ完了の確認
-- =============================================

\echo '============================================='
\echo 'データベースセットアップの検証を実行中...'
\echo '============================================='

-- テーブル数の確認
SELECT 
    schemaname,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname = 'public'
GROUP BY schemaname;

-- マイグレーション履歴の確認
SELECT 
    migration_id,
    migration_name,
    applied_at,
    status,
    execution_time_ms
FROM schema_migrations
ORDER BY applied_at;

-- 関数数の確認
SELECT 
    COUNT(*) as function_count
FROM information_schema.routines 
WHERE routine_schema = 'public';

-- インデックス数の確認
SELECT 
    COUNT(*) as index_count
FROM pg_indexes 
WHERE schemaname = 'public';

-- =============================================
-- 12. セットアップ完了の通知
-- =============================================

DO $$
DECLARE
    v_table_count INTEGER;
    v_migration_count INTEGER;
    v_function_count INTEGER;
    v_index_count INTEGER;
    v_end_time TIMESTAMPTZ;
BEGIN
    v_end_time := NOW();
    
    -- 統計情報を取得
    SELECT COUNT(*) INTO v_table_count FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO v_migration_count FROM schema_migrations WHERE status = 'applied';
    SELECT COUNT(*) INTO v_function_count FROM information_schema.routines WHERE routine_schema = 'public';
    SELECT COUNT(*) INTO v_index_count FROM pg_indexes WHERE schemaname = 'public';
    
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Usalingo データベースセットアップが完了しました！';
    RAISE NOTICE '完了時刻: %', v_end_time;
    RAISE NOTICE '=============================================';
    RAISE NOTICE '作成されたオブジェクト:';
    RAISE NOTICE '  - テーブル数: %', v_table_count;
    RAISE NOTICE '  - 適用済みマイグレーション数: %', v_migration_count;
    RAISE NOTICE '  - 関数数: %', v_function_count;
    RAISE NOTICE '  - インデックス数: %', v_index_count;
    RAISE NOTICE '=============================================';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '1. データのインポート (必要に応じて)';
    RAISE NOTICE '2. アプリケーションの接続テスト';
    RAISE NOTICE '3. パフォーマンステストの実行';
    RAISE NOTICE '=============================================';
END $$;

-- =============================================
-- 13. エラーハンドリング
-- =============================================

-- エラーが発生した場合の通知
DO $$
BEGIN
    -- ここでエラーチェックを行う
    -- 例: 必須テーブルの存在確認
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN
        RAISE EXCEPTION '重要なテーブル "users" が見つかりません。セットアップに問題があります。';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_migrations' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'マイグレーション管理テーブルが見つかりません。セットアップに問題があります。';
    END IF;
    
    RAISE NOTICE 'データベース構造の検証が完了しました。';
END $$;

-- =============================================
-- スクリプト終了
-- =============================================
