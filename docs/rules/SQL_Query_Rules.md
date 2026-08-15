# Supabase SQL・migration運用

## 正本

- 実行可能なSQLは `supabase/migrations/` に置く。
- 運用案内は `docs/supabase/README.md` に置く。
- SQL本文を `docs/` に複製しない。

## 変更手順

1. `git status --short` と既存migrationを確認する。
2. 現在のSupabase CLIヘルプで作成コマンドと命名を確認する。
3. 新しいmigrationを `supabase/migrations/` に作る。
4. 既存データ、外部キー、RLS、GRANT、Storage policyへの影響を確認する。
5. ローカルまたは検証環境でSQLとアプリの対象フローをテストする。
6. 本番適用前に対象プロジェクトと差分を確認し、適用後に再検証する。

## 安全ルール

- 既存データを確認せずに削除・上書きしない。
- `public`などData APIへ公開されるschemaでは、GRANTとRLSを別々に確認する。
- 利用者データは本人の行だけを操作できるpolicyにする。
- `service_role`や秘密鍵をiOSアプリ、文書、Gitへ入れない。
- 本番DB変更、Storage削除、データ削除は実行直前に承認を得る。
- 実装済み、検証環境で確認済み、本番適用済みを区別して記録する。

## 現在の構造

- 公式コンテンツ: `words`、`word_meanings`、`example_contents`
- Card Type: `card_templates`
- 学習単位: `cards`
- Card単位の進捗: `user_card_progress`
- 詳細: `docs/architecture/anki-data-model.md`

古い `user_learning_progress.word_id` は移行元です。旧表を削除する時期は、本番移行と切り戻し条件を確認してから別途決めます。
