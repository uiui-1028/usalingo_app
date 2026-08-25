# Supabase

Supabase関連は、用途ごとに次の2か所だけを正本とします。

| 場所 | 役割 |
| --- | --- |
| `supabase/migrations/` | データベース変更の実行可能な履歴（SQLの正本） |
| `docs/supabase/README.md` | 運用方針と参照先（このファイル） |

ローカルで空のDBから再現・検証する手順は、[ローカルSupabaseの再現手順](local-development.md) を参照してください。

## 運用ルール

- スキーマ、関数、RLS、インデックスの変更は `supabase/migrations/` に追加する。
- 同じSQLを `docs/` にコピーしない。説明が必要な場合は対象マイグレーションへリンクする。
- 新しいマイグレーション名やCLIオプションは推測せず、`supabase migration new --help` など現在のCLIヘルプで確認する。
- 適用前に変更内容と対象環境を確認し、適用後はテストクエリとアプリの該当フローで検証する。
- `public` などData APIへ公開されるスキーマでは、RLSと必要な権限を明示的に確認する。
- Edge Functionsを運用する場合は、ドキュメント配下ではなく `supabase/functions/<function-name>/` に置く。

Supabase公式の基本フローも、バージョン管理するSQLを `supabase/migrations/` に置く構成です。

- [Local development with schema migrations](https://supabase.com/docs/guides/local-development/overview)
- [Database migrations](https://supabase.com/docs/guides/local-development/database-migrations)

## 現在のマイグレーション

手書きの一覧は持たず、[`supabase/migrations/`](../../supabase/migrations/) を直接参照してください。

## 旧資料について

2025年に作成された統合SQL、移行スクリプト、完了報告、Edge Functionの参考実装は、現行コードから参照されず、存在しないパスや旧命名規則も含んでいたため作業ツリーから除外しました。必要な場合はGit履歴のコミット `4b52c7f`（`Supabase Structure mvp`）から参照できます。旧SQLや旧Functionをそのまま本番実行しないでください。
