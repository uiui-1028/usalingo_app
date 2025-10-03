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

-- =============================================
-- 複合インデックスの追加
-- =============================================
-- 作成日: 2025-10-01
-- 目的: 頻繁なクエリパターンに対応する複合インデックスを追加し、パフォーマンスを向上

-- =============================================
-- 1. 現状分析
-- =============================================

-- 現在のインデックス状況:
-- - 単一カラムインデックスが主体
-- - word_meanings: word_id のみ
-- - example_contents: meaning_id のみ
-- - 複数カラムでのフィルタリング時にパフォーマンスが低下

-- =============================================
-- 2. 複合インデックスの追加
-- =============================================

-- ----------------------------------------
-- 2-1. word_meaningsテーブル
-- ----------------------------------------

-- word_id + priority: 単語の意味を優先度順で取得
-- 用途: 単語詳細画面で意味を優先度順に表示
CREATE INDEX IF NOT EXISTS idx_word_meanings_word_priority 
ON public.word_meanings (word_id, priority);

COMMENT ON INDEX idx_word_meanings_word_priority IS 
'単語IDと優先度の複合インデックス。単語の意味を優先度順で取得する際に使用。';

-- ----------------------------------------
-- 2-2. example_contentsテーブル
-- ----------------------------------------

-- meaning_id + theme: 意味IDとテーマでの例文取得
-- 用途: 特定のテーマの例文を取得
CREATE INDEX IF NOT EXISTS idx_example_contents_meaning_theme 
ON public.example_contents (meaning_id, theme);

COMMENT ON INDEX idx_example_contents_meaning_theme IS 
'意味IDとテーマの複合インデックス。特定テーマの例文取得に使用。';

-- ----------------------------------------
-- 2-3. user_learning_progressテーブル
-- ----------------------------------------

-- user_id + status: ユーザーの学習ステータス別の単語一覧
-- 用途: 「学習中」「マスター済み」などステータス別の単語取得
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_user_status 
ON public.user_learning_progress (user_id, status);

COMMENT ON INDEX idx_user_learning_progress_user_status IS 
'ユーザーIDとステータスの複合インデックス。ステータス別の単語一覧取得に使用。';

-- user_id + next_review_date: 復習予定の単語取得
-- 用途: 今日復習すべき単語の一覧取得（SRSシステム）
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_user_next_review 
ON public.user_learning_progress (user_id, next_review_date)
WHERE next_review_date IS NOT NULL;

COMMENT ON INDEX idx_user_learning_progress_user_next_review IS 
'ユーザーIDと次回復習日の複合インデックス。復習予定の単語取得に使用（部分インデックス）。';

-- user_id + srs_level: SRSレベル別の学習進捗確認
-- 用途: レベル別の単語数集計、統計情報の取得
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_user_srs_level 
ON public.user_learning_progress (user_id, srs_level);

COMMENT ON INDEX idx_user_learning_progress_user_srs_level IS 
'ユーザーIDとSRSレベルの複合インデックス。レベル別の学習進捗確認に使用。';

-- ----------------------------------------
-- 2-4. user_widget_layoutsテーブル
-- ----------------------------------------

-- user_id + tab_name + display_order: タブ内のウィジェット配置順
-- 用途: ユーザーのタブ画面でウィジェットを表示順に取得
CREATE INDEX IF NOT EXISTS idx_user_widget_layouts_user_tab_order 
ON public.user_widget_layouts (user_id, tab_name, display_order);

COMMENT ON INDEX idx_user_widget_layouts_user_tab_order IS 
'ユーザーID、タブ名、表示順の複合インデックス。ウィジェットの配置順取得に使用。';

-- ----------------------------------------
-- 2-5. wordsテーブル（前方一致検索用）
-- ----------------------------------------

-- word_text with text_pattern_ops: 前方一致検索の最適化
-- 用途: LIKE 'apple%' のような前方一致検索
CREATE INDEX IF NOT EXISTS idx_words_text_pattern 
ON public.words (word_text text_pattern_ops);

COMMENT ON INDEX idx_words_text_pattern IS 
'単語テキストの前方一致検索用インデックス（text_pattern_ops使用）。';

-- =============================================
-- 3. カバリングインデックス（オプション）
-- =============================================

-- word_meanings: よく使用されるカラムを含むカバリングインデックス
-- 用途: 単語詳細取得時にテーブルアクセスを削減
CREATE INDEX IF NOT EXISTS idx_word_meanings_covering 
ON public.word_meanings (word_id, priority) 
INCLUDE (part_of_speech_en, part_of_speech_jp, definition_jp, cefr_level);

COMMENT ON INDEX idx_word_meanings_covering IS 
'単語の意味取得用カバリングインデックス。頻繁にアクセスされるカラムを含む。';

-- =============================================
-- 4. 既存の冗長なインデックスの確認と削除
-- =============================================

-- idx_meanings_on_word_id は idx_word_meanings_word_priority でカバーされる
-- ただし、priority を指定しない検索も多い可能性があるため、
-- パフォーマンステスト後に判断する

-- 確認用クエリ（実行のみ、削除はコメントアウト）
-- DROP INDEX IF EXISTS idx_meanings_on_word_id;

-- =============================================
-- 5. インデックス使用状況の監視関数
-- =============================================

-- インデックスの使用統計を表示する関数
CREATE OR REPLACE FUNCTION get_index_usage_stats()
RETURNS TABLE (
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    table_size TEXT,
    index_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        psat.schemaname::TEXT,
        psat.relname::TEXT,
        psat.indexrelname::TEXT,
        psat.idx_scan,
        psat.idx_tup_read,
        psat.idx_tup_fetch,
        pg_size_pretty(pg_relation_size(psat.relid)) as table_size,
        pg_size_pretty(pg_relation_size(psat.indexrelid)) as index_size
    FROM pg_stat_user_indexes psat
    WHERE psat.schemaname = 'public'
    ORDER BY psat.idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_index_usage_stats() IS 
'インデックスの使用統計を取得する関数。idx_scanが0のインデックスは未使用の可能性がある。';

-- =============================================
-- 6. 冗長インデックスの検出関数
-- =============================================

-- 冗長な可能性のあるインデックスを検出
CREATE OR REPLACE FUNCTION find_duplicate_indexes()
RETURNS TABLE (
    table_name TEXT,
    redundant_index TEXT,
    main_index TEXT,
    redundant_columns TEXT,
    main_columns TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH index_columns AS (
        SELECT 
            t.relname as table_name,
            i.relname as index_name,
            array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)) as columns,
            ix.indkey as key_positions
        FROM pg_index ix
        JOIN pg_class t ON t.oid = ix.indrelid
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_attribute a ON a.attrelid = t.oid
        WHERE t.relkind = 'r'
        AND a.attnum = ANY(ix.indkey)
        AND t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
        GROUP BY t.relname, i.relname, ix.indkey
    )
    SELECT 
        ic1.table_name::TEXT,
        ic1.index_name::TEXT as redundant_index,
        ic2.index_name::TEXT as main_index,
        array_to_string(ic1.columns, ', ')::TEXT as redundant_columns,
        array_to_string(ic2.columns, ', ')::TEXT as main_columns
    FROM index_columns ic1
    JOIN index_columns ic2 
        ON ic1.table_name = ic2.table_name 
        AND ic1.index_name < ic2.index_name
    WHERE ic1.columns[1:array_length(ic1.columns, 1)] = ic2.columns[1:array_length(ic1.columns, 1)]
        OR ic2.columns[1:array_length(ic2.columns, 1)] = ic1.columns[1:array_length(ic2.columns, 1)]
    ORDER BY ic1.table_name, ic1.index_name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_duplicate_indexes() IS 
'冗長な可能性のあるインデックスを検出する関数。複合インデックスで既存の単一インデックスがカバーされる場合を検出。';

-- =============================================
-- 7. パフォーマンステスト用のサンプルクエリ
-- =============================================

-- テスト用のクエリ例（コメントアウト）
/*
-- テスト1: word_meaningsの優先度順取得
EXPLAIN ANALYZE
SELECT * FROM word_meanings 
WHERE word_id = 1 
ORDER BY priority;

-- テスト2: example_contentsのテーマ別取得
EXPLAIN ANALYZE
SELECT * FROM example_contents 
WHERE meaning_id = 1 
AND theme = 'simple';

-- テスト3: 復習予定の単語取得
EXPLAIN ANALYZE
SELECT * FROM user_learning_progress 
WHERE user_id = '123e4567-e89b-12d3-a456-426614174000'::uuid
AND next_review_date <= NOW()
ORDER BY next_review_date;

-- テスト4: ステータス別の単語一覧
EXPLAIN ANALYZE
SELECT * FROM user_learning_progress 
WHERE user_id = '123e4567-e89b-12d3-a456-426614174000'::uuid
AND status = 'learning'
ORDER BY last_reviewed_at DESC;

-- テスト5: 前方一致検索
EXPLAIN ANALYZE
SELECT * FROM words 
WHERE word_text LIKE 'app%'
LIMIT 10;
*/

-- =============================================
-- 8. 完了メッセージ
-- =============================================

SELECT '複合インデックスのセットアップが完了しました。' as status;

