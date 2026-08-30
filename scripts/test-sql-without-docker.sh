#!/bin/sh
set -eu

# Docker が使えない環境で、migration・pgTAP・lint を検証する代替手段です。
#
#   sh scripts/test-sql-without-docker.sh
#
# 通常は ./scripts/test-local-db.sh（Docker + Supabase CLI）を使ってください。
# このスクリプトは、Docker が動かない環境（CI のコンテナ、クラウド上の
# 開発セッションなど）でも SQL の回帰を止めないための逃げ道です。
#
# やること
#   1. 使い捨ての PostgreSQL クラスタを一時ディレクトリへ作る
#   2. Supabase 相当の最小スタブを入れる（scripts/sql/supabase-stubs.sql）
#   3. supabase/migrations/*.sql を名前順に全部適用する
#   4. supabase/seed.sql を入れる
#   5. supabase/tests/*.test.sql の pgTAP を実行する
#   6. supabase db lint を実行する（Supabase CLI があるときだけ）
#   7. クラスタを止めて消す
#
# 本番へは一切接続しません。127.0.0.1 の使い捨て DB だけを使います。
#
# この環境で確認できないこと
#   - 認証、PostgREST、Realtime、Storage の実挙動
#   - 本物の Supabase の起動順序と拡張構成
#   - 本番と同じ PostgreSQL メジャーバージョン（下の PG_MAJOR に依存）
#   これらは Docker のある環境で ./scripts/test-local-db.sh を回して確認します。
#
# 必要なもの（Debian/Ubuntu の例）
#   apt-get install -y postgresql-16 postgresql-16-pgtap postgresql-16-plpgsql-check
#   npm install supabase          # lint を回す場合だけ。無ければ lint は自動で飛ばす
#
# 環境変数
#   PG_MAJOR    PostgreSQL のメジャーバージョン（既定 16）
#   PG_PORT     使い捨てクラスタが listen するポート（既定 55432）
#   PG_RUN_AS   root で実行するときに postgres を動かすユーザー（既定 usalingo-pg）
#   SUPABASE    supabase コマンドのパス（既定は PATH から探し、無ければ lint を飛ばす）

PG_MAJOR="${PG_MAJOR:-16}"
PG_PORT="${PG_PORT:-55432}"
PG_RUN_AS="${PG_RUN_AS:-usalingo-pg}"
PG_BIN="/usr/lib/postgresql/${PG_MAJOR}/bin"
DB_NAME="usalingo_verify"

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

if [ ! -x "$PG_BIN/initdb" ]; then
  echo "PostgreSQL ${PG_MAJOR} のサーバーコマンドが $PG_BIN にありません。" >&2
  echo "  apt-get install -y postgresql-${PG_MAJOR} postgresql-${PG_MAJOR}-pgtap postgresql-${PG_MAJOR}-plpgsql-check" >&2
  exit 1
fi

# postgres は root では起動しないため、root のときだけ専用ユーザーへ委譲します。
if [ "$(id -u)" -eq 0 ]; then
  if ! id "$PG_RUN_AS" >/dev/null 2>&1; then
    echo "root で実行中です。postgres 用のユーザー $PG_RUN_AS を作ります。"
    useradd -m -s /bin/sh "$PG_RUN_AS"
  fi
  run_as_pg() { su "$PG_RUN_AS" -c "$1"; }
  pg_home=$(getent passwd "$PG_RUN_AS" | cut -d: -f6)
else
  run_as_pg() { sh -c "$1"; }
  pg_home="$HOME"
fi

PGDATA="$pg_home/.usalingo-verify-pgdata"
export PGHOST=127.0.0.1
export PGPORT="$PG_PORT"
export PGUSER=postgres
# DROP ... IF EXISTS の NOTICE が数百行出て、本当の失敗が埋もれるため抑えます。
# ERROR と WARNING は残ります。
export PGOPTIONS='-c client_min_messages=warning'

cleanup() {
  run_as_pg "$PG_BIN/pg_ctl -D '$PGDATA' -m immediate stop" >/dev/null 2>&1 || true
  run_as_pg "rm -rf '$PGDATA'" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "== 使い捨てクラスタを作る =="
run_as_pg "rm -rf '$PGDATA'"
run_as_pg "$PG_BIN/initdb -D '$PGDATA' -U postgres --auth=trust" >/dev/null
# -k で unix ソケットをクラスタ内へ置きます。既定の /var/run/postgresql は
# 専用ユーザーに書き込み権が無く、指定しないと起動に失敗します。
run_as_pg "$PG_BIN/pg_ctl -D '$PGDATA' -o '-k $PGDATA -p $PG_PORT -c listen_addresses=127.0.0.1' -l '$PGDATA/log' -w start" >/dev/null
psql -tAc "SELECT 'PostgreSQL ' || current_setting('server_version')"

echo "== Supabase 相当のスタブを入れる =="
psql -q -c "CREATE DATABASE $DB_NAME"
psql -q -d "$DB_NAME" -v ON_ERROR_STOP=1 -f scripts/sql/supabase-stubs.sql

echo "== migration を名前順に適用する =="
count=0
for f in supabase/migrations/*.sql; do
  psql -q -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$f"
  count=$((count + 1))
  echo "  OK  $(basename "$f")"
done
echo "  $count 件すべて適用しました"

echo "== seed を入れる =="
psql -q -d "$DB_NAME" -v ON_ERROR_STOP=1 -f supabase/seed.sql

echo "== pgTAP を実行する =="
psql -q -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pgtap"
tap_total=0
tap_failed=0
for t in supabase/tests/*.test.sql; do
  out=$(psql -X -q -d "$DB_NAME" -f "$t" 2>&1)
  n=$(printf '%s\n' "$out" | grep -cE '^ (not )?ok ' || true)
  f=$(printf '%s\n' "$out" | grep -cE '^ not ok ' || true)
  tap_total=$((tap_total + n))
  tap_failed=$((tap_failed + f))
  printf '  %-40s %s 件中 %s 件失敗\n' "$(basename "$t")" "$n" "$f"
  [ "$f" -gt 0 ] && printf '%s\n' "$out" | grep -E '^ not ok ' >&2
done
echo "  pgTAP 合計 ${tap_total} 件 / 失敗 ${tap_failed} 件"

echo "== lint を実行する =="
# lint は pgTAP を入れていない DB に対して行います。pgTAP 自身の関数が
# plpgsql_check に大量の警告を出し、本物の指摘が埋もれるためです。
supabase_cmd="${SUPABASE:-}"
if [ -z "$supabase_cmd" ]; then
  if command -v supabase >/dev/null 2>&1; then
    supabase_cmd=supabase
  elif [ -x node_modules/.bin/supabase ]; then
    supabase_cmd=node_modules/.bin/supabase
  fi
fi

lint_status=skipped
if [ -z "$supabase_cmd" ]; then
  echo "  supabase コマンドが無いため飛ばしました（npm install supabase で入ります）"
elif ! psql -q -d "$DB_NAME" -c "SELECT 1 FROM pg_available_extensions WHERE name='plpgsql_check'" -tA | grep -q 1; then
  echo "  plpgsql_check 拡張が無いため飛ばしました" >&2
  echo "  apt-get install -y postgresql-${PG_MAJOR}-plpgsql-check" >&2
else
  psql -q -c "DROP DATABASE IF EXISTS ${DB_NAME}_lint"
  psql -q -c "CREATE DATABASE ${DB_NAME}_lint"
  psql -q -d "${DB_NAME}_lint" -v ON_ERROR_STOP=1 -f scripts/sql/supabase-stubs.sql
  for f in supabase/migrations/*.sql; do
    psql -q -d "${DB_NAME}_lint" -v ON_ERROR_STOP=1 -f "$f"
  done
  if "$supabase_cmd" db lint \
      --db-url "postgresql://postgres@127.0.0.1:${PG_PORT}/${DB_NAME}_lint?sslmode=disable" \
      --schema public --fail-on error; then
    lint_status=ok
  else
    lint_status=failed
  fi
fi

echo
echo "== まとめ =="
echo "  migration : ${count} 件適用"
echo "  pgTAP     : ${tap_total} 件中 ${tap_failed} 件失敗"
echo "  lint      : ${lint_status}"

if [ "$tap_failed" -gt 0 ] || [ "$lint_status" = failed ]; then
  exit 1
fi
