# 📚 Supabase リファレンス

このディレクトリには、現在使用中のSupabase関連ファイルが整理されています。

## 📂 ディレクトリ構成

### `sql/`
データベース関連のSQLファイル
- `core/` - コアスキーマ（テーブル、インデックス、RLS）
- `features/` - 機能別SQL（トリガー、タイムスタンプ、検索、ストレージ）
- `maintenance/` - メンテナンス用SQL
- `setup/` - セットアップ用SQL

### `execution-guides/`
SQL実行手順書
- 各機能のデプロイ手順
- トラブルシューティングガイド
- ベストプラクティス

### `functions/`
Edge Functions
- アセットリンカー
- 移行スクリプト
- ユーティリティ関数

### `types/`
TypeScript型定義
- JSONB構造の型定義
- データベーススキーマの型定義

## 🚀 使用方法

### SQLファイルの実行順序
1. `sql/setup/setup_database.sql` - 初期セットアップ
2. `sql/core/` - コアスキーマの構築
3. `sql/features/` - 機能の追加
4. `sql/maintenance/` - 必要に応じてメンテナンス

### Edge Functionsのデプロイ
1. `functions/`内の関数を確認
2. Supabaseダッシュボードでデプロイ
3. 動作確認

## 📋 クイックリファレンス

### よく使用するSQL
- **データベース初期化**: `sql/setup/setup_database.sql`
- **スキーマ構築**: `sql/core/01_schema.sql`
- **インデックス作成**: `sql/core/02_indexes.sql`
- **RLS設定**: `sql/core/03_rls.sql`

### よく使用する機能
- **トリガー**: `sql/features/triggers/04_media_trigger.sql`
- **タイムスタンプ**: `sql/features/timestamps/06_add_timestamps.sql`
- **全文検索**: `sql/features/search/08_fulltext_search.sql`
- **ストレージ**: `sql/features/storage/10_storage_hierarchy.sql`
