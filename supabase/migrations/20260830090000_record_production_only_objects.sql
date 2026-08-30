-- USL-270 本番だけに存在したDBオブジェクトをリポジトリへ記録する
--
-- 目的:
--   本番Supabase (project udvmzaodsrgwecfybkry) にはSQL Editorから直接作られ、
--   supabase/migrations/ に一度も記録されていないオブジェクトがある。
--   USL-244の本番読み取り監査はそれらを理由に「停止」と判定した。
--   このマイグレーションは、2026-08-30時点の本番の姿を「そのまま」写し取り、
--   隔離環境で同じ状態を再現できるようにするためのものである。
--
-- 重要:
--   これは現状記録であり、改善ではない。既知の危険をあえてそのまま再現している。
--     - public.asset_processing_queue は RLS 無効で anon に全DMLが開いている
--     - SECURITY DEFINER 関数を anon / authenticated が実行できる
--     - 6つの view が security_invoker 未設定で、実行者ではなく所有者の権限で動く
--   これらを閉じるのは後続チケットであり、この課題では扱わない。
--
-- 取得元: 本番からの読み取り専用SQL (pg_get_functiondef / pg_get_viewdef /
--         pg_attribute / pg_indexes / information_schema.role_table_grants)
-- 取得日時: 2026-08-30 08:4x UTC
-- 監査記録: docs/decisions/usl-270-production-only-objects.md

-- ---------------------------------------------------------------------------
-- 1. アセットのファイル名・パスを組み立てる補助関数
--    後述の2つの view がこれらに依存するため、view より先に作る。
--    本番では search_path が未設定である。ここでも本番に合わせる。
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.generate_image_example_filename(example_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'image_example_' || example_id || '.webp';
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_audio_example_filename(example_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'audio_example_' || example_id || '.mp3';
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_audio_meaning_filename(meaning_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'audio_meaning_' || meaning_id || '.mp3';
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_image_example_asset_path(example_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'content-images/' || generate_image_example_filename(example_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_audio_example_asset_path(example_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'content-audio/' || generate_audio_example_filename(example_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_audio_meaning_asset_path(meaning_id integer)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN 'content-audio/' || generate_audio_meaning_filename(meaning_id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. Storage policy を作り直す SECURITY DEFINER 関数
--    USL-244 が停止理由に挙げた2本。anon / authenticated から実行できる。
--    管理者判定に本番のメールアドレスを直接埋め込んでいる点も本番のままである。
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.setup_content_images_policies()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    result text := '';
BEGIN
    -- 既存のポリシーを削除
    DROP POLICY IF EXISTS "content_images_select_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_images_insert_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_images_update_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_images_delete_policy" ON storage.objects;

    -- SELECTポリシー（パブリック読み取り）
    CREATE POLICY "content_images_select_policy" ON storage.objects
        FOR SELECT
        TO public
        USING (bucket_id = 'content-images');

    -- INSERTポリシー（認証ユーザーアップロード）
    CREATE POLICY "content_images_insert_policy" ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (
            bucket_id = 'content-images'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    -- UPDATEポリシー（認証ユーザー更新）
    CREATE POLICY "content_images_update_policy" ON storage.objects
        FOR UPDATE
        TO authenticated
        USING (
            bucket_id = 'content-images'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        )
        WITH CHECK (
            bucket_id = 'content-images'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    -- DELETEポリシー（認証ユーザー削除）
    CREATE POLICY "content_images_delete_policy" ON storage.objects
        FOR DELETE
        TO authenticated
        USING (
            bucket_id = 'content-images'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    result := 'content-imagesバケットのポリシー設定が完了しました';
    RETURN result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.optimize_content_audio_policies()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    result text := '';
BEGIN
    -- 既存のポリシーを削除
    DROP POLICY IF EXISTS "content_audio_select_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_audio_insert_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_audio_update_policy" ON storage.objects;
    DROP POLICY IF EXISTS "content_audio_delete_policy" ON storage.objects;

    -- SELECTポリシー（パブリック読み取り）
    CREATE POLICY "content_audio_select_policy" ON storage.objects
        FOR SELECT
        TO public
        USING (bucket_id = 'content-audio');

    -- INSERTポリシー（認証ユーザーアップロード + 管理者権限）
    CREATE POLICY "content_audio_insert_policy" ON storage.objects
        FOR INSERT
        TO authenticated
        WITH CHECK (
            bucket_id = 'content-audio'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    -- UPDATEポリシー（認証ユーザー更新 + 管理者権限）
    CREATE POLICY "content_audio_update_policy" ON storage.objects
        FOR UPDATE
        TO authenticated
        USING (
            bucket_id = 'content-audio'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        )
        WITH CHECK (
            bucket_id = 'content-audio'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    -- DELETEポリシー（認証ユーザー削除 + 管理者権限）
    CREATE POLICY "content_audio_delete_policy" ON storage.objects
        FOR DELETE
        TO authenticated
        USING (
            bucket_id = 'content-audio'
            AND (
                EXISTS (
                    SELECT 1 FROM auth.users
                    WHERE auth.users.id = (select auth.uid())
                    AND auth.users.email IN (
                        'admin@usalingo.com',
                        'developer@usalingo.com'
                    )
                )
                OR
                (storage.foldername(name))[1] = (select auth.uid())::text
            )
        );

    result := 'content-audioバケットのポリシー最適化が完了しました';
    RETURN result;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. 画像の一括同期と、監視系の SECURITY DEFINER 関数
--    sync_existing_images は本番のプロジェクトURLと、現行スキーマには存在しない
--    列 (example_contents.illustration_url, words.word_text 経由の word_id) を
--    参照する。本番のまま写しているため、実行すると失敗する可能性が高い。
--    plpgsql は本体を実行時にしか検証しないため、作成自体は成功する。
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_existing_images()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    file_record RECORD;
    extracted_word TEXT;
    image_url TEXT;
    example_content_id INT;
BEGIN
    -- content-imagesバケット内の全ファイルを処理
    FOR file_record IN
        SELECT name
        FROM storage.objects
        WHERE bucket_id = 'content-images'
    LOOP
        -- ファイル名から単語を抽出
        extracted_word := split_part(file_record.name, '_', 1);

        -- 公開URLを構築
        image_url := 'https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/content-images/' || file_record.name;

        -- example_contentsテーブルから該当する単語のレコードを検索
        SELECT ec.id INTO example_content_id
        FROM example_contents ec
        JOIN words w ON ec.word_id = w.id
        WHERE w.word_text = extracted_word
        LIMIT 1;

        -- レコードが見つかった場合、illustration_urlを更新
        IF example_content_id IS NOT NULL THEN
            UPDATE example_contents
            SET illustration_url = image_url,
                updated_at = NOW()
            WHERE id = example_content_id;

            RAISE NOTICE 'Synced illustration_url for word "%": %', extracted_word, image_url;
        END IF;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_index_recommendations()
 RETURNS TABLE(table_name text, column_name text, recommendation text, estimated_benefit text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    SELECT
        schemaname||'.'||relname as table_name,
        attname as column_name,
        'Consider adding index on frequently queried column' as recommendation,
        'High' as estimated_benefit
    FROM pg_stat_user_tables t
    JOIN pg_attribute a ON a.attrelid = t.relid
    WHERE schemaname = 'public'
    AND a.attnum > 0
    AND NOT a.attisdropped
    AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid = t.relid
        AND a.attnum = ANY(i.indkey)
    )
    LIMIT 10;
$function$;

CREATE OR REPLACE FUNCTION public.get_performance_summary()
 RETURNS TABLE(metric_name text, metric_value text, metric_description text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    SELECT
        'total_tables'::text,
        count(*)::text,
        'Total number of tables in public schema'::text
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'

    UNION ALL

    SELECT
        'total_indexes'::text,
        count(*)::text,
        'Total number of indexes in public schema'::text
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'

    UNION ALL

    SELECT
        'database_size'::text,
        pg_size_pretty(pg_database_size(current_database()))::text,
        'Total database size'::text;
$function$;

-- ---------------------------------------------------------------------------
-- 4. アセット紐付け処理の非同期キュー
--    本番では RLS が無効で、anon / authenticated に全DMLが開いている。
--    現状記録のため、その状態をそのまま再現する。閉じるのは後続チケット。
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.asset_processing_queue (
    id             integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    table_name     text        NOT NULL,
    record_id      integer     NOT NULL,
    asset_type     text        NOT NULL,
    status         text        NOT NULL DEFAULT 'pending',
    created_at     timestamptz NOT NULL DEFAULT now(),
    processed_at   timestamptz,
    error_message  text,
    retry_count    integer     DEFAULT 0
);

COMMENT ON TABLE public.asset_processing_queue IS 'アセット紐付け処理の非同期キュー';

CREATE INDEX IF NOT EXISTS idx_asset_queue_status
    ON public.asset_processing_queue USING btree (status);
CREATE INDEX IF NOT EXISTS idx_asset_queue_table_record
    ON public.asset_processing_queue USING btree (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_asset_queue_created_at
    ON public.asset_processing_queue USING btree (created_at);

-- 本番の状態: RLS 無効。ENABLE しないことが現状の再現である。
ALTER TABLE public.asset_processing_queue DISABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 5. view
--    本番では security_invoker が未設定のため、実行者ではなく所有者 (postgres)
--    の権限で動く。reloptions を付けないことが現状の再現である。
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.v_word_meanings_with_paths AS
 SELECT id,
    word_id,
    priority,
    part_of_speech_en,
    part_of_speech_jp,
    definition_jp,
    cefr_level,
    etymology,
    synonyms,
    antonyms,
    pronunciation_ipa,
    pronunciation_kana,
    pronunciation_cmu,
    inflections,
    derivatives,
    collocations,
    related_phrases,
    created_at,
    updated_at,
    audio_asset_path,
    generate_audio_meaning_filename(id) AS audio_filename,
    get_audio_meaning_asset_path(id) AS audio_path_generated
   FROM word_meanings wm;

CREATE OR REPLACE VIEW public.v_example_contents_with_paths AS
 SELECT id,
    meaning_id,
    theme,
    sentence_en,
    sentence_jp,
    created_at,
    updated_at,
    image_asset_path AS illustration_asset_path,
    audio_asset_path,
    generate_image_example_filename(id) AS illustration_filename,
    generate_audio_example_filename(id) AS audio_filename,
    get_image_example_asset_path(id) AS illustration_path_generated,
    get_audio_example_asset_path(id) AS audio_path_generated
   FROM example_contents ec;

CREATE OR REPLACE VIEW public.v_index_usage_stats AS
 SELECT schemaname,
    relname AS tablename,
    indexrelname AS indexname,
    idx_tup_read,
    idx_tup_fetch,
        CASE
            WHEN idx_tup_read > 0 THEN round(idx_tup_fetch::numeric / idx_tup_read::numeric * 100::numeric, 2)
            ELSE 0::numeric
        END AS hit_ratio_percent
   FROM pg_stat_user_indexes
  WHERE indexrelname ~~ '%gin%'::text
  ORDER BY idx_tup_read DESC;

CREATE OR REPLACE VIEW public.v_index_monitoring AS
 SELECT schemaname,
    relname AS tablename,
    indexrelname AS indexname,
    idx_tup_read,
    idx_tup_fetch,
        CASE
            WHEN idx_tup_read > 0 THEN round(idx_tup_fetch::numeric / idx_tup_read::numeric * 100::numeric, 2)
            ELSE 0::numeric
        END AS hit_ratio_percent,
    pg_size_pretty(pg_relation_size(indexrelid::regclass)) AS index_size
   FROM pg_stat_user_indexes
  WHERE schemaname = 'public'::name
  ORDER BY idx_tup_read DESC;

CREATE OR REPLACE VIEW public.v_database_size_monitoring AS
 SELECT schemaname,
    relname AS tablename,
    pg_size_pretty(pg_total_relation_size(((schemaname::text || '.'::text) || relname::text)::regclass)) AS total_size,
    pg_size_pretty(pg_relation_size(((schemaname::text || '.'::text) || relname::text)::regclass)) AS table_size,
    pg_size_pretty(pg_total_relation_size(((schemaname::text || '.'::text) || relname::text)::regclass) - pg_relation_size(((schemaname::text || '.'::text) || relname::text)::regclass)) AS index_size,
    n_live_tup AS row_count
   FROM pg_stat_user_tables
  WHERE schemaname = 'public'::name
  ORDER BY (pg_total_relation_size(((schemaname::text || '.'::text) || relname::text)::regclass)) DESC;

CREATE OR REPLACE VIEW public.v_table_stats_monitoring AS
 SELECT 'table_stats'::text AS metric_type,
    (schemaname::text || '.'::text) || relname::text AS query,
    n_tup_ins + n_tup_upd + n_tup_del AS calls,
    n_live_tup AS total_time,
    n_dead_tup AS mean_time,
    n_tup_ins + n_tup_upd + n_tup_del AS rows,
    0 AS hit_percent
   FROM pg_stat_user_tables
  WHERE schemaname = 'public'::name
  ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC
 LIMIT 20;

-- ---------------------------------------------------------------------------
-- 6. GRANT
--    本番の現在値をそのまま写す。過剰であることは承知のうえで記録している。
-- ---------------------------------------------------------------------------

GRANT ALL ON TABLE public.asset_processing_queue TO anon, authenticated, service_role;

GRANT ALL ON TABLE public.v_word_meanings_with_paths     TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.v_example_contents_with_paths  TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.v_index_usage_stats            TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.v_index_monitoring             TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.v_database_size_monitoring     TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.v_table_stats_monitoring       TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.setup_content_images_policies()   TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.optimize_content_audio_policies() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_existing_images()            TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_index_recommendations()       TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_performance_summary()         TO anon, authenticated, service_role;
