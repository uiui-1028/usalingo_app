# Dockerなしでmigrationとテストを検証する

最終更新: 2026-08-30

Dockerが使えない環境で、migration、pgTAP、lintの回帰を止めないための逃げ道です。

**通常は [ローカルSupabaseの再現手順](supabase-local-development.md) を使います。**
この文書は、Docker Desktopが動かない場所（CIのコンテナ、クラウド上の開発セッションなど）で
それでもSQLを検証したいときだけ読みます。

## 使い方

    sh scripts/test-sql-without-docker.sh

必要なものが入っていれば、これだけで終わります。本番へは接続しません。
使い捨てのPostgreSQLクラスタを一時ディレクトリへ作り、終了時に消します。

## 必要なもの

Debian / Ubuntu の場合:

    apt-get install -y postgresql-16 postgresql-16-pgtap postgresql-16-plpgsql-check
    npm install supabase          # lintを回す場合だけ

`supabase` コマンドが無ければ、lintは自動で飛ばしてpgTAPまで実行します。
`plpgsql_check` が無い場合も同じくlintだけ飛ばします。

macOS の場合は Docker Desktop が使えるはずなので、この手順ではなく
[ローカルSupabaseの再現手順](supabase-local-development.md) を使ってください。

## 何をしているか

| 手順 | 内容 |
| --- | --- |
| 1 | 使い捨てPostgreSQLクラスタを `initdb` で作る |
| 2 | `scripts/sql/supabase-stubs.sql` でSupabase相当の最小スタブを入れる |
| 3 | `supabase/migrations/*.sql` を名前順に全部適用する |
| 4 | `supabase/seed.sql` を入れる |
| 5 | `supabase/tests/*.test.sql` のpgTAPを実行する |
| 6 | pgTAPを入れていない別DBに対して `supabase db lint --fail-on error` を実行する |
| 7 | クラスタを止めて消す |

手順6でDBを分けているのは、pgTAP自身の関数が `plpgsql_check` に大量の警告を出し、
本物の指摘が埋もれるためです。

## 環境変数

| 変数 | 既定 | 用途 |
| --- | --- | --- |
| `PG_MAJOR` | `16` | PostgreSQLのメジャーバージョン |
| `PG_PORT` | `55432` | 使い捨てクラスタのポート |
| `PG_RUN_AS` | `usalingo-pg` | rootで実行するときにpostgresを動かすユーザー。無ければ作る |
| `SUPABASE` | PATHから探す | `supabase` コマンドのパス |

`postgres` はrootでは起動しません。rootで実行した場合だけ、専用ユーザーへ委譲します。

## この方法で確認できないこと

スタブは本物のSupabaseではありません。次は**確認できません**。

- 認証の実挙動。`auth.uid()` は常に `NULL` を返すため、RLSの「自分の行だけ」は実際には効かない
- PostgREST、Realtime、Edge Runtime、Storageの実挙動
- 本物のSupabaseの起動順序と拡張構成
- 本番と同じPostgreSQLメジャーバージョン（本番は17、この手順の既定は16）

つまり確認できるのは「SQLが構文として通り、カタログ上のオブジェクトが期待どおりの形になるか」までです。
RLSやStorageの**実際の遮断**を確かめるには、Dockerのある環境で
`./scripts/test-local-db.sh` を回してください。

`supabase/tests/usl_222_local_environment.test.sql` のように、bucketやpolicyの
**定義**を検査するpgTAPはこの環境でも通ります。通らないのは、実際にアクセスして
拒否されることを確かめる種類の検証です。

## いまの状態（2026-08-30）

| 項目 | 結果 |
| --- | --- |
| migration | 13件すべて適用成功 |
| pgTAP | 54件中 0件失敗 |
| lint | **error 1件**。終了コード1 |

lintのerrorは `public.sync_existing_images` の1件だけです。
これは本番から写した壊れた関数で、[USL-276](https://app.notion.com/p/3ccc3d1f59e8819bb992df9ba515a378)
で扱います。**このスクリプトはUSL-276が片づくまでは終了コード1で終わります。**
隠さずそのまま出しています。

lintを飛ばした場合（`supabase` コマンドが無い場合）は終了コード0で終わります。

## なぜこれが要るのか

USL-270の作業中、Docker Hubのイメージ取得がネットワーク方針で遮断され、
`supabase start` が使えませんでした。そのままではSQLの検証手段がゼロになります。

この手順を用意したことで、Dockerなしでも次が確認できるようになりました。

- migrationが順番に適用できること
- pgTAP 54件が成功すること
- lintが動くこと（そしてUSL-276のバグは、これで初めて見つかりました）

## 関連

- [ローカルSupabaseの再現手順](supabase-local-development.md) — Dockerがある場合の正規手順
- [SQLのルール](sql-rules.md)
- [品質ゲート](release-quality-gate.md)
- `docs/decisions/usl-270-production-only-objects.md` — この検証環境を最初に組んだ記録
