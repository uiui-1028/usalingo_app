/**
 * ストレージファイル移行スクリプト
 * 
 * 実行前の準備:
 * 1. 01_backup_script.ts でバックアップを取得
 * 2. Supabase URLとService Role Keyを環境変数に設定
 * 
 * 実行方法:
 * deno run --allow-net --allow-env 02_migration_script.ts
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

interface MigrationResult {
  id: number
  success: boolean
  illustrationMigrated: boolean
  audioMigrated: boolean
  error?: string
}

interface BatchResult {
  total: number
  success: number
  failed: number
  results: MigrationResult[]
}

/**
 * ファイルを新しいパスに移行
 */
async function migrateFile(
  bucket: string,
  oldPath: string,
  newPath: string
): Promise<boolean> {
  try {
    // 1. 旧パスからダウンロード
    const { data: fileData, error: downloadError } = await supabase.storage
      .from(bucket)
      .download(oldPath)
    
    if (downloadError) {
      console.error(`  ❌ ダウンロード失敗 (${oldPath}):`, downloadError.message)
      return false
    }
    
    if (!fileData) {
      console.error(`  ❌ ファイルデータなし (${oldPath})`)
      return false
    }
    
    // 2. 新しいパスにアップロード
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(newPath, fileData, {
        upsert: true,
        contentType: fileData.type
      })
    
    if (uploadError) {
      console.error(`  ❌ アップロード失敗 (${newPath}):`, uploadError.message)
      return false
    }
    
    // 3. アップロードされたファイルの存在確認
    const { data: checkData, error: checkError } = await supabase.storage
      .from(bucket)
      .download(newPath)
    
    if (checkError || !checkData) {
      console.error(`  ❌ 確認失敗 (${newPath})`)
      return false
    }
    
    return true
    
  } catch (error) {
    console.error(`  ❌ エラー:`, error)
    return false
  }
}

/**
 * 例文コンテンツのファイルを移行
 */
async function migrateExampleContent(id: number): Promise<MigrationResult> {
  const result: MigrationResult = {
    id,
    success: false,
    illustrationMigrated: false,
    audioMigrated: false
  }
  
  try {
    // データベースから情報取得
    const { data: example, error } = await supabase
      .from('v_example_contents_with_paths')
      .select('*')
      .eq('id', id)
      .single()
    
    if (error || !example) {
      result.error = `データ取得失敗: ${error?.message}`
      return result
    }
    
    // イラストを移行
    if (example.illustration_asset_path && example.illustration_path) {
      const oldPath = example.illustration_asset_path.replace('content-images/', '')
      const newPath = example.illustration_path.replace('content-images/', '')
      
      if (oldPath !== newPath) {
        result.illustrationMigrated = await migrateFile('content-images', oldPath, newPath)
      } else {
        result.illustrationMigrated = true // 既に正しい場所
      }
    } else {
      result.illustrationMigrated = true // ファイルなし
    }
    
    // 音声を移行
    if (example.audio_asset_path && example.audio_path) {
      const oldPath = example.audio_asset_path.replace('content-audio/', '')
      const newPath = example.audio_path.replace('content-audio/', '')
      
      if (oldPath !== newPath) {
        result.audioMigrated = await migrateFile('content-audio', oldPath, newPath)
      } else {
        result.audioMigrated = true // 既に正しい場所
      }
    } else {
      result.audioMigrated = true // ファイルなし
    }
    
    result.success = result.illustrationMigrated && result.audioMigrated
    
  } catch (error) {
    result.error = `例外: ${error}`
  }
  
  return result
}

/**
 * 単語音声ファイルを移行
 */
async function migrateWordAudio(id: number): Promise<MigrationResult> {
  const result: MigrationResult = {
    id,
    success: false,
    illustrationMigrated: true, // N/A
    audioMigrated: false
  }
  
  try {
    // データベースから情報取得
    const { data: word, error } = await supabase
      .from('v_word_meanings_with_paths')
      .select('*')
      .eq('id', id)
      .single()
    
    if (error || !word) {
      result.error = `データ取得失敗: ${error?.message}`
      return result
    }
    
    // 音声を移行
    if (word.audio_asset_path && word.audio_path) {
      const oldPath = word.audio_asset_path.replace('content-audio/', '')
      const newPath = word.audio_path.replace('content-audio/', '')
      
      if (oldPath !== newPath) {
        result.audioMigrated = await migrateFile('content-audio', oldPath, newPath)
      } else {
        result.audioMigrated = true // 既に正しい場所
      }
    } else {
      result.audioMigrated = true // ファイルなし
    }
    
    result.success = result.audioMigrated
    
  } catch (error) {
    result.error = `例外: ${error}`
  }
  
  return result
}

/**
 * バッチ移行
 */
async function migrateBatch(
  type: 'example' | 'word',
  startId: number,
  endId: number
): Promise<BatchResult> {
  console.log(`\n📦 バッチ移行: ${type} ID ${startId}-${endId}`)
  
  const batchResult: BatchResult = {
    total: endId - startId + 1,
    success: 0,
    failed: 0,
    results: []
  }
  
  for (let id = startId; id <= endId; id++) {
    const result = type === 'example' 
      ? await migrateExampleContent(id)
      : await migrateWordAudio(id)
    
    batchResult.results.push(result)
    
    if (result.success) {
      batchResult.success++
      if (id % 10 === 0 || id === endId) {
        console.log(`  ✅ ID ${id}: 成功 (${batchResult.success}/${id - startId + 1})`)
      }
    } else {
      batchResult.failed++
      console.log(`  ❌ ID ${id}: 失敗 - ${result.error || '不明'}`)
    }
    
    // レート制限対策
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  
  console.log(`  完了: 成功 ${batchResult.success}, 失敗 ${batchResult.failed}`)
  
  return batchResult
}

/**
 * テスト移行（ID 1-5）
 */
async function runTestMigration(): Promise<boolean> {
  console.log('\n🧪 テスト移行（ID 1-5）を実行中...')
  
  const testResult = await migrateBatch('example', 1, 5)
  
  if (testResult.failed > 0) {
    console.log('\n⚠️  テスト移行で失敗がありました')
    console.log('   続行しますか? (y/n)')
    // Note: 実際の対話処理は省略
    return false
  }
  
  console.log('\n✅ テスト移行成功！')
  return true
}

/**
 * 本番移行
 */
async function runFullMigration() {
  console.log('\n🚀 本番移行を開始します...\n')
  
  const allResults: BatchResult[] = []
  
  // 例文コンテンツの移行（バッチごと）
  console.log('📝 例文コンテンツの移行:')
  allResults.push(await migrateBatch('example', 1, 199))
  allResults.push(await migrateBatch('example', 200, 399))
  allResults.push(await migrateBatch('example', 400, 599))
  allResults.push(await migrateBatch('example', 600, 799))
  allResults.push(await migrateBatch('example', 800, 999))
  allResults.push(await migrateBatch('example', 1000, 1000))
  
  // 単語音声の移行
  console.log('\n🎵 単語音声の移行:')
  allResults.push(await migrateBatch('word', 1, 199))
  allResults.push(await migrateBatch('word', 200, 399))
  allResults.push(await migrateBatch('word', 400, 599))
  allResults.push(await migrateBatch('word', 600, 799))
  allResults.push(await migrateBatch('word', 800, 999))
  allResults.push(await migrateBatch('word', 1000, 1000))
  
  // サマリー
  const totalSuccess = allResults.reduce((sum, r) => sum + r.success, 0)
  const totalFailed = allResults.reduce((sum, r) => sum + r.failed, 0)
  const totalFiles = allResults.reduce((sum, r) => sum + r.total, 0)
  
  console.log('\n' + '='.repeat(50))
  console.log('📊 移行完了サマリー\n')
  console.log(`合計: ${totalFiles} ファイル`)
  console.log(`成功: ${totalSuccess}`)
  console.log(`失敗: ${totalFailed}`)
  console.log(`成功率: ${Math.round(totalSuccess / totalFiles * 100)}%`)
  
  if (totalFailed > 0) {
    console.log('\n⚠️  失敗したファイルがあります')
    console.log('   詳細はログを確認してください')
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('🚀 ストレージファイル移行スクリプト\n')
  console.log('=' .repeat(50))
  
  // 環境変数チェック
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('❌ 環境変数が設定されていません')
    Deno.exit(1)
  }
  
  console.log('\n⚠️  重要な注意事項:')
  console.log('  1. バックアップを取得済みですか?')
  console.log('  2. この操作は元に戻せません')
  console.log('  3. アプリがダウンタイムする可能性があります')
  console.log('\n続行する場合は、以下を実行してください:')
  console.log('  - テスト移行のみ: --test フラグを追加')
  console.log('  - 本番移行: --production フラグを追加')
  
  const args = Deno.args
  
  if (args.includes('--test')) {
    await runTestMigration()
  } else if (args.includes('--production')) {
    console.log('\n⚠️  本番移行を開始します（5秒後）...')
    await new Promise(resolve => setTimeout(resolve, 5000))
    await runFullMigration()
  } else {
    console.log('\n実行するには --test または --production フラグが必要です')
    Deno.exit(0)
  }
}

// スクリプト実行
if (import.meta.main) {
  main()
}

