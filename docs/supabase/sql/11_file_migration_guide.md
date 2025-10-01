# 📦 ストレージファイル移行ガイド

## 🎯 移行の目的

現在フラットな構造で保存されているアセットファイルを、テーマ別・ID範囲別の階層構造に移行します。

---

## 📊 現状分析

### ファイル数
- **例文イラスト**: 1,000件
- **例文音声**: 999件
- **単語音声**: 1,000件
- **合計**: 約3,000ファイル

### 現在のファイル構造
```
content-images/
  ├── example_1.webp
  ├── example_2.webp
  ...
  └── example_1000.webp

content-audio/
  ├── example_1.mp3
  ├── example_2.mp3
  ...
  └── example_1000.mp3
  ├── word_1.mp3（想定）
  ...
```

### 目標の構造
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
  │       └── ...
  └── word/
      ├── 0000-0199/
      └── ...
```

---

## ⚠️ 重要な注意事項

### 1. **破壊的な操作です**
- ファイル移行は元に戻すのが困難
- 必ずバックアップを取得してから実施

### 2. **ダウンタイムが発生する可能性**
- アプリがファイルにアクセスできない期間が発生
- メンテナンスモードの検討が必要

### 3. **段階的に実施**
- 一度に全ファイルを移行しない
- 小さなバッチで検証しながら進める

---

## 📋 移行手順

### フェーズ1: 準備 🛠️

#### 1-1. バックアップの取得

**重要**: すべてのファイルをローカルにダウンロード

```bash
# Supabase CLIを使用（推奨）
supabase storage cp --recursive content-images ./backup/content-images
supabase storage cp --recursive content-audio ./backup/content-audio

# または、管理画面から手動でダウンロード
```

#### 1-2. データベースのバックアップ

```sql
-- 現在のasset_pathをバックアップ
CREATE TABLE IF NOT EXISTS example_contents_backup AS
SELECT 
    id,
    illustration_asset_path,
    audio_asset_path,
    illustration_filename,
    audio_filename
FROM example_contents;

CREATE TABLE IF NOT EXISTS word_meanings_backup AS
SELECT 
    id,
    audio_asset_path,
    audio_filename
FROM word_meanings;
```

#### 1-3. メンテナンスモードの設定（推奨）

アプリ側でメンテナンスモードを有効化し、ユーザーアクセスを制限

---

### フェーズ2: テスト移行 🧪

#### 2-1. 少数ファイルでテスト（ID 1-10）

Supabase管理画面または以下のスクリプトで実施：

```typescript
// Deno/Edge Functionまたはローカルスクリプト
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SERVICE_ROLE_KEY' // 管理者権限が必要
)

async function migrateTestFiles() {
  const testIds = [1, 2, 3, 4, 5] // テスト用に5件のみ
  
  for (const id of testIds) {
    // 例文イラストを移行
    await migrateExampleIllustration(id)
    
    // 例文音声を移行
    await migrateExampleAudio(id)
  }
}

async function migrateExampleIllustration(id: number) {
  // 1. データベースから情報取得
  const { data: example } = await supabase
    .from('v_example_contents_with_paths')
    .select('id, theme, illustration_asset_path, illustration_path')
    .eq('id', id)
    .single()
  
  if (!example || !example.illustration_asset_path) return
  
  const oldPath = example.illustration_asset_path.replace('content-images/', '')
  const newPath = example.illustration_path.replace('content-images/', '')
  
  console.log(`移行: ${oldPath} → ${newPath}`)
  
  // 2. 新しいフォルダパスを抽出
  const newFolder = newPath.substring(0, newPath.lastIndexOf('/'))
  
  // 3. ファイルをコピー（まずはコピーして安全確認）
  try {
    const { data: fileData } = await supabase.storage
      .from('content-images')
      .download(oldPath)
    
    if (!fileData) {
      console.error(`ファイルが見つかりません: ${oldPath}`)
      return
    }
    
    // 新しいパスにアップロード
    const { error } = await supabase.storage
      .from('content-images')
      .upload(newPath, fileData, {
        upsert: true
      })
    
    if (error) {
      console.error(`アップロード失敗: ${newPath}`, error)
      return
    }
    
    console.log(`✓ コピー成功: ${newPath}`)
    
    // 4. 新しいパスで正常にアクセスできるか確認
    const { data: publicUrl } = supabase.storage
      .from('content-images')
      .getPublicUrl(newPath)
    
    console.log(`公開URL: ${publicUrl}`)
    
  } catch (error) {
    console.error(`エラー発生: ${id}`, error)
  }
}

async function migrateExampleAudio(id: number) {
  // 同様のロジックでaudioを移行
  // ... (上記と同じパターン)
}
```

#### 2-2. テスト結果の確認

```sql
-- 移行されたファイルのパスを確認
SELECT 
    id,
    theme,
    illustration_path,
    audio_path
FROM v_example_contents_with_paths
WHERE id IN (1, 2, 3, 4, 5);
```

Supabase管理画面で実際にファイルが新しい場所に存在するか確認

---

### フェーズ3: 本番移行 🚀

#### 3-1. バッチ移行スクリプト

```typescript
async function migrateBatch(startId: number, endId: number) {
  console.log(`バッチ移行開始: ID ${startId} - ${endId}`)
  
  const { data: examples } = await supabase
    .from('v_example_contents_with_paths')
    .select('*')
    .gte('id', startId)
    .lte('id', endId)
  
  if (!examples) return
  
  let successCount = 0
  let errorCount = 0
  
  for (const example of examples) {
    try {
      // イラストを移行
      if (example.illustration_asset_path) {
        await migrateFile(
          'content-images',
          example.illustration_asset_path.replace('content-images/', ''),
          example.illustration_path.replace('content-images/', '')
        )
      }
      
      // 音声を移行
      if (example.audio_asset_path) {
        await migrateFile(
          'content-audio',
          example.audio_asset_path.replace('content-audio/', ''),
          example.audio_path.replace('content-audio/', '')
        )
      }
      
      successCount++
      console.log(`✓ ${example.id} 完了 (${successCount}/${examples.length})`)
      
      // レート制限対策: 少し待機
      await new Promise(resolve => setTimeout(resolve, 100))
      
    } catch (error) {
      errorCount++
      console.error(`✗ ${example.id} 失敗:`, error)
    }
  }
  
  console.log(`バッチ完了: 成功 ${successCount}, 失敗 ${errorCount}`)
}

async function migrateFile(bucket: string, oldPath: string, newPath: string) {
  // ファイルをダウンロード
  const { data: fileData, error: downloadError } = await supabase.storage
    .from(bucket)
    .download(oldPath)
  
  if (downloadError) throw downloadError
  
  // 新しいパスにアップロード
  const { error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(newPath, fileData, { upsert: true })
  
  if (uploadError) throw uploadError
}

// 実行
async function runMigration() {
  // ID 0-199を移行
  await migrateBatch(1, 199)
  
  // ID 200-399を移行
  await migrateBatch(200, 399)
  
  // 以降同様に続ける...
}
```

#### 3-2. 段階的な移行

```bash
# 推奨スケジュール
Day 1: ID 1-199    (バッチ1)
Day 2: ID 200-399  (バッチ2)
Day 3: ID 400-599  (バッチ3)
Day 4: ID 600-799  (バッチ4)
Day 5: ID 800-999  (バッチ5)
Day 6: ID 1000+    (バッチ6)
```

各バッチ完了後、必ず確認：
1. ファイルが新しい場所に存在するか
2. アプリから正常にアクセスできるか
3. エラーログの確認

---

### フェーズ4: 検証と旧ファイル削除 🗑️

#### 4-1. 移行完了の確認

```sql
-- すべてのファイルが新しいパスで生成されているか確認
SELECT 
    theme,
    COUNT(*) as total,
    COUNT(illustration_filename) as has_illustration,
    COUNT(audio_filename) as has_audio
FROM example_contents
GROUP BY theme;
```

Supabase管理画面で新しいフォルダ構造を確認：
- content-images/シンプル/0-199/ に約199ファイル
- content-images/シンプル/200-399/ に200ファイル
- など

#### 4-2. アプリからのアクセステスト

Flutterアプリで実際にファイルが表示されるか確認

#### 4-3. 旧ファイルの削除（慎重に！）

**警告**: この操作は元に戻せません

```typescript
async function deleteOldFiles(startId: number, endId: number) {
  const { data: examples } = await supabase
    .from('example_contents_backup') // バックアップテーブルから
    .select('*')
    .gte('id', startId)
    .lte('id', endId)
  
  if (!examples) return
  
  for (const example of examples) {
    // 旧パスからファイルを削除
    if (example.illustration_asset_path) {
      await supabase.storage
        .from('content-images')
        .remove([example.illustration_asset_path.replace('content-images/', '')])
    }
    
    if (example.audio_asset_path) {
      await supabase.storage
        .from('content-audio')
        .remove([example.audio_asset_path.replace('content-audio/', '')])
    }
  }
}
```

---

## 🔧 トラブルシューティング

### 問題1: ファイルが見つからない

```typescript
// 欠損ファイルをリストアップ
async function findMissingFiles() {
  const { data } = await supabase
    .from('v_example_contents_with_paths')
    .select('*')
  
  for (const item of data || []) {
    // 新しいパスでファイル存在確認
    const { data: file, error } = await supabase.storage
      .from('content-images')
      .download(item.illustration_path.replace('content-images/', ''))
    
    if (error) {
      console.log(`欠損: ${item.id} - ${item.illustration_path}`)
    }
  }
}
```

### 問題2: 移行が途中で失敗

- バックアップから復元
- エラーログを確認
- 該当バッチのみ再実行

### 問題3: パフォーマンスが悪い

- バッチサイズを小さくする（50件ずつなど）
- レート制限の待機時間を増やす

---

## ✅ チェックリスト

### 移行前
- [ ] すべてのファイルをローカルにバックアップ
- [ ] データベースのバックアップ作成
- [ ] メンテナンスモードの設定
- [ ] 移行スクリプトの準備

### 移行中
- [ ] テスト移行の実施（ID 1-10）
- [ ] テスト結果の確認
- [ ] バッチ1の移行（ID 1-199）
- [ ] バッチ1の確認
- [ ] バッチ2-6の移行

### 移行後
- [ ] すべてのファイルが新しい場所に存在
- [ ] アプリから正常にアクセスできる
- [ ] エラーログの確認
- [ ] 十分な検証期間（1-2週間）
- [ ] 旧ファイルの削除
- [ ] メンテナンスモードの解除

---

## 📞 サポート

移行中に問題が発生した場合は、すぐに作業を中断してバックアップから復元してください。

---

**作成日**: 2025年10月1日  
**対象**: タスク07 ストレージ階層化の実装 - ファイル移行

