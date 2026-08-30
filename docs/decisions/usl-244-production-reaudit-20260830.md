# USL-244 本番Supabase適用停止監査（再監査 2026-08-30）

- 判定: **停止のまま。ただし停止理由が変わった**
- 読み取り時刻: 2026-08-30 16:23〜16:29 UTC
- 対象: Supabase project `udvmzaodsrgwecfybkry`（`Usalingo.app`、`ap-northeast-1`）
- Database: Postgres 17.4.1.064
- 実行境界: Management APIの読み取り、`SELECT`、Security Advisorだけを使用した。
  本番DDL、DML、Storage変更、migration適用、バックアップ作成、branch作成は0件。

[初回監査](usl-244-production-stop-audit.md)（2026-08-23）の再確認である。

## 結論

初回監査が挙げた停止3条件を閉じるmigration
`20260830150000_close_production_only_exposure.sql` は
[USL-224](usl-224-close-production-exposure.md) で `main` にマージ済みである。
本番の該当オブジェクトは初回監査から**一切変化していない**ため、そのmigrationは
記録どおりの対象に、記録どおりに効く。

しかし解除条件4（隔離環境での適用と、Data API・Storageを含む再検証）が
まだ満たされていない。したがって判定は**停止のまま**である。

初回監査の停止理由は「修正する手段が無い」だった。現在の停止理由は
「修正はあるが、Data APIとStorageを通した検証が済んでいない」である。

## 本番の現状（読み取り結果）

修正migrationは本番未適用のため、危険な状態はそのまま残っている。

| 停止条件 | 本番の現在値 | 初回監査からの変化 |
| --- | --- | --- |
| `asset_processing_queue` のRLS | 無効 | 変化なし |
| 同 policy件数 | 0 | 変化なし |
| 同 `anon` の SELECT/INSERT/DELETE | すべて可 | 変化なし |
| `setup_content_images_policies()` の `anon` 実行 | 可 | 変化なし |
| `optimize_content_audio_policies()` の `anon` 実行 | 可 | 変化なし |
| `get_index_recommendations()` / `get_performance_summary()` の `anon` 実行 | 可 | 変化なし |
| `sync_existing_images()` | 存在する | 変化なし（USL-276の削除はリポジトリのみ） |
| 6 viewの `security_invoker=true` | 0件 | 変化なし |
| `anon` のview INSERT | 可 | 変化なし |
| `anon` の監視view SELECT | 可 | 変化なし |

Security Advisor（security）の結果:

| level | 件数 | 内容 |
| --- | ---: | --- |
| ERROR | 7 | `security_definer_view` 6件、`rls_disabled_in_public` 1件（`asset_processing_queue`） |
| WARN | — | 公開実行可能な `SECURITY DEFINER` 関数、`function_search_path_mutable`、Leaked Password Protection無効、Postgresのセキュリティパッチ未適用 |

ERROR 7件は、いずれも `20260830150000` の適用対象そのものである。

`ensure_current_user_row()` もAdvisorのWARNに出るが、これは
`20260411120000` と `20260821133424` で `anon` から取消済み・`authenticated` のみ・
`search_path` 固定であり、意図した公開である。対応不要。

## 移行元データ（初回監査からの再確認）

| 項目 | 現在値 | 初回監査 | 判定 |
| --- | ---: | ---: | --- |
| `words` | 1,000 | 1,000 | 合格 |
| `word_meanings` | 1,000 | 1,000 | 合格 |
| `example_contents` | 1,000 | 1,000 | 合格 |
| `decks` | 1 | 1 | 合格 |
| `deck_words` | 1,000 | 1,000 | 合格 |
| `card_templates` | 0 | 0 | 合格 |
| `user_learning_progress` | 88 | 88 | 合格 |
| `cards` | 未作成 | 未作成 | 合格（適用前の期待状態） |
| `user_card_progress` | 未作成 | 未作成 | 合格（適用前の期待状態） |
| 孤児の `deck_words` | 0 | 0 | 合格 |
| 未知の `word_id` を持つ旧進捗 | 0 | 0 | 合格 |
| `image_asset_path` のNULL | 0 | 0 | 合格 |
| `audio_asset_path` のNULL | 0 | 0 | 合格 |

migration履歴は41件で、対象の
`20260810065120_create_anki_cards_and_migrate_progress` と
`20260812055432_define_official_content_contract`、および
`20260830150000_close_production_only_exposure` はいずれも本番未適用である。

## Storage policyの件数について（初回監査の記述の補足）

初回監査は「既存Storage policyはmigrationが認識する8件だけで、未知のpolicyは0件」と
書いている。今回 `storage.objects` のpolicyを数えると **22件** あり、一見矛盾する。

内訳を読むと矛盾ではない。8件は対象bucketの
`content_images_*`（4件）と `content_audio_*`（4件）であり、初回監査の「8件」は
**対象bucketに限った数**である。残る14件は別bucketのものである。

| bucket | policy数 |
| --- | ---: |
| `content-images` | 4 |
| `content-audio` | 4 |
| `illustrations` | 4 |
| `user-uploads` | 4 |
| `asset-inbox` | 3 |
| `public` | 3 |

対象bucketの8件は初回監査の記述と一致し、新規・未知のpolicyは0件である。
初回監査の「8件」という表現は範囲が読み取りにくいため、この再監査で明示しておく。

## 停止条件（再判定）

| 条件 | 判定 | 根拠 |
| --- | --- | --- |
| 進捗に対応先Cardがない | 合格 | 0件 |
| 無効な外部キー | 合格 | 0件 |
| 想定外の重複・NULL・状態値 | 合格 | 0件 |
| 不正なメディアパス | 合格 | NULL 0件 |
| 未知のStorage policy | 合格 | 対象bucketは既知の8件のみ |
| migration履歴 | 合格 | 対象3件はいずれも未適用 |
| policy変更用管理関数の公開 | 停止解消の見込みあり | `20260830150000` が `EXECUTE` を取り消す。本番は未適用 |
| 公開queueのRLS・GRANT | 停止解消の見込みあり | `20260830150000` がRLS有効化とGRANT取消を行う。本番は未適用 |
| SECURITY DEFINER view | 停止解消の見込みあり | `20260830150000` が6件を `security_invoker=true` にする。本番は未適用 |
| **隔離環境での検証** | **停止** | Data APIとStorageを通した実挙動の検証が未実施 |

## 残る停止条件について

USL-224 でローカル検証は行ったが、いずれも range が足りない。

- `scripts/test-sql-without-docker.sh`（クラウド開発セッション）: `auth.uid()` が常にNULLで、
  PostgREST・Storageも無い。カタログ上の形だけを確認した。
- `scripts/test-local-db.sh`（人間のMacで実行、合格）: Postgresだけを起動し、
  `gotrue`・`postgrest`・`storage-api` などを明示的に除外している。
  したがってRLSの定義とpgTAPは通ったが、**Data API経由の実際の遮断とStorageの実挙動は
  依然として未確認**である。

初回監査の解除条件4は「USL-243相当のRLS・Data API・Storageテスト」を求めている。
これを満たすには、次のどちらかが必要である。

1. 人間のMacで、除外なしの `supabase start` を使ったフルスタック検証
   （`docs/operations/supabase-local-development.md` の「Auth/APIの統合確認」と
   `scripts/test-local-account-e2e.sh`）。費用は発生しない。
2. Supabase branch を作って本番同等の隔離環境で検証する。
   branch作成は課金対象であり、人間の明示承認が必要である。

## 次の順序

1. 上の1または2で、Data APIとStorageを含む検証を通す。
2. USL-244 を合格へ変える。
3. USL-245 の本番適用。対象project・migration・バックアップ・切り戻し方法を提示した上で、
   人間の明示承認を得てから実行する。適用対象は
   `20260830150000`、`20260810065120`、`20260812055432` を含む未適用migrationである。
   セキュリティを先に閉じる観点では、`20260830150000` を先頭に適用する。
4. USL-246 のテスト利用者による本番回答保存。さらに別の明示承認が必要である。

## 根拠SQL

本番では次の読み取り専用の集計だけを実行した。結果は上の表へ転記した。

```sql
-- 停止条件の現在値
select
  (select relrowsecurity from pg_class where oid = 'public.asset_processing_queue'::regclass),
  (select count(*) from pg_policies where schemaname='public' and tablename='asset_processing_queue'),
  has_table_privilege('anon','public.asset_processing_queue','select'),
  has_function_privilege('anon','public.setup_content_images_policies()','execute'),
  to_regprocedure('public.sync_existing_images()') is not null,
  (select count(*) from pg_class c
     where c.relkind='v' and c.relnamespace='public'::regnamespace
       and 'security_invoker=true' = any(coalesce(c.reloptions, array[]::text[])));

-- 移行元データ、Storage policy
select count(*) from public.words;                       -- 他のtableも同様
select policyname, cmd, roles from pg_policies
 where schemaname='storage' and tablename='objects';
```

このほか Management API の `list_projects`、`list_migrations`、
Security Advisor（security）を読み取った。
