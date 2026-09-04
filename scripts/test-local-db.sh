#!/bin/sh
set -eu

# Database tests need Postgres and pg_prove only. Excluding every optional
# service prevents DB-only runs from downloading or starting Storage and the
# other large Supabase service images.
#
# The excluded stack must not outlive this script. A later plain `supabase
# start` reconciles against the already-running project, so it keeps the
# DB-only service set, exits 0, and leaves a local environment with no
# Storage, Auth, or API. Stopping on exit makes the next `supabase start`
# begin from a clean state.
cleanup() {
  supabase stop >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

supabase stop
supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
supabase db reset --local
supabase test db --local
supabase db lint --local --schema public --fail-on error
