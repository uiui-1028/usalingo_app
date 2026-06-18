# Supabase Queries for iOS MVP

## 1. Deck List

```text
目的:
学習デッキ一覧を表示する

使うテーブル:
decks
deck_words
user_learning_progress
```

## 2. Deck Cards

```text
目的:
選んだデッキのカードを取得する

使うテーブル:
deck_words
words
word_meanings
example_contents
```

## 3. Due Cards

```text
目的:
復習すべきカードを優先して取得する

条件:
user_learning_progress.next_review_date <= now
```

## 4. Save Answer

```text
目的:
わかる/わからないを保存する

使うテーブル:
user_learning_progress

方法:
upsert by user_id + word_id
```

## 5. Image URL

```text
目的:
カードのイラストを表示する

使う値:
example_contents.illustration_asset_path

Storage:
content-images
```

## Not Needed Yet

```text
- 全文検索
- card_templates
- user_widget_layouts
- Edge Functions
- 複雑な同期
```
