# 本番マイグレーション履歴のずれを直す

決定日: 2026-09-04

対象: 本番Supabase `Usalingo.app`（`udvmzaodsrgwecfybkry`）の
`supabase_migrations.schema_migrations`

## 何が起きていたか

`supabase migration list --linked` が、手元と本番で食い違った状態を示していた。
2026-08-28 のバックアップ表を適用しようとして初めて表面化した。

| 種類 | 件数 | 中身 |
|---|---|---|
| 本番だけ | 36 | 2025年。SQL Editorから直接作られ、リポジトリに対応ファイルが無い |
| 本番だけ | 5 | 2026年。**リポジトリの5本と同じ内容が別バージョン番号で二重記録** |
| 手元だけ | 8 | リポジトリにあるが本番の履歴に無い |

手元だけの8本のうち7本は、**本番に実体があるのに履歴だけが欠けていた**。
CLIが採番したバージョン（例 `20260411060312`）とリポジトリのファイル名
（`20260411120000`）が別物として数えられていたためである。

## やったこと

SQLは一切実行していない。履歴表の記録だけを実態に合わせた。

1. **7本を「適用済み」として記録。** 実体があることを本番で確認してから行った。

   | バージョン | 確認した実体 |
   |---|---|
   | `20260411000000` | `public.users` |
   | `20260411120000` | `public.ensure_current_user_row()` |
   | `20260411130000` | `example_contents` 50件すべてに asset path |
   | `20260618190500` | `public.user_word_tags` |
   | `20260618195500` | `public.user_word_overrides` |
   | `20260627000100` | `user_learning_progress.incorrect_count` |
   | `20260830090000` | `public.asset_processing_queue` |

2. **二重記録の5本を削除。** 名前が完全一致する重複であり、
   リポジトリ側のバージョンを残した。

   `20260411060312` `20260411102909` `20260618105058` `20260618105737` `20260627112023`

3. `20260828060000` の適用時に自動採番された `20260904094003` を、
   リポジトリのファイル名へ書き換えた。

結果、2026年分は**15本すべてが手元と本番で揃った**。

4. **`20260821133424_enforce_current_app_grants` を本番へ適用した。**
   これは記録のずれではなく本当に未適用だったため、履歴だけ直さず実際に流した。

   | | 適用前 | 適用後 |
   |---|---|---|
   | `anon` の select（3表） | 可 | **不可** |
   | `authenticated` の `user_profiles` | 全操作可 | select / insert / update |
   | `authenticated` の `user_word_tags` | 全操作可 | select / insert / delete |
   | `authenticated` の `user_word_overrides` | 全操作可 | select / insert / update |
   | `ensure_current_user_row()` | `search_path=public`・anon実行可 | `search_path=''`・authenticatedのみ |

   適用前に本番の関数定義を確認し、本文が `public.users` / `auth.users` と
   完全修飾されていて `search_path=''` でも壊れないことを確かめてから流した。
   migration内の検証3ブロックもすべて通っている。

   security advisor の指摘が2件解消した
   （`function_search_path_mutable` と `anon_security_definer_function_executable`）。

5. **2025年の36件を履歴から削除した。** SQL Editor時代の記録で、
   リポジトリに対応ファイルが無かったもの。作られたオブジェクトは
   `20260830090000_record_production_only_objects.sql` がリポジトリ側へ写し取っている。

   削除した36件（記録として残す）:

   ```
   20250807025516 create_illustrations_bucket
   20250827021133 add_content_images_upload_policy
   20250827021146 create_storage_trigger_function
   20250827021153 create_storage_trigger
   20250827021206 create_sync_existing_images_function
   20250827021210 grant_function_permissions
   20250827022024 fix_storage_trigger_function_variable_conflict
   20250827022035 fix_sync_existing_images_function_variable_conflict
   20250919074051 create_usgs_master_v2_deck
   20250929022552 create_asset_buckets
   20250929022557 setup_storage_policies
   20250929022605 create_media_triggers
   20250929022614 create_asset_linking_functions
   20250929023953 create_asset_migration_functions
   20250929024004 fix_migration_status_function
   20250929024237 modify_asset_path_schema
   20250929024342 update_triggers_for_existing_buckets
   20250930011700 migration_system_setup
   20251002122025 fix_security_definer_views
   20251002122030 enable_rls_schema_migrations
   20251002122042 fix_function_search_path_mutable
   20251002122059 move_pg_trgm_extension_final
   20251002122136 optimize_rls_policies_performance
   20251002122155 remove_unused_indexes_short
   20251002122313 setup_performance_monitoring_simple
   20251002122330 fix_remaining_security_definer_views
   20251002123850 create_storage_policy_helper_function
   20251002123902 optimize_content_audio_policies
   20251005084552 create_optimized_asset_path_functions_v2
   20251005084601 create_performance_indexes
   20251005090232 add_temp_asset_path_for_testing
   20251005094837 update_asset_path_functions_corrected
   20251005094920 recreate_views_corrected_approach
   20251005100040 create_asset_linking_triggers
   20251005100321 create_asset_processing_queue
   20251005100530 create_improved_triggers
   ```

## 結果

`supabase migration list --linked` が**16本すべてで一致**した。手元だけ・本番だけは0件。

## 残っている注意点

`ensure_current_user_row()` は `authenticated` から実行できる（advisorが警告する）。
これはアプリが起動時に自分の行を作るために呼ぶもので、意図した設計である。

## 再発を防ぐには

本番へはSQL Editorから直接DDLを流さず、`supabase/migrations/` のファイル経由で適用する。
