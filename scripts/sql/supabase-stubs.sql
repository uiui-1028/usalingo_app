-- Docker が使えない環境で migration を検証するための、Supabase 相当の最小スタブ。
--
-- これは本物の Supabase ではありません。migration が参照する範囲だけを、
-- 素の PostgreSQL 上に手で用意したものです。次の違いがあります。
--
--   - auth.uid() は常に NULL を返す。RLS の「自分の行だけ」は実際には効かない
--   - auth.users は id / email / created_at だけ。他の列とトリガーは無い
--   - storage.objects / storage.buckets は列だけ。Storage の実挙動は無い
--   - GoTrue、PostgREST、Realtime、Edge Runtime は存在しない
--
-- したがって、この環境で確認できるのは「SQL が構文として通り、
-- カタログ上のオブジェクトが期待どおりの形になるか」までです。
-- 認証、API、Storage の実挙動は ./scripts/test-local-db.sh（Docker 必須）で確認します。

DO $$
BEGIN
  -- ロールはクラスタ共通のため、既にあれば作らない
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin NOLOGIN;
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS auth.users (
  id         uuid PRIMARY KEY,
  email      text,
  created_at timestamptz DEFAULT now()
);

-- 本物は JWT から取り出す。ここでは常に NULL。
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql STABLE AS $$ SELECT NULL::uuid $$;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text
  LANGUAGE sql STABLE AS $$ SELECT NULL::text $$;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb
  LANGUAGE sql STABLE AS $$ SELECT '{}'::jsonb $$;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id                 text PRIMARY KEY,
  name               text,
  public             boolean DEFAULT false,
  file_size_limit    bigint,
  allowed_mime_types text[]
);

-- owner と owner_id の両方を持たせる。本物の storage.objects も両方を持ち、
-- 片方だけにすると plpgsql_check が実在する参照を誤って error と報告する。
CREATE TABLE IF NOT EXISTS storage.objects (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id  text,
  name       text,
  owner      uuid,
  owner_id   text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  metadata   jsonb
);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION storage.foldername(name text) RETURNS text[]
  LANGUAGE sql IMMUTABLE AS $$ SELECT string_to_array(name, '/') $$;

CREATE EXTENSION IF NOT EXISTS pg_trgm;
