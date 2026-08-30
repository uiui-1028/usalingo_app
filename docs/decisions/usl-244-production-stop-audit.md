# USL-244 本番Supabase適用停止監査

- 判定: **停止**
- 読み取り時刻: 2026-08-23 04:06:01 UTC（2026-08-23 13:06:01 JST）
- 対象: Supabase project `udvmzaodsrgwecfybkry`（`Usalingo.app`、`ap-northeast-1`）
- Database: Postgres 17.4（Management API表示: 17.4.1.064）
- 対象migration:
  - `20260810065120_create_anki_cards_and_migrate_progress.sql`
  - `20260812055432_define_official_content_contract.sql`
- 実行境界: Supabase Management APIの読み取り、`SELECT`、Security Advisorだけを使用した。本番DDL、DML、Storage変更、migration適用、バックアップ作成は0件。

## 結論

Card移行元データとメディア参照は、migration内の事前停止条件をすべて満たしている。しかし、対象migrationが解消しない既存の公開権限があるため、現状のまま本番適用へ進めない。

特に `public.optimize_content_audio_policies()` と `public.setup_content_images_policies()` は `SECURITY DEFINER` で、`anon` と `authenticated` が実行できる。両関数は `storage.objects` のpolicyを削除・再作成し、対象migrationが削除するクライアント書込policyを適用後に復活できる。先に関数の削除・移動・`EXECUTE` 取消をmigrationへ含め、隔離環境で再検証する必要がある。

## 件数と移行元データ

| 項目 | 現在値 | 判定 |
|---|---:|---|
| `words` | 1,000 | 合格 |
| `word_meanings` | 1,000 | 合格 |
| `example_contents` | 1,000 | 合格 |
| `decks` | 1 | 合格 |
| `deck_words` | 1,000 | 合格 |
| `card_templates` | 0 | 合格 |
| `cards` | 未作成 | 合格（適用前の期待状態） |
| `user_learning_progress` | 88 | 合格 |
| `user_card_progress` | 未作成 | 合格（適用前の期待状態） |
| 進捗状態 | `learning` 50、`review` 38 | 合格 |

次はすべて0件だった。

- 孤児の `deck_words`
- 未知の `word_id` を持つ旧進捗
- 対応Deckがない旧進捗
- 不正な進捗状態・NULL・範囲違反
- 重複した `deck_id + word_id`
- 複数Deckに所属する単語
- 重複した `user_id + word_id` 進捗
- 空の `word_text`、空の `definition_jp`
- 未検証の制約

移行直後の期待値は、Card 1,000件、Card進捗88件である。

## DB・RLS・GRANT

| 対象 | RLS | `anon` GRANT | `authenticated` GRANT | 現在のpolicy |
|---|---|---|---|---|
| `words` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `word_meanings` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `example_contents` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `decks` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `deck_words` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `card_templates` | 有効 | 全table権限 | 全table権限 | SELECT許可、書込3操作を拒否 |
| `user_learning_progress` | 有効 | 全table権限 | 全table権限 | `auth.uid() = user_id` のALL policy |
| `cards` | 未作成 | なし | なし | なし |
| `user_card_progress` | 未作成 | なし | なし | なし |

`card_templates` の旧policyと広いGRANTはAnki migrationで置換される。`words`、`word_meanings`、`example_contents`、`decks`、`deck_words` の旧policyと広いGRANTは公式コンテンツmigrationで置換される。

## Storageとメディアパス

| 項目 | 現在値 | 判定 |
|---|---:|---|
| image path 非NULL / 形式適合 / 不適合 | 1,000 / 1,000 / 0 | 合格 |
| audio path 非NULL / 形式適合 / 不適合 | 1,000 / 1,000 / 0 | 合格 |
| DB参照先がないimage object | 0 | 合格 |
| DB参照先がないaudio object | 0 | 合格 |
| `content-images` object | 1,001 | 記録 |
| `content-audio` object | 2,000 | 記録 |

bucketはいずれもpublic。現在のMIME設定は次のとおりで、対象migrationが期待値へ更新する設計になっている。

- `content-images`: `image/webp`, `image/png`, `image/jpeg`（期待は `image/webp` のみ）
- `content-audio`: 制限なし（期待は `audio/mpeg` のみ）

既存Storage policyはmigrationが認識する8件だけで、未知のpolicyは0件。ただし、認証利用者の個人フォルダへのINSERT・UPDATE・DELETEを許す旧policyが現在は有効である。

## 停止条件

| 条件 | 判定 | 根拠 |
|---|---|---|
| 進捗に対応先Cardがない | 合格 | 対応Deckなし0件 |
| 無効な外部キー | 合格 | `deck_words`・旧進捗の孤児0件 |
| 想定外の重複・NULL・状態値 | 合格 | 全停止集計0件 |
| 不正なメディアパス・欠落object | 合格 | path不適合0件、参照先欠落0件 |
| 未知のStorage policy | 合格 | migration既知の8件のみ |
| migration履歴 | 合格 | ローカル先行5件と同名の本番履歴を確認。対象2件は未適用 |
| policy変更用管理関数の公開 | **停止** | 2関数が`SECURITY DEFINER`かつ`anon`/`authenticated`実行可。対象migrationは処理しない |
| 公開queueのRLS・GRANT | **停止** | `asset_processing_queue`はRLS無効で、`anon`/`authenticated`にSELECT/INSERT/UPDATE/DELETEあり。対象migrationは処理しない |
| SECURITY DEFINER view | **停止** | Advisorが6 viewをERROR。すべて`security_invoker=false`かつ`anon`/`authenticated`がSELECT可。対象migrationは処理しない |

停止対象のviewは `v_word_meanings_with_paths`、`v_example_contents_with_paths`、`v_index_usage_stats`、`v_database_size_monitoring`、`v_table_stats_monitoring`、`v_index_monitoring`。このほかSecurity Advisorは、公開実行可能な `SECURITY DEFINER` 関数として `ensure_current_user_row`、`get_index_recommendations`、`get_performance_summary`、`sync_existing_images` も報告した。今回の直接的な停止根拠は、Storage policyを再作成できる2関数である。

## 解除条件

1. 公開のpolicy変更関数を、削除、非公開schemaへの移動、または必要role以外からの`EXECUTE`取消で閉じるmigrationを作る。
2. `asset_processing_queue` の利用者と必要操作を決め、RLSと最小GRANTを同じmigrationで定義する。
3. 6つのviewを `security_invoker=true` にするか、公開不要なviewのapp role権限を取り消す。
4. 上記を対象2migrationと同じ隔離Supabaseへ適用し、USL-243相当のRLS・Data API・StorageテストとSecurity Advisorを再実行する。
5. 合格後に本番を再度読み取り監査する。USL-245の本番適用は、その後も人間の明示承認が必要。

### 解除条件の進捗（2026-08-30 追記）

1〜3は `supabase/migrations/20260830150000_close_production_only_exposure.sql` で実装し、
ローカルの使い捨てPostgreSQLでmigration・pgTAP・lintが通っている。
判断の記録は [USL-224](usl-224-close-production-exposure.md) を参照。
4（隔離Supabaseでの再検証）と5（本番の再読み取り監査）は未実施であり、
この監査の判定は**停止のまま**である。

2026-08-30 に本番を読み取りで再確認した。結果と再判定は
[USL-244 再監査（2026-08-30）](usl-244-production-reaudit-20260830.md) を参照。
本番の該当オブジェクトはこの監査から変化しておらず、移行元データもすべて合格のままである。
残る停止条件は、Data APIとStorageを通した隔離環境での検証1件になった。

## 根拠SQL

本番では次のような読み取り専用集計だけを実行した。結果は上の表へ転記した。

```sql
select
  clock_timestamp() as read_at_utc,
  (select count(*) from public.words) as words,
  (select count(*) from public.word_meanings) as word_meanings,
  (select count(*) from public.example_contents) as example_contents,
  (select count(*) from public.decks) as decks,
  (select count(*) from public.deck_words) as deck_words,
  (select count(*) from public.card_templates) as card_templates,
  (select count(*) from public.user_learning_progress) as legacy_progress,
  to_regclass('public.cards') as cards,
  to_regclass('public.user_card_progress') as user_card_progress;
```

```sql
select
  count(*) filter (where d.id is null or w.id is null) as orphan_deck_words
from public.deck_words dw
left join public.decks d on d.id = dw.deck_id
left join public.words w on w.id = dw.word_id;

select count(*) as invalid_progress_rows
from public.user_learning_progress p
where p.status is null
   or p.status not in ('learning', 'review', 'mastered')
   or p.next_review_date is null
   or p.srs_level not between 1 and 5
   or p.easiness_factor < 1.3
   or p.repetitions < 0
   or p.incorrect_count < 0
   or p.interval_days < 0
   or p.created_at is null
   or p.updated_at is null;
```

```sql
select
  p.proname,
  p.prosecdef as security_definer,
  has_function_privilege('anon', p.oid, 'execute') as anon_execute,
  has_function_privilege('authenticated', p.oid, 'execute') as authenticated_execute
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in (
    'optimize_content_audio_policies',
    'setup_content_images_policies'
  );
```

```sql
select
  c.relname,
  c.relrowsecurity,
  has_table_privilege('anon', c.oid, 'select,insert,update,delete') as anon_all_dml,
  has_table_privilege('authenticated', c.oid, 'select,insert,update,delete') as authenticated_all_dml
from pg_class c
where c.oid = 'public.asset_processing_queue'::regclass;
```

## 未実施

- 本番migration適用
- 本番DDL・DML・Storage変更
- 本番バックアップ作成
- 本番Data APIでの利用者A・B・匿名E2E
- 停止条件を直すmigrationの作成・適用

## AIレビュー判定

- 判定: **blocked（停止）**
- 受け入れ条件: project ref、時刻、件数、整合性、RLS、GRANT、関数権限、bucket、policy、MIME、パス、SQL、未確認事項を記録した。
- 安全境界: 本番への書き込み・migration適用は0件。
- 残る危険: 公開管理関数、RLS無効queue、SECURITY DEFINER viewを対象migrationが解消しない。
