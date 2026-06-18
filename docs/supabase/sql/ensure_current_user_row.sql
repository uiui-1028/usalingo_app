-- public.users へのクライアント INSERT は RLS で拒否されがちなため、
-- SECURITY DEFINER の RPC で auth と同じ id の行を確実に作る。
--
-- 適用方法（いずれか 1 回）:
-- - Supabase Dashboard → SQL Editor でこのファイルを実行
-- - プロジェクトルートで `supabase db push`（`supabase/migrations/` に同名マイグレーションあり）
--
-- 適用直後に PostgREST が関数を見つけられない場合は、数秒待つか Dashboard で
-- API の再読み込みを試す（稀にスキーマキャッシュの遅延あり）。

CREATE OR REPLACE FUNCTION public.ensure_current_user_row()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, created_at)
  SELECT
    au.id,
    COALESCE(au.email, ''),
    COALESCE(au.created_at, now())
  FROM auth.users AS au
  WHERE au.id = auth.uid()
  ON CONFLICT (id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_current_user_row() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_current_user_row() TO authenticated;
