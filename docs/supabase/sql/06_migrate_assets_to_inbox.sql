-- ===============================================
-- 既存アセットをasset-inboxに移動するスクリプト
-- ===============================================
-- 目的: content-imagesとcontent-audioバケットのファイルをasset-inboxに移動する

-- ===============================================
-- ファイル移動用の関数
-- ===============================================

-- バケット間でファイルを移動する関数
CREATE OR REPLACE FUNCTION public.move_files_to_inbox()
RETURNS TABLE(
    source_bucket TEXT,
    target_bucket TEXT,
    moved_count INTEGER,
    error_count INTEGER,
    details TEXT
) AS $$
DECLARE
    file_record RECORD;
    moved_count INTEGER := 0;
    error_count INTEGER := 0;
    details TEXT := '';
BEGIN
    -- content-imagesバケットのファイルをasset-inboxに移動
    FOR file_record IN 
        SELECT name FROM storage.objects 
        WHERE bucket_id = 'content-images'
        LIMIT 100 -- 一度に100ファイルずつ処理
    LOOP
        BEGIN
            -- ファイルをasset-inboxにコピー
            INSERT INTO storage.objects (bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, path_tokens)
            SELECT 'asset-inbox', name, owner, created_at, updated_at, last_accessed_at, metadata, path_tokens
            FROM storage.objects 
            WHERE bucket_id = 'content-images' AND name = file_record.name;
            
            -- 元のファイルを削除
            DELETE FROM storage.objects 
            WHERE bucket_id = 'content-images' AND name = file_record.name;
            
            moved_count := moved_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            details := details || 'Error moving ' || file_record.name || ': ' || SQLERRM || '; ';
        END;
    END LOOP;
    
    details := 'Moved ' || moved_count || ' files from content-images to asset-inbox. Errors: ' || error_count;
    
    RETURN QUERY SELECT 'content-images'::TEXT, 'asset-inbox'::TEXT, moved_count, error_count, details;
    
    -- リセット
    moved_count := 0;
    error_count := 0;
    details := '';
    
    -- content-audioバケットのファイルをasset-inboxに移動
    FOR file_record IN 
        SELECT name FROM storage.objects 
        WHERE bucket_id = 'content-audio'
        LIMIT 100 -- 一度に100ファイルずつ処理
    LOOP
        BEGIN
            -- ファイルをasset-inboxにコピー
            INSERT INTO storage.objects (bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, path_tokens)
            SELECT 'asset-inbox', name, owner, created_at, updated_at, last_accessed_at, metadata, path_tokens
            FROM storage.objects 
            WHERE bucket_id = 'content-audio' AND name = file_record.name;
            
            -- 元のファイルを削除
            DELETE FROM storage.objects 
            WHERE bucket_id = 'content-audio' AND name = file_record.name;
            
            moved_count := moved_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            details := details || 'Error moving ' || file_record.name || ': ' || SQLERRM || '; ';
        END;
    END LOOP;
    
    details := 'Moved ' || moved_count || ' files from content-audio to asset-inbox. Errors: ' || error_count;
    
    RETURN QUERY SELECT 'content-audio'::TEXT, 'asset-inbox'::TEXT, moved_count, error_count, details;
    
END;
$$ LANGUAGE plpgsql;

-- ファイル移動状況を確認する関数
CREATE OR REPLACE FUNCTION public.check_migration_status()
RETURNS TABLE(
    bucket_name TEXT,
    file_count INTEGER,
    status TEXT
) AS $$
BEGIN
    -- content-images
    RETURN QUERY
    SELECT 
        'content-images'::TEXT as bucket_name,
        COUNT(*)::INTEGER as file_count,
        CASE 
            WHEN COUNT(*) = 0 THEN 'Empty (migration complete)'
            ELSE 'Has files (migration pending)'
        END as status
    FROM storage.objects 
    WHERE bucket_id = 'content-images';
    
    -- content-audio
    RETURN QUERY
    SELECT 
        'content-audio'::TEXT as bucket_name,
        COUNT(*)::INTEGER as file_count,
        CASE 
            WHEN COUNT(*) = 0 THEN 'Empty (migration complete)'
            ELSE 'Has files (migration pending)'
        END as status
    FROM storage.objects 
    WHERE bucket_id = 'content-audio';
    
    -- asset-inbox
    RETURN QUERY
    SELECT 
        'asset-inbox'::TEXT as bucket_name,
        COUNT(*)::INTEGER as file_count,
        CASE 
            WHEN COUNT(*) > 0 THEN 'Has files (ready for processing)'
            ELSE 'Empty (no files)'
        END as status
    FROM storage.objects 
    WHERE bucket_id = 'asset-inbox';
END;
$$ LANGUAGE plpgsql;

-- 移行完了の確認メッセージ
SELECT 'Asset migration functions created successfully. Use move_files_to_inbox() to migrate files.' as status;
