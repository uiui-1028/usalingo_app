#!/bin/sh
set -eu

# Database tests need Postgres and pg_prove only. Excluding every optional
# service prevents DB-only runs from downloading or starting Storage and the
# other large Supabase service images.
supabase stop
supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
supabase db reset --local
supabase test db --local
supabase db lint --local --schema public --fail-on error
