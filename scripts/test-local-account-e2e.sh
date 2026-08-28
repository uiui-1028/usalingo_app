#!/bin/sh
set -eu

# USL-261 local-only account and RLS E2E.
# This resets the Supabase project identified by supabase/config.toml, creates
# synthetic A/B accounts, withdraws A, advances only A's synthetic deletion
# clock, and then permanently purges A. It never accepts a remote project URL.

for command_name in curl jq supabase docker uuidgen; do
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

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/usalingo-261.XXXXXX")
function_pid=""
cleanup() {
  if [ -n "$function_pid" ]; then
    kill "$function_pid" >/dev/null 2>&1 || true
    wait "$function_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_status() {
  label=$1
  actual=$2
  expected=$3
  [ "$actual" = "$expected" ] || fail "$label returned HTTP $actual, expected $expected"
  printf 'PASS: %s\n' "$label"
}

assert_json_length() {
  label=$1
  file=$2
  expected=$3
  actual=$(jq 'length' "$file")
  [ "$actual" = "$expected" ] || fail "$label returned $actual rows, expected $expected"
  printf 'PASS: %s\n' "$label"
}

request() {
  method=$1
  url=$2
  output=$3
  key=$4
  token=$5
  body=${6-}

  set -- -sS -o "$output" -w '%{http_code}' -X "$method" "$url" \
    -H "apikey: $key" \
    -H 'content-type: application/json'
  if [ -n "$token" ]; then
    set -- "$@" -H "Authorization: Bearer $token"
  fi
  if [ -n "$body" ]; then
    set -- "$@" -d "$body"
  fi
  curl "$@"
}

supabase stop >/dev/null
supabase start >/dev/null
supabase db reset --local >/dev/null

# The CLI emits shell-quoted local credentials. Do not print them.
eval "$(supabase status -o env 2>/dev/null)"
case "$API_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) fail "refusing non-local API URL" ;;
esac
case "$INBUCKET_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) fail "refusing non-local Mailpit URL" ;;
esac

supabase functions serve delete-user-account >"$tmp_dir/function.log" 2>&1 &
function_pid=$!
ready=0
attempt=0
while [ "$attempt" -lt 30 ]; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$API_URL/functions/v1/delete-user-account" \
    -H 'content-type: application/json' -d '{}' || true)
  if [ "$code" = "401" ]; then
    ready=1
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$ready" = "1" ] || {
  sed -n '1,80p' "$tmp_dir/function.log" >&2
  fail "local delete-user-account function did not become ready"
}

run_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
email_a="usl261-a-$run_id@example.test"
email_b="usl261-b-$run_id@example.test"
email_a_new="usl261-a-new-$run_id@example.test"
password_a='Local-only-A-261!'
password_b='Local-only-B-261!'
request_id=$(uuidgen | tr '[:upper:]' '[:lower:]')

signup_a=$(jq -nc --arg email "$email_a" --arg password "$password_a" '{email:$email,password:$password}')
signup_b=$(jq -nc --arg email "$email_b" --arg password "$password_b" '{email:$email,password:$password}')
code=$(request POST "$API_URL/auth/v1/signup" "$tmp_dir/signup-a.json" "$ANON_KEY" "" "$signup_a")
assert_status "create synthetic user A" "$code" 200
code=$(request POST "$API_URL/auth/v1/signup" "$tmp_dir/signup-b.json" "$ANON_KEY" "" "$signup_b")
assert_status "create synthetic user B" "$code" 200

token_a=$(jq -er '.access_token' "$tmp_dir/signup-a.json")
token_b=$(jq -er '.access_token' "$tmp_dir/signup-b.json")
user_a=$(jq -er '.user.id' "$tmp_dir/signup-a.json")
user_b=$(jq -er '.user.id' "$tmp_dir/signup-b.json")

code=$(request POST "$API_URL/rest/v1/rpc/ensure_current_user_row" "$tmp_dir/rpc-a.json" "$ANON_KEY" "$token_a" '{}')
assert_status "create A application row" "$code" 204
code=$(request POST "$API_URL/rest/v1/rpc/ensure_current_user_row" "$tmp_dir/rpc-b.json" "$ANON_KEY" "$token_b" '{}')
assert_status "create B application row" "$code" 204

profile_a=$(jq -nc --arg user_id "$user_a" '{user_id:$user_id,nickname:"A-local"}')
profile_b=$(jq -nc --arg user_id "$user_b" '{user_id:$user_id,nickname:"B-local"}')
code=$(request POST "$API_URL/rest/v1/user_profiles" "$tmp_dir/profile-a.json" "$ANON_KEY" "$token_a" "$profile_a")
assert_status "A writes own profile" "$code" 201
code=$(request POST "$API_URL/rest/v1/user_profiles" "$tmp_dir/profile-b.json" "$ANON_KEY" "$token_b" "$profile_b")
assert_status "B writes own profile" "$code" 201

code=$(request GET "$API_URL/rest/v1/cards?select=id&limit=1" "$tmp_dir/cards.json" "$ANON_KEY" "$token_a")
assert_status "A reads official cards" "$code" 200
card_id=$(jq -er '.[0].id' "$tmp_dir/cards.json")
progress_a=$(jq -nc --arg user_id "$user_a" --argjson card_id "$card_id" \
  '{user_id:$user_id,card_id:$card_id,status:"learning",next_review_date:"2026-08-28T00:00:00Z"}')
progress_b=$(jq -nc --arg user_id "$user_b" --argjson card_id "$card_id" \
  '{user_id:$user_id,card_id:$card_id,status:"learning",next_review_date:"2026-08-28T00:00:00Z"}')
code=$(request POST "$API_URL/rest/v1/user_card_progress" "$tmp_dir/progress-a.json" "$ANON_KEY" "$token_a" "$progress_a")
assert_status "A writes own learning progress" "$code" 201
code=$(request POST "$API_URL/rest/v1/user_card_progress" "$tmp_dir/progress-b.json" "$ANON_KEY" "$token_b" "$progress_b")
assert_status "B writes own learning progress" "$code" 201

code=$(request GET "$API_URL/rest/v1/user_profiles?user_id=eq.$user_a&select=user_id,nickname" "$tmp_dir/a-own-profile.json" "$ANON_KEY" "$token_a")
assert_status "A reads own profile" "$code" 200
assert_json_length "A sees one own profile" "$tmp_dir/a-own-profile.json" 1
code=$(request PATCH "$API_URL/rest/v1/user_profiles?user_id=eq.$user_a" "$tmp_dir/a-own-update.json" "$ANON_KEY" "$token_a" '{"nickname":"A-updated"}')
assert_status "A updates own profile" "$code" 204

code=$(request GET "$API_URL/rest/v1/user_profiles?user_id=eq.$user_b&select=user_id" "$tmp_dir/a-reads-b.json" "$ANON_KEY" "$token_a")
assert_status "A attempts to read B profile" "$code" 200
assert_json_length "RLS hides B profile from A" "$tmp_dir/a-reads-b.json" 0
code=$(request PATCH "$API_URL/rest/v1/user_profiles?user_id=eq.$user_b" "$tmp_dir/a-updates-b.json" "$ANON_KEY" "$token_a" '{"nickname":"tampered"}')
assert_status "A attempts to update B profile" "$code" 204
code=$(request DELETE "$API_URL/rest/v1/user_card_progress?user_id=eq.$user_b" "$tmp_dir/a-deletes-b.json" "$ANON_KEY" "$token_a")
assert_status "A attempts to delete B progress" "$code" 204
code=$(request GET "$API_URL/rest/v1/user_profiles?user_id=eq.$user_b&nickname=eq.B-local&select=user_id" "$tmp_dir/b-profile-intact.json" "$ANON_KEY" "$token_b")
assert_status "B verifies own profile" "$code" 200
assert_json_length "B profile is unchanged" "$tmp_dir/b-profile-intact.json" 1
code=$(request GET "$API_URL/rest/v1/user_card_progress?user_id=eq.$user_b&select=user_id" "$tmp_dir/b-progress-intact.json" "$ANON_KEY" "$token_b")
assert_status "B verifies own progress" "$code" 200
assert_json_length "B progress survives A delete attempt" "$tmp_dir/b-progress-intact.json" 1

anon_profile_code=$(request GET "$API_URL/rest/v1/user_profiles?select=user_id" "$tmp_dir/anon-profile.json" "$ANON_KEY" "")
case "$anon_profile_code" in 401|403) printf 'PASS: anonymous profile access is rejected\n' ;; *) fail "anonymous profile access returned HTTP $anon_profile_code" ;; esac
anon_delete_code=$(request POST "$API_URL/functions/v1/delete-user-account" "$tmp_dir/anon-delete.json" "$ANON_KEY" "" '{}')
assert_status "anonymous account deletion is rejected" "$anon_delete_code" 401

recovery_body=$(jq -nc --arg email "$email_a" '{email:$email}')
code=$(request POST "$API_URL/auth/v1/recover?redirect_to=usalingo%3A%2F%2Fauth%2Frecovery" "$tmp_dir/recovery.json" "$ANON_KEY" "" "$recovery_body")
assert_status "password recovery request accepts the app link" "$code" 200
code=$(request GET "$API_URL/auth/v1/reauthenticate" "$tmp_dir/reauth.json" "$ANON_KEY" "$token_a" '{}')
assert_status "reauthentication request succeeds" "$code" 200

wrong_signin=$(jq -nc --arg email "$email_a" '{email:$email,password:"wrong-local-password"}')
code=$(request POST "$API_URL/auth/v1/token?grant_type=password" "$tmp_dir/wrong-password.json" "$ANON_KEY" "" "$wrong_signin")
assert_status "wrong current password is rejected" "$code" 400
email_change=$(jq -nc --arg email "$email_a_new" '{email:$email}')
code=$(request PUT "$API_URL/auth/v1/user" "$tmp_dir/email-change.json" "$ANON_KEY" "$token_a" "$email_change")
assert_status "email change request succeeds" "$code" 200

mail_ready=0
attempt=0
while [ "$attempt" -lt 20 ]; do
  messages=$(curl -sS "$INBUCKET_URL/api/v1/messages")
  recovery_count=$(printf '%s' "$messages" | jq --arg email "$email_a" '[.messages[] | select(.Subject == "Reset Your Password" and (.To | any(.Address == $email)))] | length')
  reauth_count=$(printf '%s' "$messages" | jq --arg email "$email_a" '[.messages[] | select(.Subject == "Confirm reauthentication" and (.To | any(.Address == $email)))] | length')
  email_change_count=$(printf '%s' "$messages" | jq --arg old "$email_a" --arg new "$email_a_new" '[.messages[] | select(.Subject == "Confirm Email Change" and (.To | any(.Address == $old or .Address == $new)))] | length')
  if [ "$recovery_count" -ge 1 ] && [ "$reauth_count" -ge 1 ] && [ "$email_change_count" -ge 2 ]; then
    mail_ready=1
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$mail_ready" = "1" ] || fail "local Mailpit did not receive recovery, reauthentication, and email-change messages"
printf 'PASS: recovery, reauthentication, and email-change messages reach local Mailpit\n'

recovery_message_id=$(printf '%s' "$messages" | jq -er --arg email "$email_a" '.messages[] | select(.Subject == "Reset Your Password" and (.To | any(.Address == $email))) | .ID' | head -1)
recovery_link=$(curl -sS "$INBUCKET_URL/api/v1/message/$recovery_message_id" \
  | jq -er '.HTML' \
  | sed -n 's/.*href="\([^"]*\)".*/\1/p' \
  | sed 's/&amp;/\&/g')
case "$recovery_link" in
  "$API_URL"/auth/v1/verify?*) ;;
  *) fail "recovery message did not contain a local Auth verification link" ;;
esac
recovery_verify_code=$(curl -sS -D "$tmp_dir/recovery-verify.headers" -o /dev/null -w '%{http_code}' "$recovery_link")
case "$recovery_verify_code" in
  302|303) ;;
  *) fail "recovery link returned HTTP $recovery_verify_code, expected 302 or 303" ;;
esac
recovery_location=$(sed -n 's/^[Ll]ocation: //p' "$tmp_dir/recovery-verify.headers" | tr -d '\r')
case "$recovery_location" in
  usalingo://auth/recovery?*|usalingo://auth/recovery#*) ;;
  *) fail "recovery link did not redirect to the app recovery URL" ;;
esac
printf 'PASS: recovery link redirects to the app recovery URL\n'

code=$(request GET "$API_URL/rest/v1/words?select=id&limit=100" "$tmp_dir/official-before.json" "$ANON_KEY" "$token_b")
assert_status "B reads official content before A withdrawal" "$code" 200
official_before=$(jq 'length' "$tmp_dir/official-before.json")
[ "$official_before" -gt 0 ] || fail "official content seed is empty"

mismatch_body=$(jq -nc --arg request_id "$request_id" --arg password "$password_a" --arg user_id "$user_b" \
  '{request_id:$request_id,confirmation:"退会",password:$password,user_id:$user_id}')
code=$(request POST "$API_URL/functions/v1/delete-user-account" "$tmp_dir/mismatch.json" "$ANON_KEY" "$token_a" "$mismatch_body")
assert_status "A cannot target B for withdrawal" "$code" 403
bad_withdrawal=$(jq -nc --arg request_id "$request_id" '{request_id:$request_id,confirmation:"退会",password:"wrong-local-password"}')
code=$(request POST "$API_URL/functions/v1/delete-user-account" "$tmp_dir/bad-withdrawal.json" "$ANON_KEY" "$token_a" "$bad_withdrawal")
assert_status "withdrawal rejects a wrong password" "$code" 403
withdrawal=$(jq -nc --arg request_id "$request_id" --arg password "$password_a" \
  '{request_id:$request_id,confirmation:"退会",password:$password}')
code=$(request POST "$API_URL/functions/v1/delete-user-account" "$tmp_dir/withdrawal.json" "$ANON_KEY" "$token_a" "$withdrawal")
assert_status "A withdrawal succeeds" "$code" 200
[ "$(jq -r '.status' "$tmp_dir/withdrawal.json")" = "disabled" ] || fail "A withdrawal did not return disabled"

code=$(request GET "$API_URL/rest/v1/user_profiles?select=user_id" "$tmp_dir/a-after-withdrawal.json" "$ANON_KEY" "$token_a")
assert_status "withdrawn A token reaches RLS" "$code" 200
assert_json_length "withdrawn A cannot read retained profile" "$tmp_dir/a-after-withdrawal.json" 0
signin_a=$(jq -nc --arg email "$email_a" --arg password "$password_a" '{email:$email,password:$password}')
code=$(request POST "$API_URL/auth/v1/token?grant_type=password" "$tmp_dir/a-login-after-withdrawal.json" "$ANON_KEY" "" "$signin_a")
case "$code" in 400|403) printf 'PASS: withdrawn A cannot sign in\n' ;; *) fail "withdrawn A sign-in returned HTTP $code" ;; esac

code=$(request GET "$API_URL/rest/v1/user_profiles?user_id=eq.$user_b&select=user_id" "$tmp_dir/b-after-withdrawal.json" "$ANON_KEY" "$token_b")
assert_status "B still reads own profile after A withdrawal" "$code" 200
assert_json_length "B profile survives A withdrawal" "$tmp_dir/b-after-withdrawal.json" 1
code=$(request GET "$API_URL/rest/v1/words?select=id&limit=100" "$tmp_dir/official-after-withdrawal.json" "$ANON_KEY" "$token_b")
assert_status "B reads official content after A withdrawal" "$code" 200
[ "$(jq 'length' "$tmp_dir/official-after-withdrawal.json")" = "$official_before" ] || fail "official content changed after A withdrawal"

# Move only synthetic A beyond the 365-day boundary, then exercise the server-
# secret-only final purge. UUID shape is validated before SQL interpolation.
case "$user_a" in
  ????????-????-????-????-????????????) ;;
  *) fail "synthetic A has an invalid UUID" ;;
esac
docker exec "supabase_db_$project_id" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 \
  -c "update private.account_deletions set requested_at = now() - interval '366 days', restorable_until = now() - interval '1 day' where user_id = '$user_a'::uuid;" >/dev/null
purge_body=$(jq -nc --arg user_id "$user_a" --arg request_id "$request_id" \
  '{operation:"purge",user_id:$user_id,request_id:$request_id,confirmation:"退会",password:"unused"}')
code=$(request POST "$API_URL/functions/v1/delete-user-account" "$tmp_dir/purge.json" "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY" "$purge_body")
assert_status "expired A final purge succeeds" "$code" 200
code=$(request GET "$API_URL/auth/v1/admin/users/$user_a" "$tmp_dir/a-auth-after-purge.json" "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY")
assert_status "A Auth record is gone after final purge" "$code" 404
code=$(request GET "$API_URL/rest/v1/users?id=eq.$user_a&select=id" "$tmp_dir/a-db-after-purge.json" "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY")
assert_status "query A database rows after final purge" "$code" 200
assert_json_length "A application rows are gone after final purge" "$tmp_dir/a-db-after-purge.json" 0
code=$(request GET "$API_URL/rest/v1/users?id=eq.$user_b&select=id" "$tmp_dir/b-db-after-purge.json" "$SERVICE_ROLE_KEY" "$SERVICE_ROLE_KEY")
assert_status "query B database rows after A final purge" "$code" 200
assert_json_length "B application row survives A final purge" "$tmp_dir/b-db-after-purge.json" 1
code=$(request GET "$API_URL/rest/v1/words?select=id&limit=100" "$tmp_dir/official-after-purge.json" "$ANON_KEY" "$token_b")
assert_status "B reads official content after A final purge" "$code" 200
[ "$(jq 'length' "$tmp_dir/official-after-purge.json")" = "$official_before" ] || fail "official content changed after A final purge"

printf '\nUSL-261 local E2E passed: RLS A/B/anonymous, recovery request, email-change request, reauthentication, withdrawal, 365-day retention boundary, final purge, and B/official-content isolation.\n'
printf 'Environment: project_id=%s API=local synthetic_accounts=2 production_changes=0\n' "$project_id"
