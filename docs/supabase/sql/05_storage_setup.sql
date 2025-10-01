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
