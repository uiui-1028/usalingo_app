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
