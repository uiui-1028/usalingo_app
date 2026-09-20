#!/usr/bin/env bash
# 同梱デッキ（decks.is_starter の公式デッキ）を本番から書き出し、
# apps/ios-swiftui/UsalingoIOS/Resources/StarterDeck.json を作り直す。
#
# 出す形はアプリがサーバーから読むときと同じ（StudyCardRecord の配列）。
# 教材を更新したら、このスクリプトを流してから commit する。
set -euo pipefail

PROJECT_REF="udvmzaodsrgwecfybkry"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/apps/ios-swiftui/UsalingoIOS/Resources/StarterDeck.json"

supabase db query \
  --file "$ROOT/scripts/sql/export-starter-deck.sql" \
  --linked --project-ref "$PROJECT_REF" --workdir "$ROOT" \
  | jq -c '.rows[0].payload' > "$OUTPUT.tmp"

# デッキとカードが取れたときだけ差し替える。空の応答で同梱デッキを消さない。
jq -e '.deck.id and (.cards | length > 0)' "$OUTPUT.tmp" > /dev/null
mv "$OUTPUT.tmp" "$OUTPUT"
echo "wrote $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
