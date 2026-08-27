# ローカルSupabaseの再現手順

この手順はDocker内の127.0.0.1だけで動きます。本番project ref、認証情報、利用者データは使いません。

## 必要なもの

- Docker Desktop
- Supabase CLI
- リポジトリのルートでコマンドを実行すること

バージョンとDocker接続を先に確認します。

    docker version
    supabase --version
    docker system df

## DBテスト（通常はこちら）

    ./scripts/test-local-db.sh

このスクリプトはPostgresだけを起動し、Storage、Studio、Realtime、Edge Runtimeなどを除外します。画像・音声ファイルは取得・保存せず、Storageについてはbucketとパス制約のメタデータだけを検査します。`db reset --local`はローカルDBだけを作り直し、migrationを順番に適用してから`supabase/seed.sql`のテストデータを入れます。

Dockerの「Images」は画像アセットではなく、Postgresなどを動かすプログラム一式です。初回にはPostgresイメージとpgTAP実行用イメージのダウンロードが必要ですが、画像・音声コンテンツではありません。

## Auth/APIの統合確認が必要な場合だけ

DBテスト用スクリプトとは別に、Auth/APIの確認時は次を使います。Storageの実ファイルを使うテストは行いません。

    supabase stop
    supabase start
    supabase status

`supabase status`のAPI、DB、Mailpitなどは127.0.0.1のURL・接続先であることを確認します。

## 停止・再起動・完全再作成

DBテスト環境を止める場合:

    supabase stop

もう一度DBテストする場合:

    ./scripts/test-local-db.sh

スクリプトは毎回`db reset --local`を実行し、空のDBからmigrationとテスト用seedを再現します。

ローカルDocker volumeも消して完全に作り直す場合だけ、次を使います。このコマンドはusalingo-localのローカルDBデータを削除します。

    supabase stop --no-backup
    ./scripts/test-local-db.sh

## 容量を安全に確認する

    docker system df

まず上の結果を確認します。Usalingoのローカルデータだけを消すならsupabase stop --no-backupを使います。ほかのDockerプロジェクトも消し得るdocker system pruneは、この手順では実行しません。

## 本番へ触れないための禁止事項

- supabase linkを実行しない
- supabase db pushを実行しない
- --linkedを付けない
- 本番project ref、API key、DB URL、データを設定・コピーしない

## 再現される主な対象

- Auth（統合確認時のみサービスを起動。DB schemaは常に検査）
- words、word_meanings、example_contents
- decks、deck_words
- card_templates、cards、user_card_progress
- users、user_profiles、user_word_tags、user_word_overrides
- RLS、Data API GRANT、Storage bucket、MIME制限（実ファイルは0件）

## 2026-08-22の確認結果

- Docker 29.7.2のClient・Server接続: 成功
- Supabase CLI 2.33.9
- supabase startと127.0.0.1だけのURL表示: 成功
- AuthとStorageのhealth endpoint: 200
- 空DBから全migration、seed、再起動: 成功
- pgTAP: 34件すべて成功
- public schemaのSQL lint: エラー0件
- ローカルAuth signup、ユーザー行作成RPC、user_profilesのRLS往復: 成功
- supabase stop後のseed保持: 1件から1件
- volume削除後の完全再作成: seed 1件を再現
- 再作成後のDocker使用量: image 9.119GB、local volume 74.29MB
- 本番接続、--linked、db push、本番データの使用: 未実施
