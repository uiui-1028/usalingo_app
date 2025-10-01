# Usalingo Supabaseスキーマ再構築手順書

## 概要
この手順書は、UsalingoプロジェクトのSupabaseデータベーススキーマを最新の要件定義書に基づいて安全に再構築するためのガイドです。

## ⚠️ 重要な注意事項

**本番環境で実行する前には、必ずデータベースのバックアップを取得してください。**

データベースの変更は元に戻せないため、以下の手順を実行する前に必ずバックアップを作成することを強く推奨します。

## 前提条件

- Supabaseプロジェクトへの管理者アクセス権限
- Supabase SQL Editorへのアクセス権限
- 既存のコンテンツ関連テーブルが存在すること（削除対象）

## 実行手順

### 1. バックアップの作成

1. Supabaseダッシュボードにログイン
2. プロジェクトの「Database」セクションに移動
3. 「Backups」タブを選択
4. 「Create backup」をクリックしてバックアップを作成

### 2. SQLスクリプトの実行

以下の順序で、Supabase SQL Editorで各SQLスクリプトを実行してください：

#### ステップ1: クリーンアップ実行
1. Supabaseダッシュボードの「SQL Editor」に移動
2. `00_cleanup.sql` の内容をコピーして貼り付け
3. 「Run」ボタンをクリックして実行
4. 実行結果で「Cleanup completed successfully」メッセージが表示されることを確認

#### ステップ2: スキーマ作成
1. `01_schema.sql` の内容をコピーして貼り付け
2. 「Run」ボタンをクリックして実行
3. 実行結果で「Schema creation completed successfully」メッセージが表示されることを確認

#### ステップ3: インデックス作成
1. `02_indexes.sql` の内容をコピーして貼り付け
2. 「Run」ボタンをクリックして実行
3. 実行結果で「Indexes creation completed successfully」メッセージが表示されることを確認

#### ステップ4: RLSポリシー設定
1. `03_rls.sql` の内容をコピーして貼り付け
2. 「Run」ボタンをクリックして実行
3. 実行結果で「RLS policies setup completed successfully」メッセージが表示されることを確認

### 3. 実行後の確認

#### テーブル構造の確認
以下のクエリを実行して、テーブルが正しく作成されていることを確認してください：

```sql
-- 作成されたテーブル一覧の確認
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('words', 'word_meanings', 'example_contents', 'decks', 'deck_words', 'card_templates')
ORDER BY table_name;
```

#### インデックスの確認
```sql
-- 作成されたインデックス一覧の確認
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('words', 'word_meanings', 'example_contents', 'decks', 'deck_words', 'card_templates')
ORDER BY tablename, indexname;
```

#### RLSポリシーの確認
```sql
-- RLSが有効になっているテーブルの確認
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('words', 'word_meanings', 'example_contents', 'decks', 'deck_words', 'card_templates')
ORDER BY tablename;
```

## トラブルシューティング

### よくあるエラーと対処法

#### 1. 外部キー制約エラー
**エラー:** `ERROR: cannot drop table because other objects depend on it`
**対処法:** 依存関係のあるテーブルから先に削除する必要があります。`00_cleanup.sql` の順序を確認してください。

#### 2. 権限エラー
**エラー:** `ERROR: permission denied for table`
**対処法:** Supabaseプロジェクトの管理者権限でログインしていることを確認してください。

#### 3. テーブルが存在しないエラー
**エラー:** `ERROR: relation "table_name" does not exist`
**対処法:** 既存のテーブル名を確認し、`00_cleanup.sql` で正しいテーブル名を指定しているか確認してください。

## ロールバック手順

万が一問題が発生した場合は、以下の手順でロールバックしてください：

1. Supabaseダッシュボードの「Database」セクションに移動
2. 「Backups」タブを選択
3. 作成したバックアップを選択
4. 「Restore」をクリックしてバックアップから復元

## 次のステップ

スキーマ再構築が完了したら、以下の作業を実行してください：

1. **テストデータの投入**: 開発用のサンプルデータを投入
2. **アプリケーションの動作確認**: 既存のアプリケーションが新しいスキーマで正常に動作することを確認
3. **パフォーマンステスト**: インデックスが適切に機能していることを確認

## サポート

問題が発生した場合は、以下の情報と共に開発チームに連絡してください：

- 実行したSQLスクリプト名
- エラーメッセージの全文
- 実行時の環境情報（開発環境/本番環境）
- バックアップの有無

---

**最終更新日:** 2025年1月8日  
**バージョン:** 1.0  
**作成者:** Usalingo開発チーム
