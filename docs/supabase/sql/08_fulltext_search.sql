-- =============================================
-- 全文検索インデックスの追加
-- =============================================
-- 作成日: 2025-10-01
-- 目的: pg_trgm拡張機能とGINインデックスによる高速な全文検索機能の実装

-- =============================================
-- 1. pg_trgm拡張機能の有効化
-- =============================================

-- pg_trgm拡張機能を有効化（中間一致検索とあいまい検索のため）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================
-- 2. 全文検索用GINインデックスの作成
-- =============================================

-- wordsテーブルの全文検索インデックス
CREATE INDEX IF NOT EXISTS idx_words_word_text_gin 
ON public.words USING gin(word_text gin_trgm_ops);

-- word_meaningsテーブルの全文検索インデックス
CREATE INDEX IF NOT EXISTS idx_word_meanings_definition_jp_gin 
ON public.word_meanings USING gin(definition_jp gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_word_meanings_part_of_speech_en_gin 
ON public.word_meanings USING gin(part_of_speech_en gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_word_meanings_part_of_speech_jp_gin 
ON public.word_meanings USING gin(part_of_speech_jp gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_word_meanings_etymology_gin 
ON public.word_meanings USING gin(etymology gin_trgm_ops);

-- example_contentsテーブルの全文検索インデックス
CREATE INDEX IF NOT EXISTS idx_example_contents_sentence_en_gin 
ON public.example_contents USING gin(sentence_en gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_example_contents_sentence_jp_gin 
ON public.example_contents USING gin(sentence_jp gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_example_contents_theme_gin 
ON public.example_contents USING gin(theme gin_trgm_ops);

-- decksテーブルの全文検索インデックス
CREATE INDEX IF NOT EXISTS idx_decks_deck_name_gin 
ON public.decks USING gin(deck_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_decks_description_gin 
ON public.decks USING gin(description gin_trgm_ops);

-- =============================================
-- 3. 検索関数の実装
-- =============================================

-- 単語検索関数（あいまい検索対応）
CREATE OR REPLACE FUNCTION search_words(
    search_term TEXT,
    similarity_threshold REAL DEFAULT 0.3,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    word_id INTEGER,
    word_text TEXT,
    similarity REAL,
    definition_jp TEXT,
    part_of_speech_jp TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        w.id,
        w.word_text,
        similarity(w.word_text, search_term) as similarity,
        wm.definition_jp,
        wm.part_of_speech_jp
    FROM public.words w
    LEFT JOIN public.word_meanings wm ON w.id = wm.word_id AND wm.priority = 1
    WHERE w.word_text % search_term
        OR similarity(w.word_text, search_term) > similarity_threshold
    ORDER BY similarity DESC, w.word_text
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 意味検索関数
CREATE OR REPLACE FUNCTION search_meanings(
    search_term TEXT,
    similarity_threshold REAL DEFAULT 0.3,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    meaning_id INTEGER,
    word_text TEXT,
    definition_jp TEXT,
    part_of_speech_jp TEXT,
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wm.id,
        w.word_text,
        wm.definition_jp,
        wm.part_of_speech_jp,
        similarity(wm.definition_jp, search_term) as similarity
    FROM public.word_meanings wm
    JOIN public.words w ON wm.word_id = w.id
    WHERE wm.definition_jp % search_term
        OR similarity(wm.definition_jp, search_term) > similarity_threshold
    ORDER BY similarity DESC, wm.definition_jp
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- 例文検索関数
CREATE OR REPLACE FUNCTION search_examples(
    search_term TEXT,
    language TEXT DEFAULT 'en',
    similarity_threshold REAL DEFAULT 0.3,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    example_id INTEGER,
    word_text TEXT,
    sentence TEXT,
    translation TEXT,
    theme TEXT,
    similarity REAL
) AS $$
BEGIN
    IF language = 'en' THEN
        RETURN QUERY
        SELECT 
            ec.id,
            w.word_text,
            ec.sentence_en as sentence,
            ec.sentence_jp as translation,
            ec.theme,
            similarity(ec.sentence_en, search_term) as similarity
        FROM public.example_contents ec
        JOIN public.word_meanings wm ON ec.meaning_id = wm.id
        JOIN public.words w ON wm.word_id = w.id
        WHERE ec.sentence_en % search_term
            OR similarity(ec.sentence_en, search_term) > similarity_threshold
        ORDER BY similarity DESC, ec.sentence_en
        LIMIT limit_count;
    ELSE
        RETURN QUERY
        SELECT 
            ec.id,
            w.word_text,
            ec.sentence_jp as sentence,
            ec.sentence_en as translation,
            ec.theme,
            similarity(ec.sentence_jp, search_term) as similarity
        FROM public.example_contents ec
        JOIN public.word_meanings wm ON ec.meaning_id = wm.id
        JOIN public.words w ON wm.word_id = w.id
        WHERE ec.sentence_jp % search_term
            OR similarity(ec.sentence_jp, search_term) > similarity_threshold
        ORDER BY similarity DESC, ec.sentence_jp
        LIMIT limit_count;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 統合検索関数（単語、意味、例文を横断検索）
CREATE OR REPLACE FUNCTION search_all(
    search_term TEXT,
    similarity_threshold REAL DEFAULT 0.3,
    limit_count INTEGER DEFAULT 100
)
RETURNS TABLE (
    result_type TEXT,
    result_id INTEGER,
    word_text TEXT,
    content TEXT,
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    -- 単語検索結果
    SELECT 
        'word'::TEXT,
        w.id::INTEGER,
        w.word_text,
        w.word_text,
        similarity(w.word_text, search_term)
    FROM public.words w
    WHERE w.word_text % search_term
        OR similarity(w.word_text, search_term) > similarity_threshold
    
    UNION ALL
    
    -- 意味検索結果
    SELECT 
        'meaning'::TEXT,
        wm.id::INTEGER,
        w.word_text,
        wm.definition_jp,
        similarity(wm.definition_jp, search_term)
    FROM public.word_meanings wm
    JOIN public.words w ON wm.word_id = w.id
    WHERE wm.definition_jp % search_term
        OR similarity(wm.definition_jp, search_term) > similarity_threshold
    
    UNION ALL
    
    -- 例文検索結果（英語）
    SELECT 
        'example_en'::TEXT,
        ec.id::INTEGER,
        w.word_text,
        ec.sentence_en,
        similarity(ec.sentence_en, search_term)
    FROM public.example_contents ec
    JOIN public.word_meanings wm ON ec.meaning_id = wm.id
    JOIN public.words w ON wm.word_id = w.id
    WHERE ec.sentence_en % search_term
        OR similarity(ec.sentence_en, search_term) > similarity_threshold
    
    UNION ALL
    
    -- 例文検索結果（日本語）
    SELECT 
        'example_jp'::TEXT,
        ec.id::INTEGER,
        w.word_text,
        ec.sentence_jp,
        similarity(ec.sentence_jp, search_term)
    FROM public.example_contents ec
    JOIN public.word_meanings wm ON ec.meaning_id = wm.id
    JOIN public.words w ON wm.word_id = w.id
    WHERE ec.sentence_jp % search_term
        OR similarity(ec.sentence_jp, search_term) > similarity_threshold
    
    ORDER BY similarity DESC, content
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. パフォーマンス監視用ビュー
-- =============================================

-- インデックス使用状況の監視ビュー
CREATE OR REPLACE VIEW v_index_usage_stats AS
SELECT 
    schemaname,
    relname as tablename,
    indexrelname as indexname,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_tup_read > 0 THEN 
            ROUND((idx_tup_fetch::NUMERIC / idx_tup_read::NUMERIC) * 100, 2)
        ELSE 0 
    END as hit_ratio_percent
FROM pg_stat_user_indexes 
WHERE indexrelname LIKE '%gin%'
ORDER BY idx_tup_read DESC;

-- =============================================
-- 5. 完了メッセージ
-- =============================================

SELECT '全文検索インデックスのセットアップが完了しました。' as status;

