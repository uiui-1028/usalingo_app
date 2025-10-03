#!/usr/bin/env deno run --allow-net --allow-read --allow-env

/**
 * Supabase CLIを活用したフォルダーツリー自動作成スクリプト
 * 
 * このスクリプトは、Supabase CLIの自動フォルダ作成機能を活用して
 * 必要なフォルダ構造を一括で作成します。
 * 
 * 使用方法:
 * 1. Supabase CLIがインストールされていることを確認
 * 2. プロジェクトにログイン: supabase login
 * 3. プロジェクトをリンク: supabase link --project-ref YOUR_PROJECT_REF
 * 4. このスクリプトを実行: deno run --allow-net --allow-read --allow-env 03_create_folder_tree.ts
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// 設定
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('❌ SUPABASE_URL と SUPABASE_ANON_KEY の環境変数を設定してください');
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// フォルダ構造の定義（現在のデータベースから生成）
const FOLDER_STRUCTURE = [
  // content-images フォルダ
  { bucket: 'content-images', path: 'シンプル/0000-0499' },
  { bucket: 'content-images', path: 'シンプル/0500-0999' },
  { bucket: 'content-images', path: 'シンプル/1000-1499' },
  
  // content-audio/example フォルダ
  { bucket: 'content-audio', path: 'example/シンプル/0000-0499' },
  { bucket: 'content-audio', path: 'example/シンプル/0500-0999' },
  { bucket: 'content-audio', path: 'example/シンプル/1000-1499' },
  
  // content-audio/word フォルダ
  { bucket: 'content-audio', path: 'word/0000-0499' },
  { bucket: 'content-audio', path: 'word/0500-0999' },
  { bucket: 'content-audio', path: 'word/1000-1499' },
];

// 将来のテーマ拡張用のフォルダ構造
const FUTURE_THEMES = ['ビジネス', 'カジュアル', 'アカデミック', '子供向け'];

const FUTURE_FOLDER_STRUCTURE = FUTURE_THEMES.flatMap(theme => [
  // content-images
  { bucket: 'content-images', path: `${theme}/0000-0499` },
  { bucket: 'content-images', path: `${theme}/0500-0999` },
  { bucket: 'content-images', path: `${theme}/1000-1499` },
  
  // content-audio/example
  { bucket: 'content-audio', path: `example/${theme}/0000-0499` },
  { bucket: 'content-audio', path: `example/${theme}/0500-0999` },
  { bucket: 'content-audio', path: `example/${theme}/1000-1499` },
]);

/**
 * ダミーファイルを作成してフォルダ構造を生成
 */
async function createFolderStructure(folders: Array<{bucket: string, path: string}>, isFuture = false) {
  console.log(`\n🚀 ${isFuture ? '将来用' : '現在用'}フォルダ構造の作成を開始...`);
  
  let successCount = 0;
  let errorCount = 0;
  
  for (const folder of folders) {
    try {
      // ダミー画像ファイルの内容（1x1ピクセルのPNG）
      const dummyPngData = new Uint8Array([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
        0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x37, 0x6E, 0xF9, 0x24, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);
      
      // ダミーファイルをアップロード（フォルダが自動作成される）
      const fileName = `.folder_placeholder_${Date.now()}.png`;
      const filePath = `${folder.path}/${fileName}`;
      
      const { data, error } = await supabase.storage
        .from(folder.bucket)
        .upload(filePath, dummyPngData, {
          contentType: 'image/png',
          upsert: false
        });
      
      if (error) {
        console.error(`❌ フォルダ作成失敗: ${folder.bucket}/${folder.path} - ${error.message}`);
        errorCount++;
      } else {
        console.log(`✅ フォルダ作成成功: ${folder.bucket}/${folder.path}`);
        successCount++;
        
        // ダミーファイルを削除（フォルダは残る）
        await supabase.storage
          .from(folder.bucket)
          .remove([filePath]);
      }
      
      // API制限を避けるため少し待機
      await new Promise(resolve => setTimeout(resolve, 100));
      
    } catch (error) {
      console.error(`❌ エラー: ${folder.bucket}/${folder.path} - ${error.message}`);
      errorCount++;
    }
  }
  
  console.log(`\n📊 ${isFuture ? '将来用' : '現在用'}フォルダ作成結果:`);
  console.log(`   ✅ 成功: ${successCount}フォルダ`);
  console.log(`   ❌ 失敗: ${errorCount}フォルダ`);
  
  return { successCount, errorCount };
}

/**
 * Supabase CLIコマンドを生成
 */
function generateSupabaseCLICommands(folders: Array<{bucket: string, path: string}>) {
  console.log('\n📋 Supabase CLIコマンド（手動実行用）:');
  console.log('以下のコマンドを順次実行してください:\n');
  
  const commands: string[] = [];
  
  for (const folder of folders) {
    // ダミーファイルを作成
    const dummyFile = `dummy_${Date.now()}.png`;
    const localPath = `./temp/${dummyFile}`;
    const remotePath = `${folder.path}/${dummyFile}`;
    
    // ローカルにダミーPNGファイルを作成
    commands.push(`echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > ${localPath}`);
    
    // Supabaseにアップロード（フォルダが自動作成される）
    commands.push(`supabase storage cp ${localPath} ${folder.bucket}/${remotePath}`);
    
    // ダミーファイルを削除
    commands.push(`supabase storage rm ${folder.bucket}/${remotePath}`);
    commands.push(`rm ${localPath}`);
    commands.push('');
  }
  
  commands.forEach(cmd => console.log(cmd));
  
  // 一時ディレクトリのクリーンアップ
  console.log('rmdir ./temp 2>/dev/null || true');
}

/**
 * メイン処理
 */
async function main() {
  console.log('🎯 Supabase CLIを活用したフォルダーツリー自動作成');
  console.log('================================================');
  
  // 現在のフォルダ構造を作成
  const currentResult = await createFolderStructure(FOLDER_STRUCTURE, false);
  
  // 将来用のフォルダ構造を作成（オプション）
  const createFuture = Deno.args.includes('--include-future');
  let futureResult = { successCount: 0, errorCount: 0 };
  
  if (createFuture) {
    futureResult = await createFolderStructure(FUTURE_FOLDER_STRUCTURE, true);
  }
  
  // 結果サマリー
  console.log('\n🎉 フォルダーツリー作成完了!');
  console.log('================================');
  console.log(`📁 現在用フォルダ: ${currentResult.successCount}個作成`);
  if (createFuture) {
    console.log(`📁 将来用フォルダ: ${futureResult.successCount}個作成`);
  }
  console.log(`❌ エラー: ${currentResult.errorCount + futureResult.errorCount}個`);
  
  // Supabase CLIコマンドも生成
  generateSupabaseCLICommands(FOLDER_STRUCTURE);
  
  console.log('\n💡 使用方法:');
  console.log('  現在用のみ: deno run --allow-net --allow-read --allow-env 03_create_folder_tree.ts');
  console.log('  将来用も含む: deno run --allow-net --allow-read --allow-env 03_create_folder_tree.ts --include-future');
}

// スクリプト実行
if (import.meta.main) {
  main().catch(console.error);
}
