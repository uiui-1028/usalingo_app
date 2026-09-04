#!/bin/sh
set -eu

# 依存パッケージのライセンス一覧を生成します。
# 一覧は手で書かず、必ずこのスクリプトの出力をコミットしてください。
# 手書きの一覧は依存を足すたびに古くなり、表示義務を満たせなくなります。
#
#   sh scripts/generate-licenses.sh          生成して Acknowledgements.md を更新する
#   sh scripts/generate-licenses.sh --check  生成結果が現在のコミットと一致するか確かめる
#
# macOS でのみ動きます。LicensePlist は macOS 向けのコマンドです。
# 導入は次のどちらかです。
#
#   brew install licenseplist
#   mint install mono0926/LicensePlist
#
# GitHub API の回数制限に当たる場合は GITHUB_TOKEN を設定してから実行します。

repo_root=$(cd "$(dirname "$0")/.." && pwd)
project_dir="$repo_root/apps/ios-swiftui"
markdown_path="UsalingoIOS/Resources/Licenses/Acknowledgements.md"

check_only=0
if [ "${1:-}" = "--check" ]; then
  check_only=1
fi

if command -v license-plist >/dev/null 2>&1; then
  run_license_plist() { license-plist "$@"; }
elif command -v mint >/dev/null 2>&1; then
  run_license_plist() { mint run mono0926/LicensePlist license-plist "$@"; }
else
  echo "license-plist が見つかりません。brew install licenseplist か mint install mono0926/LicensePlist を実行してください。" >&2
  exit 1
fi

cd "$project_dir"

# LicensePlist は cd した先の *.xcodeproj から Package.resolved を探します。
# Package.resolved が無い場合（依存ゼロ）は空の一覧が生成されます。それが正しい状態です。
#
# --fail-if-missing-license を付けているのは、ライセンス本文を取得できない依存を
# 気づかないまま同梱しないためです。ここで落ちたら license_plist.yml の manual に足します。
run_license_plist \
  --config-path license_plist.yml \
  --markdown-path "$markdown_path" \
  --fail-if-missing-license \
  --force \
  ${GITHUB_TOKEN:+--github-token "$GITHUB_TOKEN"}

# LicensePlist の版によっては末尾に空行を複数出す。内容に意味のない差分を
# コミットへ混ぜないため、最後の改行は1つだけにそろえる。
perl -0pi -e 's/\n+\z/\n/' "$markdown_path"

if [ "$check_only" -eq 1 ]; then
  if ! git -C "$repo_root" diff --exit-code -- "apps/ios-swiftui/$markdown_path"; then
    echo "ライセンス一覧が古いままです。sh scripts/generate-licenses.sh を実行して差分をコミットしてください。" >&2
    exit 1
  fi
  echo "ライセンス一覧は最新です。"
else
  echo "生成しました: apps/ios-swiftui/$markdown_path"
  echo "差分が出た場合は、その差分もコミットしてください。"
fi
