# Supabase CLIを活用したフォルダーツリー自動作成

## 🎯 概要

Supabase CLIの自動フォルダ作成機能を活用して、必要なフォルダ構造を一括で作成します。

## 📋 前提条件

1. **Supabase CLIがインストール済み**
   ```bash
   npm install -g supabase
   ```

2. **Supabaseプロジェクトにログイン済み**
   ```bash
   supabase login
   ```

3. **プロジェクトがリンク済み**
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. **環境変数が設定済み**
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

## 🚀 実行方法

### 方法1: TypeScriptスクリプト（推奨）

```zsh
# プロジェクトディレクトリに移動
cd /Users/art0/development/usalingo_app

# 現在用フォルダのみ作成
deno run --allow-net --allow-read --allow-env docs/supabase/storage-migration/03_create_folder_tree.ts

# 将来用フォルダも含めて作成
deno run --allow-net --allow-read --allow-env docs/supabase/storage-migration/03_create_folder_tree.ts --include-future
```

### 方法2: Supabase CLIコマンド（手動）

スクリプト実行時に生成されるコマンドを順次実行：

```zsh
# 一時ディレクトリ作成
mkdir -p temp

# フォルダ作成（例）
echo "# フォルダ作成用" > temp/dummy_001.txt
supabase storage cp temp/dummy_001.txt content-images/シンプル/0000-0199/dummy_001.txt
supabase storage rm content-images/シンプル/0000-0199/dummy_001.txt
rm temp/dummy_001.txt

# 以下、各フォルダに対して繰り返し...

# クリーンアップ
rmdir temp 2>/dev/null || true
```

## 📁 作成されるフォルダ構造

### 現在用（18フォルダ）

```
content-images/
└── シンプル/
    ├── 0000-0199/
    ├── 0200-0399/
    ├── 0400-0599/
    ├── 0600-0799/
    ├── 0800-0999/
    └── 1000-1199/

content-audio/
├── example/
│   └── シンプル/
│       ├── 0000-0199/
│       ├── 0200-0399/
│       ├── 0400-0599/
│       ├── 0600-0799/
│       ├── 0800-0999/
│       └── 1000-1199/
└── word/
    ├── 0000-0199/
    ├── 0200-0399/
    ├── 0400-0599/
    ├── 0600-0799/
    ├── 0800-0999/
    └── 1000-1199/
```

### 将来用（90フォルダ、--include-future指定時）

```
content-images/
├── シンプル/ (6フォルダ)
├── ビジネス/ (6フォルダ)
├── カジュアル/ (6フォルダ)
├── アカデミック/ (6フォルダ)
└── 子供向け/ (6フォルダ)

content-audio/
├── example/
│   ├── シンプル/ (6フォルダ)
│   ├── ビジネス/ (6フォルダ)
│   ├── カジュアル/ (6フォルダ)
│   ├── アカデミック/ (6フォルダ)
│   └── 子供向け/ (6フォルダ)
└── word/ (6フォルダ)
```

## 🔍 動作確認

### 1. フォルダ作成の確認

Supabase管理画面のStorageセクションで、以下のフォルダが作成されていることを確認：

- `content-images/シンプル/0000-0199/`
- `content-images/シンプル/0200-0399/`
- `content-audio/example/シンプル/0000-0199/`
- `content-audio/word/0000-0199/`
- など...

### 2. フォルダ構造の確認

```sql
-- 作成されたフォルダ構造を確認
SELECT 
  bucket_name,
  name as folder_path,
  created_at
FROM storage.objects 
WHERE bucket_id IN ('content-images', 'content-audio')
  AND name LIKE '%/'
ORDER BY bucket_id, name;
```

## ⚠️ 注意事項

1. **API制限**: リクエスト間に100msの待機時間を設けています
2. **ダミーファイル**: フォルダ作成後にダミーファイルは自動削除されます
3. **既存フォルダ**: 既に存在するフォルダはスキップされます
4. **権限**: Storageの書き込み権限が必要です

## 🐛 トラブルシューティング

### エラー: "Bucket not found"
```zsh
# バケットが存在するか確認
supabase storage ls
```

### エラー: "Permission denied"
```zsh
# 認証状態を確認
supabase projects list
```

### エラー: "Rate limit exceeded"
- スクリプト内の待機時間を増やす
- 手動でコマンドを分割実行

## 📊 実行結果例

```
🎯 Supabase CLIを活用したフォルダーツリー自動作成
================================================

🚀 現在用フォルダ構造の作成を開始...
✅ フォルダ作成成功: content-images/シンプル/0000-0199
✅ フォルダ作成成功: content-images/シンプル/0200-0399
...
✅ フォルダ作成成功: content-audio/word/1000-1199

📊 現在用フォルダ作成結果:
   ✅ 成功: 18フォルダ
   ❌ 失敗: 0フォルダ

🎉 フォルダーツリー作成完了!
================================
📁 現在用フォルダ: 18個作成
❌ エラー: 0個
```

## 🔄 次のステップ

フォルダ作成完了後：

1. **ファイル移行の実施**
   - `02_migration_script.ts` を使用してファイルを移行
   
2. **移行結果の確認**
   - 管理画面でファイルが正しいフォルダに配置されているか確認
   
3. **パス生成関数のテスト**
   - `get_example_illustration_path()` などの関数が正しく動作するか確認
