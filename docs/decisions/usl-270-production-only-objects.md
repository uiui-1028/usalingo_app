# USL-270 本番だけにあるDBオブジェクトの記録

確認日: 2026-08-30

## 結論

本番Supabaseから読み取りだけで、リポジトリに存在しなかった19オブジェクトの定義・権限・RLS状態を取得し、
`supabase/migrations/20260830090000_record_production_only_objects.sql` として記録した。
ローカルPostgreSQLで全13migrationを適用し、19オブジェクトが本番と同じ形で再現されることを確認した。

本番へのDDL、DML、設定変更、migration適用は **0件**。読み取りのみ。

## 実行境界

- 対象project: `udvmzaodsrgwecfybkry`（`Usalingo.app` / ap-northeast-1 / Postgres 17.4.1.064）
- 読み取り時刻: 2026-08-30 08:40〜08:47 UTC
- 使用したSQL: `pg_get_functiondef`、`pg_get_viewdef`、`pg_attribute`、`pg_constraint`、
  `pg_indexes`、`information_schema.role_table_grants`、`aclexplode(proacl)`
- 本番への書き込み: なし
- 検証環境: このセッションのコンテナ上に `initdb` で作ったPostgreSQL 16.13
  （Supabase CLIとDockerが使えないため、`auth`・`storage` は最小スタブで代用した）

## 記録した19オブジェクト

### 関数 11本

| 関数 | SECURITY DEFINER | search_path | 備考 |
|---|---|---|---|
| `generate_image_example_filename(int)` | いいえ | 未設定 | viewの依存先 |
| `generate_audio_example_filename(int)` | いいえ | 未設定 | viewの依存先 |
| `generate_audio_meaning_filename(int)` | いいえ | 未設定 | viewの依存先 |
| `get_image_example_asset_path(int)` | いいえ | 未設定 | viewの依存先 |
| `get_audio_example_asset_path(int)` | いいえ | 未設定 | viewの依存先 |
| `get_audio_meaning_asset_path(int)` | いいえ | 未設定 | viewの依存先 |
| `setup_content_images_policies()` | **はい** | public | Storage policyを再作成する |
| `optimize_content_audio_policies()` | **はい** | public | Storage policyを再作成する |
| `sync_existing_images()` | **はい** | public | 現行スキーマに無い列を参照する |
| `get_index_recommendations()` | **はい** | public | 監視用 |
| `get_performance_summary()` | **はい** | public | 監視用 |

USL-270のチケット本文は `ensure_current_user_row` を対象に挙げているが、これは
`20260411120000_ensure_current_user_row.sql` として既にリポジトリにある。本体は本番と一致する。
代わりに、viewが依存する補助関数6本を対象へ加えた。これが無いとviewを作れず、
受け入れ条件「リポジトリのmigrationだけで再現できる」を満たせないためである。

### テーブル 1本

`public.asset_processing_queue`（9列、PK 1、index 3、**RLS無効**）

### view 6本

`v_word_meanings_with_paths`、`v_example_contents_with_paths`、`v_index_usage_stats`、
`v_index_monitoring`、`v_database_size_monitoring`、`v_table_stats_monitoring`

6本とも `reloptions` が未設定、つまり `security_invoker` が付いていない。
実行者ではなく所有者 `postgres` の権限で動く。

## 確認したこと

| 確認 | 方法 | 結果 |
|---|---|---|
| 全migrationが順番に適用できる | ローカルPostgreSQLへ13ファイルを順次 `psql -v ON_ERROR_STOP=1` | 13/13 成功 |
| 関数11本のSECURITY DEFINERとsearch_path | `pg_proc.prosecdef` / `proconfig` を本番と突き合わせ | 11/11 一致 |
| view 6本の定義 | `pg_get_viewdef` を空白正規化して `diff` | 6/6 完全一致 |
| view 6本の `security_invoker` | `pg_class.reloptions` | 6/6 未設定（本番と一致） |
| テーブルの列・型・NOT NULL | `pg_attribute` | 9/9 一致 |
| テーブルのRLS状態 | `pg_class.relrowsecurity` | `false`（本番と一致） |
| テーブルのindex | `pg_indexes` | PK + 3本、本番と一致 |
| GRANT（表・view 7件 × 3ロール） | `information_schema.role_table_grants` | 21/21 一致 |
| GRANT（関数5本 × 3ロール） | `aclexplode(proacl)` | 15/15 一致 |

## 未確認のこと

- **pgTAPテストは実行していない。** 検証環境に `pgtap` 拡張が無い。
  `supabase/tests/*.test.sql` の成否は未確認である。
- **`supabase db reset` は実行していない。** Supabase CLIとDockerが使えないため、
  `psql` による順次適用で代用した。Supabaseの実際の起動順序、`auth`・`storage` の
  本物のスキーマ、Storage policyの動作は再現していない。
- 検証環境はPostgreSQL 16、本番は17。バージョン差による挙動差は確認していない。
- `sync_existing_images` は `example_contents.illustration_url` と
  `words.word_text` 経由の `word_id` を参照するが、現行スキーマにこれらは無い。
  実行すると失敗する可能性が高い。本番のまま写しており、動作確認はしていない。

## この記録は改善ではない

既知の危険を、あえてそのまま再現している。閉じるのは後続の課題である。

1. `asset_processing_queue` はRLS無効で、`anon` に全DML（TRUNCATEを含む）が開いている。
   anonキーはアプリに配布されるため、誰でも読み書きできる。
2. Storage policyを再作成できる `setup_content_images_policies` と
   `optimize_content_audio_policies` を `anon` が実行できる。
3. 監視用の `get_index_recommendations`、`get_performance_summary`、
   および `sync_existing_images` も `anon` が実行できる。
4. view 6本が `security_invoker` 未設定のまま、`anon` にSELECT権限がある。

## 新しく分かったこと（USL-270の想定より広い）

本番の `public` スキーマには **関数が47本** ある。うち **45本がリポジトリのmigrationに存在しない**。
リポジトリにあるのは `ensure_current_user_row` と `update_updated_at_column` の2本だけである。

この課題では、USL-270が対象に挙げた13オブジェクトと、それを再現するために必要な補助関数6本、
合わせて19オブジェクトだけを記録した。残る **28本は未記録のまま** である。

未記録の28本（分類）:

- 検索: `search_all`、`search_words`、`search_meanings`、`search_examples`
- migration管理: `apply_migration`、`rollback_migration`、`get_migration_status`、`check_migration_status`
- アセット紐付け: `check_asset_linking_status`、`manual_asset_linking`、`find_missing_assets`、
  `move_files_to_inbox`、`update_asset_paths_to_existing_buckets`、`get_rename_operations`、
  `handle_storage_upload`、`get_required_storage_folders`、`get_storage_structure_summary`
- パス生成（別系統）: `get_asset_folder_path`、`get_asset_folder_path_500`、
  `get_audio_example_path`、`get_audio_meaning_path`、`get_image_example_path`、
  `get_example_audio_path`、`get_example_illustration_path`、`get_word_audio_path`
- trigger関数: `trigger_asset_linking_corrected`、`trigger_queue_asset_verification`、
  `trigger_set_asset_path_immediate`
- 検証関数: `validate_collocations_structure`、`validate_derivatives_structure`、
  `validate_inflections_structure`、`validate_related_phrases_structure`
- index監視: `find_duplicate_indexes`、`get_index_usage_stats`

`asset_processing_queue` へ書き込む `trigger_queue_asset_verification` が未記録であるため、
このキューを誰が使っているかは、リポジトリだけでは判断できない。

## 次に必要なこと

1. 残る28関数と、それらが張るtriggerを記録する（USL-270と同じやり方の続き）。
2. 上の危険1〜4を閉じるmigrationを作る。`asset_processing_queue` の利用者と必要操作を
   決める必要があり、これは人間の判断を含む。
3. そのうえでUSL-244の本番再監査をやり直す。

## 根拠

- USL-244 監査記録: `docs/decisions/usl-244-production-stop-audit.md`
- 記録したSQL: `supabase/migrations/20260830090000_record_production_only_objects.sql`
