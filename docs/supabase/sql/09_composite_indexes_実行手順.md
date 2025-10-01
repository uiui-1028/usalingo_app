# 📘 複合インデックス 実行手順

## 🎯 このファイルについて

このファイルは `09_composite_indexes.sql` を実行する手順を説明します。

---

## 📍 実行場所

**Supabase SQL Editor** で実行します。

---

## 🚀 実行手順

### 1️⃣ Supabase SQL Editorを開く

1. Supabaseダッシュボードにログイン (https://supabase.com/dashboard)
2. プロジェクトを選択
3. 左側メニューから「**SQL Editor**」をクリック

### 2️⃣ SQLファイルを実行

1. SQL Editorで「**New query**」をクリック
2. `docs/supabase/sql/09_composite_indexes.sql` の内容を全てコピー
3. SQL Editorに貼り付け
4. 「**Run**」ボタンをクリック

### 3️⃣ 実行結果を確認

成功すると以下のメッセージが表示されます：

```
status: "複合インデックスのセットアップが完了しました。"
```

---

## ✅ 動作確認

### 作成されたインデックスの確認

```sql
-- 新しく作成された複合インデックスの一覧
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE '%_word_priority%'
   OR indexname LIKE '%_meaning_theme%'
   OR indexname LIKE '%_user_status%'
   OR indexname LIKE '%_user_next_review%'
   OR indexname LIKE '%_user_srs_level%'
   OR indexname LIKE '%_user_tab_order%'
   OR indexname LIKE '%_text_pattern%'
   OR indexname LIKE '%_covering%'
ORDER BY tablename, indexname;
```

期待される結果：
- `idx_word_meanings_word_priority` - 単語ID + 優先度
- `idx_example_contents_meaning_theme` - 意味ID + テーマ
- `idx_user_learning_progress_user_status` - ユーザーID + ステータス
- `idx_user_learning_progress_user_next_review` - ユーザーID + 次回復習日
- `idx_user_learning_progress_user_srs_level` - ユーザーID + SRSレベル
- `idx_user_widget_layouts_user_tab_order` - ユーザーID + タブ名 + 表示順
- `idx_words_text_pattern` - 単語テキスト（前方一致用）
- `idx_word_meanings_covering` - カバリングインデックス

**合計8個の複合インデックス**が作成されます。

### 管理関数の確認

```sql
-- インデックス管理関数が作成されているか確認
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname IN ('get_index_usage_stats', 'find_duplicate_indexes')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;
```

期待される結果：
- `get_index_usage_stats` - インデックス使用統計取得
- `find_duplicate_indexes` - 冗長インデックス検出

---

## 📊 インデックス使用状況の確認

### インデックス使用統計

```sql
-- インデックスの使用統計を確認
SELECT * FROM get_index_usage_stats()
WHERE indexname LIKE '%word_priority%'
   OR indexname LIKE '%meaning_theme%'
   OR indexname LIKE '%user_status%'
   OR indexname LIKE '%user_next_review%'
   OR indexname LIKE '%user_srs_level%'
   OR indexname LIKE '%user_tab_order%'
   OR indexname LIKE '%text_pattern%'
   OR indexname LIKE '%covering%'
ORDER BY idx_scan DESC;
```

**注意**: 新しく作成したインデックスは、実際のクエリが実行されるまで `idx_scan` が0です。

### 冗長インデックスの確認

```sql
-- 冗長な可能性のあるインデックスを検出
SELECT * FROM find_duplicate_indexes();
```

**期待される結果**:
- `idx_meanings_on_word_id` が `idx_word_meanings_word_priority` で冗長になっている可能性
- パフォーマンステスト後に削除を検討

---

## 🧪 パフォーマンステスト

### テスト1: word_meaningsの優先度順取得

```sql
-- インデックスなしでのクエリプラン
EXPLAIN ANALYZE
SELECT * FROM word_meanings 
WHERE word_id = 1 
ORDER BY priority;
```

**確認ポイント**:
- `Index Scan using idx_word_meanings_word_priority` が使用されているか
- 実行時間が短縮されているか

### テスト2: example_contentsのテーマ別取得

```sql
EXPLAIN ANALYZE
SELECT * FROM example_contents 
WHERE meaning_id = 1 
AND theme = 'simple';
```

**確認ポイント**:
- `Index Scan using idx_example_contents_meaning_theme` が使用されているか

### テスト3: 復習予定の単語取得

```sql
-- 実際のユーザーIDに置き換えてください
EXPLAIN ANALYZE
SELECT * FROM user_learning_progress 
WHERE user_id = '123e4567-e89b-12d3-a456-426614174000'::uuid
AND next_review_date <= NOW()
ORDER BY next_review_date;
```

**確認ポイント**:
- `Index Scan using idx_user_learning_progress_user_next_review` が使用されているか

### テスト4: 前方一致検索

```sql
EXPLAIN ANALYZE
SELECT * FROM words 
WHERE word_text LIKE 'app%'
LIMIT 10;
```

**確認ポイント**:
- `Index Scan using idx_words_text_pattern` が使用されているか
- GINインデックス(`idx_words_word_text_gin`)ではなく、text_pattern_opsインデックスが使用されているか

---

## 🔧 トラブルシューティング

### エラー: "index already exists"

**原因**: インデックスが既に存在している

**解決策**: 
```sql
-- 既存のインデックスを確認
SELECT indexname FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexname = 'idx_word_meanings_word_priority';

-- 既に存在する場合はスキップ（IF NOT EXISTSで自動対応済み）
```

### インデックスが使用されない

**原因**: クエリプランナーが別のインデックスを選択している

**解決策**:
1. テーブルの統計情報を更新
```sql
ANALYZE word_meanings;
ANALYZE example_contents;
ANALYZE user_learning_progress;
```

2. クエリを確認してWHERE句の順序を調整

### パフォーマンスが改善しない

**原因**: データ量が少なく、インデックスのオーバーヘッドが大きい

**解決策**:
- データ量が増えるまで様子を見る
- EXPLAIN ANALYZEで実際のコストを確認
- 必要に応じてインデックスを削除

---

## 📈 期待される効果

### パフォーマンス改善目標

| クエリパターン | 改善目標 | 対象インデックス |
|------------|--------|--------------|
| 単語の意味を優先度順で取得 | 50%以上高速化 | idx_word_meanings_word_priority |
| テーマ別例文取得 | 40%以上高速化 | idx_example_contents_meaning_theme |
| 復習予定の単語取得 | 60%以上高速化 | idx_user_learning_progress_user_next_review |
| ステータス別単語一覧 | 50%以上高速化 | idx_user_learning_progress_user_status |
| 前方一致検索 | 30%以上高速化 | idx_words_text_pattern |

### インデックスサイズの見積もり

```sql
-- インデックスのサイズを確認
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
FROM pg_indexes
WHERE schemaname = 'public'
AND (indexname LIKE '%word_priority%'
   OR indexname LIKE '%meaning_theme%'
   OR indexname LIKE '%user_status%'
   OR indexname LIKE '%user_next_review%'
   OR indexname LIKE '%user_srs_level%'
   OR indexname LIKE '%user_tab_order%'
   OR indexname LIKE '%text_pattern%'
   OR indexname LIKE '%covering%')
ORDER BY pg_relation_size(indexname::regclass) DESC;
```

**想定サイズ**: 合計で数十KB〜数百KB（データ量に依存）

---

## 📝 実行後の次のステップ

1. ✅ このファイルを実行完了
2. 📊 インデックス使用統計の監視開始
3. 🧪 実際のクエリでパフォーマンステスト
4. 🗑️ 冗長インデックスの削除を検討
5. 📋 タスク一覧を更新

---

## ⚠️ 注意事項

### インデックスのトレードオフ

✅ **メリット**:
- クエリパフォーマンスの大幅改善
- ソート処理の高速化
- JOIN処理の最適化

❌ **デメリット**:
- データ挿入・更新時のオーバーヘッド増加
- ストレージ使用量の増加
- インデックスのメンテナンスコスト

### 定期的なメンテナンス

```sql
-- インデックスの再構築（必要に応じて）
REINDEX INDEX CONCURRENTLY idx_word_meanings_word_priority;

-- 統計情報の更新
ANALYZE word_meanings;
ANALYZE example_contents;
ANALYZE user_learning_progress;
```

---

**作成日**: 2025年10月1日  
**対象**: タスク04 複合インデックスの追加

