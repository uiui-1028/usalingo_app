#!/bin/sh
set -eu

# USL-224 local-only Data API exposure check.
#
# 20260830150000_close_production_only_exposure.sql closes the objects that were
# created directly in production and recorded by USL-270. pgTAP proves the
# catalog state (GRANT, RLS, security_invoker). This script proves the behaviour
# that matters to a client: PostgREST actually refuses those objects.
#
# USL-244's remaining stop condition asked for exactly this. scripts/
# test-local-account-e2e.sh exercises the Data API for the app's own tables, but
# never touches asset_processing_queue or the six production-only views.
#
# It never accepts a remote project URL and makes no production change.

for command_name in curl jq supabase; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$command_name" >&2
    exit 2
  }
done

project_id=$(sed -n 's/^project_id = "\([^"]*\)"/\1/p' supabase/config.toml)
if [ "$project_id" != "usalingo-local" ]; then
  printf 'refusing non-local Supabase project_id: %s\n' "$project_id" >&2
  exit 2
fi

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# The CLI emits shell-quoted local credentials. Do not print them.
eval "$(supabase status -o env 2>/dev/null)"
case "$API_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) printf 'refusing non-local API URL\n' >&2; exit 2 ;;
esac

status_of() {
  method=$1
  path=$2
  key=$3
  body=${4-}

  set -- -sS -o /dev/null -w '%{http_code}' -X "$method" "$API_URL/rest/v1/$path" \
    -H "apikey: $key" \
    -H "Authorization: Bearer $key" \
    -H 'content-type: application/json'
  if [ -n "$body" ]; then
    set -- "$@" -d "$body"
  fi
  curl "$@"
}

# PostgREST answers a revoked table or function with 401/403/404 depending on
# whether the role lacks the privilege or the object is not exposed at all.
# Any of those means "closed". A 2xx means the object is still reachable.
assert_closed() {
  label=$1
  actual=$2
  case "$actual" in
    2*) fail "$label is still reachable (HTTP $actual)" ;;
    *)  printf 'PASS: %s (HTTP %s)\n' "$label" "$actual" ;;
  esac
}

assert_open() {
  label=$1
  actual=$2
  case "$actual" in
    2*) printf 'PASS: %s (HTTP %s)\n' "$label" "$actual" ;;
    *)  fail "$label should still be readable but returned HTTP $actual" ;;
  esac
}

printf '== asset_processing_queue ==\n'
assert_closed 'anon cannot read asset_processing_queue' \
  "$(status_of GET 'asset_processing_queue?select=id' "$ANON_KEY")"
assert_closed 'anon cannot insert into asset_processing_queue' \
  "$(status_of POST 'asset_processing_queue' "$ANON_KEY" \
     '{"table_name":"x","record_id":1,"asset_type":"image"}')"

printf '== policy-rewriting SECURITY DEFINER functions ==\n'
assert_closed 'anon cannot call setup_content_images_policies' \
  "$(status_of POST 'rpc/setup_content_images_policies' "$ANON_KEY" '{}')"
assert_closed 'anon cannot call optimize_content_audio_policies' \
  "$(status_of POST 'rpc/optimize_content_audio_policies' "$ANON_KEY" '{}')"

printf '== monitoring functions and views ==\n'
assert_closed 'anon cannot call get_index_recommendations' \
  "$(status_of POST 'rpc/get_index_recommendations' "$ANON_KEY" '{}')"
assert_closed 'anon cannot call get_performance_summary' \
  "$(status_of POST 'rpc/get_performance_summary' "$ANON_KEY" '{}')"
assert_closed 'anon cannot read v_index_usage_stats' \
  "$(status_of GET 'v_index_usage_stats?select=*' "$ANON_KEY")"
assert_closed 'anon cannot read v_index_monitoring' \
  "$(status_of GET 'v_index_monitoring?select=*' "$ANON_KEY")"
assert_closed 'anon cannot read v_database_size_monitoring' \
  "$(status_of GET 'v_database_size_monitoring?select=*' "$ANON_KEY")"
assert_closed 'anon cannot read v_table_stats_monitoring' \
  "$(status_of GET 'v_table_stats_monitoring?select=*' "$ANON_KEY")"

printf '== content views keep read access, lose write access ==\n'
assert_open 'anon can still read v_word_meanings_with_paths' \
  "$(status_of GET 'v_word_meanings_with_paths?select=id&limit=1' "$ANON_KEY")"
assert_open 'anon can still read v_example_contents_with_paths' \
  "$(status_of GET 'v_example_contents_with_paths?select=id&limit=1' "$ANON_KEY")"
assert_closed 'anon cannot write through v_word_meanings_with_paths' \
  "$(status_of POST 'v_word_meanings_with_paths' "$ANON_KEY" '{"id":999999}')"
assert_closed 'anon cannot write through v_example_contents_with_paths' \
  "$(status_of POST 'v_example_contents_with_paths' "$ANON_KEY" '{"id":999999}')"

printf '== dropped function stays gone ==\n'
assert_closed 'sync_existing_images is not callable' \
  "$(status_of POST 'rpc/sync_existing_images' "$ANON_KEY" '{}')"

printf '\n'
if [ "$failures" -ne 0 ]; then
  printf 'USL-224 Data API exposure check FAILED: %s problem(s)\n' "$failures" >&2
  exit 1
fi

printf 'USL-224 Data API exposure check passed.\n'
printf 'Environment: project_id=%s API=local production_changes=0\n' "$project_id"
