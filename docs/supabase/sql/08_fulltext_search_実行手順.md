# 📘 全文検索インデックス 実行手順

## 🎯 このファイルについて

このファイルは `08_fulltext_search.sql` を実行する手順を説明します。

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
2. `docs/supabase/sql/08_fulltext_search.sql` の内容を全てコピー
3. SQL Editorに貼り付け
4. 「**Run**」ボタンをクリック

### 3️⃣ 実行結果を確認

成功すると以下のメッセージが表示されます：

```
status: "全文検索インデックスのセットアップが完了しました。"
```

---

## ✅ 動作確認

### インデックスの確認

```sql
-- GINインデックスの一覧を表示
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes 
WHERE indexname LIKE '%gin%' 
ORDER BY tablename, indexname;
```

期待される結果：
- `idx_words_word_text_gin`
- `idx_word_meanings_definition_jp_gin`
- `idx_word_meanings_part_of_speech_en_gin`
- など、合計10個のGINインデックス

### 検索関数の確認

```sql
-- 関数が作成されているか確認
SELECT 
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc 
WHERE proname LIKE 'search_%'
ORDER BY proname;
```

期待される結果：
- `search_words`
- `search_meanings`
- `search_examples`
- `search_all`

### 実際に検索してみる

```sql
-- 単語検索のテスト
SELECT * FROM search_words('apple', 0.3, 10);

-- 意味検索のテスト  
SELECT * FROM search_meanings('リンゴ', 0.3, 10);

-- 例文検索のテスト（英語）
SELECT * FROM search_examples('apple', 'en', 0.3, 10);

-- 統合検索のテスト
SELECT * FROM search_all('apple', 0.3, 20);
```

---

## 📊 パフォーマンス確認

インデックスの使用状況を監視：

```sql
-- インデックス使用統計を確認
SELECT * FROM v_index_usage_stats;
```

---

## 🔧 トラブルシューティング

### エラー: "extension \"pg_trgm\" does not exist"

**原因**: pg_trgm拡張機能が有効化されていない

**解決策**: SQLの冒頭に以下が含まれているか確認
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### エラー: "relation does not exist"

**原因**: 必要なテーブルが存在しない

**解決策**: 
1. 基本スキーマ（`01_schema.sql`など）が先に実行されているか確認
2. 以下のクエリでテーブルの存在を確認：
```sql
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('words', 'word_meanings', 'example_contents', 'decks');
```

### 検索結果が表示されない

**原因**: データが存在しない、または類似度が低すぎる

**解決策**:
1. データの確認: `SELECT COUNT(*) FROM words;`
2. 類似度の閾値を下げて試す: `search_words('test', 0.1, 10)`

---

## 📝 実行後の次のステップ

1. ✅ このファイルを実行完了
2. 📋 タスク一覧を更新（実行完了をチェック）
3. 🧪 実際の検索機能をFlutterアプリに統合

---

**作成日**: 2025年10月1日  
**対象**: タスク06 全文検索インデックスの追加

