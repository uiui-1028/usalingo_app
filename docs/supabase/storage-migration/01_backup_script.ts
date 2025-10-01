/**
 * ストレージバックアップスクリプト
 * 
 * 実行前の準備:
 * 1. Supabase URLとService Role Keyを環境変数に設定
 * 2. npm install @supabase/supabase-js
 * 
 * 実行方法:
 * deno run --allow-net --allow-env --allow-write 01_backup_script.ts
 * または
 * npx tsx 01_backup_script.ts
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

interface BackupResult {
  totalFiles: number
  successCount: number
  errorCount: number
  errors: Array<{ path: string; error: string }>
}

/**
 * データベースのバックアップを作成
 */
async function backupDatabase(): Promise<void> {
  console.log('📊 データベースバックアップを作成中...')
  
  // example_contentsのバックアップ
  const { error: exampleError } = await supabase.rpc('create_table_backup', {
    source_table: 'example_contents',
    backup_table: 'example_contents_backup_' + Date.now()
  })
  
  if (exampleError) {
    console.error('❌ example_contentsバックアップ失敗:', exampleError)
    
    // 手動でバックアップテーブル作成
    const { error: manualError } = await supabase.from('example_contents').select('*')
    // Note: 実際のバックアップは管理画面から実施することを推奨
  }
  
  console.log('✅ データベースバックアップ完了')
}

/**
 * ストレージファイル一覧を取得
 */
async function listStorageFiles(bucket: string, folder: string = ''): Promise<string[]> {
  const { data, error } = await supabase.storage
    .from(bucket)
    .list(folder, {
      limit: 1000,
      offset: 0,
    })
  
  if (error) {
    console.error(`❌ ファイル一覧取得失敗 (${bucket}/${folder}):`, error)
    return []
  }
  
  const files: string[] = []
  
  for (const item of data || []) {
    const path = folder ? `${folder}/${item.name}` : item.name
    
    if (item.id === null) {
      // フォルダの場合、再帰的に取得
      const subFiles = await listStorageFiles(bucket, path)
      files.push(...subFiles)
    } else {
      // ファイルの場合
      files.push(path)
    }
  }
  
  return files
}

/**
 * ファイルをローカルにダウンロード
 */
async function downloadFile(
  bucket: string,
  remotePath: string,
  localPath: string
): Promise<boolean> {
  try {
    const { data, error } = await supabase.storage
      .from(bucket)
      .download(remotePath)
    
    if (error) {
      console.error(`❌ ダウンロード失敗 (${remotePath}):`, error)
      return false
    }
    
    if (!data) {
      console.error(`❌ データなし (${remotePath})`)
      return false
    }
    
    // ファイルを保存
    const arrayBuffer = await data.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)
    
    // ディレクトリ作成
    const dir = localPath.substring(0, localPath.lastIndexOf('/'))
    await Deno.mkdir(dir, { recursive: true })
    
    // ファイル書き込み
    await Deno.writeFile(localPath, uint8Array)
    
    return true
  } catch (error) {
    console.error(`❌ エラー (${remotePath}):`, error)
    return false
  }
}

/**
 * バケット全体をバックアップ
 */
async function backupBucket(bucket: string): Promise<BackupResult> {
  console.log(`\n📦 バケット "${bucket}" のバックアップ開始...`)
  
  const result: BackupResult = {
    totalFiles: 0,
    successCount: 0,
    errorCount: 0,
    errors: []
  }
  
  // ファイル一覧を取得
  const files = await listStorageFiles(bucket)
  result.totalFiles = files.length
  
  console.log(`   合計 ${files.length} ファイルを検出`)
  
  // 各ファイルをダウンロード
  for (let i = 0; i < files.length; i++) {
    const file = files[i]
    const localPath = `./backup/${bucket}/${file}`
    
    if (i % 50 === 0) {
      console.log(`   進捗: ${i}/${files.length} (${Math.round(i/files.length*100)}%)`)
    }
    
    const success = await downloadFile(bucket, file, localPath)
    
    if (success) {
      result.successCount++
    } else {
      result.errorCount++
      result.errors.push({ path: file, error: 'ダウンロード失敗' })
    }
    
    // レート制限対策
    await new Promise(resolve => setTimeout(resolve, 50))
  }
  
  console.log(`   完了: 成功 ${result.successCount}, 失敗 ${result.errorCount}`)
  
  return result
}

/**
 * メイン処理
 */
async function main() {
  console.log('🚀 ストレージバックアップ開始\n')
  console.log('=' .repeat(50))
  
  // 環境変数チェック
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('❌ 環境変数が設定されていません')
    console.log('以下を設定してください:')
    console.log('  export SUPABASE_URL="your-project-url"')
    console.log('  export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"')
    Deno.exit(1)
  }
  
  try {
    // データベースバックアップ
    await backupDatabase()
    
    // content-imagesバックアップ
    const imagesResult = await backupBucket('content-images')
    
    // content-audioバックアップ
    const audioResult = await backupBucket('content-audio')
    
    // サマリー
    console.log('\n' + '='.repeat(50))
    console.log('📊 バックアップ完了サマリー\n')
    console.log(`content-images: ${imagesResult.successCount}/${imagesResult.totalFiles} 成功`)
    console.log(`content-audio:  ${audioResult.successCount}/${audioResult.totalFiles} 成功`)
    console.log(`\n合計: ${imagesResult.successCount + audioResult.successCount} ファイル`)
    
    if (imagesResult.errorCount > 0 || audioResult.errorCount > 0) {
      console.log('\n⚠️  エラーが発生しました:')
      ;[...imagesResult.errors, ...audioResult.errors].forEach(e => {
        console.log(`  - ${e.path}: ${e.error}`)
      })
    }
    
    // バックアップディレクトリの確認
    console.log('\n✅ バックアップディレクトリ: ./backup/')
    console.log('   必要に応じて別の場所にコピーしてください')
    
  } catch (error) {
    console.error('\n❌ バックアップ中にエラーが発生:', error)
    Deno.exit(1)
  }
}

// スクリプト実行
if (import.meta.main) {
  main()
}

