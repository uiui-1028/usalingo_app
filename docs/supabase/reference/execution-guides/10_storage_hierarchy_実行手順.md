# 📘 ストレージ階層化 実行手順

## 🎯 このファイルについて

このファイルは `10_storage_hierarchy.sql` を実行する手順を説明します。

---

## ⚠️ 重要な注意事項

このタスクは**データベース構造の変更とファイル移行を伴う**ため、以下の点に注意してください：

1. **バックアップ必須**: 実行前に必ずデータベースとストレージのバックアップを取得
2. **段階的実施**: SQLの実行とファイル移行は分けて実施
3. **ロールバック計画**: 問題が発生した場合の戻し方を事前に確認

---

## 📍 実行場所

**Supabase SQL Editor** で実行します。

---

## 🚀 実行手順

### フェーズ1: データベース構造の変更 ⚙️

#### 1️⃣ Supabase SQL Editorを開く

1. Supabaseダッシュボードにログイン (https://supabase.com/dashboard)
2. プロジェクトを選択
3. 左側メニューから「**SQL Editor**」をクリック

#### 2️⃣ SQLファイルを実行

1. SQL Editorで「**New query**」をクリック
2. `docs/supabase/sql/10_storage_hierarchy.sql` の内容を全てコピー
3. SQL Editorに貼り付け
4. 「**Run**」ボタンをクリック

#### 3️⃣ 実行結果を確認

成功すると以下のメッセージが表示されます：

```
status: "ストレージ階層化のセットアップが完了しました。"
```

---

### フェーズ2: 動作確認 ✅

#### テスト1: パス生成関数の確認

```sql
-- ID範囲フォルダ名の生成テスト
SELECT 
    public.get_asset_folder_path(1) as folder_for_id_1,      -- 期待値: "0000-0199"
    public.get_asset_folder_path(200) as folder_for_id_200,  -- 期待値: "0200-0399"
    public.get_asset_folder_path(999) as folder_for_id_999;  -- 期待値: "0800-0999"
```

**期待される結果**:
- `folder_for_id_1`: "0000-0199"
- `folder_for_id_200`: "0200-0399"
- `folder_for_id_999`: "0800-0999"

#### テスト2: 完全パス生成の確認

```sql
-- 例文イラストの完全パス生成
SELECT 
    id,
    theme,
    illustration_ext,
    public.get_example_illustration_path(id, theme, illustration_ext) as full_path
FROM example_contents
LIMIT 5;
```

**期待される結果**:
```
id  | theme    | illustration_ext | full_path
----|----------|------------------|------------------------------------------
1   | シンプル  | webp             | content-images/シンプル/0000-0199/1.webp
2   | シンプル  | webp             | content-images/シンプル/0000-0199/2.webp
...
```

#### テスト3: ビューの動作確認

```sql
-- ビューから完全パスを取得
SELECT 
    id,
    theme,
    illustration_path,
    audio_path
FROM v_example_contents_with_paths
LIMIT 5;
```

#### テスト4: ストレージ構造サマリー

```sql
-- 期待されるフォルダ構造を確認
SELECT * FROM public.get_storage_structure_summary();
```

**期待される結果**:
```
theme    | folder_range | expected_file_count | example_file_paths
---------|--------------|---------------------|--------------------
シンプル  | 0000-0199    | 199                 | {content-images/シンプル/0000-0199/1.webp, ...}
シンプル  | 0200-0399    | 200                 | {content-images/シンプル/0200-0399/200.webp, ...}
シンプル  | 0400-0599    | 200                 | {content-images/シンプル/0400-0599/400.webp, ...}
シンプル  | 0600-0799    | 200                 | {content-images/シンプル/0600-0799/600.webp, ...}
シンプル  | 0800-0999    | 200                 | {content-images/シンプル/0800-0999/800.webp, ...}
シンプル  | 1000-1199    | 1                   | {content-images/シンプル/1000-1199/1000.webp}
```

---

### フェーズ3: アプリケーション側の対応 📱

#### Flutterアプリでの使用例

**旧方式（非推奨）**:
```dart
// データベースから直接パスを取得
final example = await supabase
    .from('example_contents')
    .select('illustration_asset_path')
    .eq('id', 1)
    .single();

final path = example['illustration_asset_path'];
```

**新方式（推奨）**:
```dart
// ビューから動的生成されたパスを取得
final example = await supabase
    .from('v_example_contents_with_paths')
    .select('illustration_path, audio_path')
    .eq('id', 1)
    .single();

final illustrationPath = example['illustration_path'];
final audioPath = example['audio_path'];

// Storageからファイルを取得
final illustrationUrl = supabase.storage
    .from('content-images')
    .getPublicUrl(illustrationPath);
```

---

### フェーズ4: ファイル移行（慎重に実施） 📦

#### ⚠️ この段階は別途計画が必要

ファイル移行は以下の手順で実施します（**今回のSQLには含まれていません**）：

1. **バックアップ作成**
   ```bash
   # ローカルにすべてのファイルをダウンロード
   supabase storage download content-images --recursive
   supabase storage download content-audio --recursive
   ```

2. **新しいフォルダ構造を作成**
   - Supabase管理画面から手動で作成、または
   - スクリプトで自動作成

3. **ファイルを移動**
   - Edge Functionまたはローカルスクリプトで実施
   - 段階的に移行（一度に全部やらない）

4. **動作確認**
   - アプリから新パスでアクセスできるか確認

5. **旧ファイルの削除**
   - 十分な検証期間の後に削除

---

## 📊 追加されたデータベースオブジェクト

### 関数（5個）

1. **`get_asset_folder_path(id, bucket_size)`**
   - ID範囲フォルダ名を生成（例: "200-399"）

2. **`get_example_illustration_path(id, theme, ext)`**
   - 例文イラストの完全パスを生成

3. **`get_example_audio_path(id, theme, ext)`**
   - 例文音声の完全パスを生成

4. **`get_word_audio_path(id, ext)`**
   - 単語音声の完全パスを生成

5. **`get_storage_structure_summary()`**
   - ストレージ構造のサマリーを表示（管理用）

6. **`find_missing_assets()`**
   - 欠損しているアセットを検出（管理用）

### テーブル変更

| テーブル | 追加カラム | 型 | デフォルト値 | 説明 |
|---------|-----------|-----|------------|------|
| example_contents | `illustration_ext` | TEXT | 'webp' | イラスト拡張子 |
| example_contents | `audio_ext` | TEXT | 'mp3' | 音声拡張子 |
| word_meanings | `audio_ext` | TEXT | 'mp3' | 音声拡張子 |

### ビュー（2個）

1. **`v_example_contents_with_paths`**
   - 例文コンテンツに完全パス付き

2. **`v_word_meanings_with_paths`**
   - 単語の意味に完全パス付き

---

## 🔧 トラブルシューティング

### エラー: "column already exists"

**原因**: カラムが既に存在している

**解決策**:
```sql
-- カラムの存在確認
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'example_contents' 
AND column_name IN ('illustration_ext', 'audio_ext');

-- 既に存在する場合はスキップ（IF NOT EXISTSで自動対応済み）
```

### 関数が正しく動作しない

**原因**: 関数のキャッシュ問題

**解決策**:
```sql
-- 関数を再作成
CREATE OR REPLACE FUNCTION public.get_asset_folder_path(...)
...
```

### ビューにデータが表示されない

**原因**: ビューの定義問題

**解決策**:
```sql
-- ビューを確認
SELECT * FROM v_example_contents_with_paths LIMIT 1;

-- エラーが出る場合は再作成
DROP VIEW IF EXISTS v_example_contents_with_paths;
CREATE OR REPLACE VIEW ...
```

---

## 📈 期待されるフォルダ構造

### 例文イラスト

```
content-images/
  └── シンプル/
      ├── 0000-0199/   (199ファイル: 1.webp ~ 199.webp)
      ├── 0200-0399/   (200ファイル: 200.webp ~ 399.webp)
      ├── 0400-0599/   (200ファイル: 400.webp ~ 599.webp)
      ├── 0600-0799/   (200ファイル: 600.webp ~ 799.webp)
      ├── 0800-0999/   (200ファイル: 800.webp ~ 999.webp)
      └── 1000-1199/   (1ファイル: 1000.webp)
```

### 例文音声

```
content-audio/
  └── example/
      └── シンプル/
          ├── 0000-0199/ (199ファイル: 1.mp3 ~ 199.mp3)
          ├── 0200-0399/ (200ファイル: 200.mp3 ~ 399.mp3)
          ├── 0400-0599/ (200ファイル: 400.mp3 ~ 599.mp3)
          ├── 0600-0799/ (200ファイル: 600.mp3 ~ 799.mp3)
          ├── 0800-0999/ (200ファイル: 800.mp3 ~ 999.mp3)
          └── 1000-1199/ (1ファイル: 1000.mp3)
```

### 単語音声

```
content-audio/
  └── word/
      ├── 0000-0199/   (200ファイル: 1.mp3 ~ 199.mp3)
      ├── 0200-0399/   (200ファイル: 200.mp3 ~ 399.mp3)
      ├── 0400-0599/   (200ファイル: 400.mp3 ~ 599.mp3)
      ├── 0600-0799/   (200ファイル: 600.mp3 ~ 799.mp3)
      ├── 0800-0999/   (200ファイル: 800.mp3 ~ 999.mp3)
      └── 1000-1199/   (必要に応じて)
```

---

## 📝 次のステップ

1. ✅ **フェーズ1完了**: データベース構造の変更
2. ✅ **フェーズ2完了**: 動作確認とテスト
3. ⏳ **フェーズ3**: アプリケーション側の対応
4. ⏳ **フェーズ4**: ファイル移行計画の策定
5. ⏳ **フェーズ5**: 段階的なファイル移行の実施

---

## ⚠️ 移行時の注意点

### 互換性の維持

- 旧`*_asset_path`カラムは残しておく（すぐには削除しない）
- アプリは新旧両方のパスに対応できるようにする
- フォールバック処理を実装

### 段階的な移行

1. 新規ファイルから新構造を適用
2. 既存ファイルは徐々に移行
3. 全移行完了後、旧パスのファイルを削除
4. 十分な検証期間後、旧カラムを削除

---

**作成日**: 2025年10月1日  
**対象**: タスク07 ストレージ階層化の実装

