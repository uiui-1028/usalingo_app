#!/usr/bin/env deno run --allow-net --allow-read --allow-env

/**
 * フォルダ分割数の移行スクリプト（200→500ファイル/フォルダ）
 * 
 * このスクリプトは、既存の200ファイル/フォルダ構造から
 * 500ファイル/フォルダ構造への移行を自動化します。
 * 
 * 使用方法:
 * 1. Supabase CLIがインストールされていることを確認
 * 2. プロジェクトにログイン: supabase login
 * 3. プロジェクトをリンク: supabase link --project-ref YOUR_PROJECT_REF
 * 4. このスクリプトを実行: deno run --allow-net --allow-read --allow-env 04_migrate_200_to_500_folders.ts
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

/**
 * 200ファイル/フォルダから500ファイル/フォルダへの移行マッピング
 */
function getMigrationMapping() {
  const mappings: Array<{
    oldFolder: string;
    newFolder: string;
    bucket: string;
  }> = [];

  // テーマリスト
  const themes = ['シンプル', 'ビジネス', 'カジュアル', 'アカデミック', '子供向け'];
  
  // content-images の移行マッピング
  themes.forEach(theme => {
    // 200ファイル/フォルダ: 0000-0199, 0200-0399, 0400-0599, 0600-0799, 0800-0999, 1000-1199
    // 500ファイル/フォルダ: 0000-0499, 0500-0999, 1000-1499
    const oldRanges = [
      { start: 0, end: 199, folder: '0000-0199' },
      { start: 200, end: 399, folder: '0200-0399' },
      { start: 400, end: 599, folder: '0400-0599' },
      { start: 600, end: 799, folder: '0600-0799' },
      { start: 800, end: 999, folder: '0800-0999' },
      { start: 1000, end: 1199, folder: '1000-1199' }
    ];

    const newRanges = [
      { start: 0, end: 499, folder: '0000-0499' },
      { start: 500, end: 999, folder: '0500-0999' },
      { start: 1000, end: 1499, folder: '1000-1499' }
    ];

    oldRanges.forEach(oldRange => {
      // どの新しいフォルダに移行するかを決定
      const newRange = newRanges.find(nr => 
        oldRange.start >= nr.start && oldRange.end <= nr.end
      );
      
      if (newRange) {
        mappings.push({
          oldFolder: `${theme}/${oldRange.folder}`,
          newFolder: `${theme}/${newRange.folder}`,
          bucket: 'content-images'
        });
      }
    });
  });

  // content-audio/example の移行マッピング
  themes.forEach(theme => {
    const oldRanges = [
      { start: 0, end: 199, folder: '0000-0199' },
      { start: 200, end: 399, folder: '0200-0399' },
      { start: 400, end: 599, folder: '0400-0599' },
      { start: 600, end: 799, folder: '0600-0799' },
      { start: 800, end: 999, folder: '0800-0999' },
      { start: 1000, end: 1199, folder: '1000-1199' }
    ];

    const newRanges = [
      { start: 0, end: 499, folder: '0000-0499' },
      { start: 500, end: 999, folder: '0500-0999' },
      { start: 1000, end: 1499, folder: '1000-1499' }
    ];

    oldRanges.forEach(oldRange => {
      const newRange = newRanges.find(nr => 
        oldRange.start >= nr.start && oldRange.end <= nr.end
      );
      
      if (newRange) {
        mappings.push({
          oldFolder: `example/${theme}/${oldRange.folder}`,
          newFolder: `example/${theme}/${newRange.folder}`,
          bucket: 'content-audio'
        });
      }
    });
  });

  // content-audio/word の移行マッピング（テーマなし）
  const oldRanges = [
    { start: 0, end: 199, folder: '0000-0199' },
    { start: 200, end: 399, folder: '0200-0399' },
    { start: 400, end: 599, folder: '0400-0599' },
    { start: 600, end: 799, folder: '0600-0799' },
    { start: 800, end: 999, folder: '0800-0999' },
    { start: 1000, end: 1199, folder: '1000-1199' }
  ];

  const newRanges = [
    { start: 0, end: 499, folder: '0000-0499' },
    { start: 500, end: 999, folder: '0500-0999' },
    { start: 1000, end: 1499, folder: '1000-1499' }
  ];

  oldRanges.forEach(oldRange => {
    const newRange = newRanges.find(nr => 
      oldRange.start >= nr.start && oldRange.end <= nr.end
    );
    
    if (newRange) {
      mappings.push({
        oldFolder: `word/${oldRange.folder}`,
        newFolder: `word/${newRange.folder}`,
        bucket: 'content-audio'
      });
    }
  });

  return mappings;
}

/**
 * フォルダ内のファイルを新しいフォルダに移動
 */
async function migrateFolderFiles(
  bucket: string, 
  oldFolder: string, 
  newFolder: string
): Promise<{ success: number; error: number; errors: string[] }> {
  console.log(`🔄 移行中: ${bucket}/${oldFolder} → ${bucket}/${newFolder}`);
  
  let successCount = 0;
  let errorCount = 0;
  const errors: string[] = [];

  try {
    // 古いフォルダ内のファイル一覧を取得
    const { data: files, error: listError } = await supabase.storage
      .from(bucket)
      .list(oldFolder);

    if (listError) {
      console.error(`❌ ファイル一覧取得エラー: ${listError.message}`);
      return { success: 0, error: 1, errors: [listError.message] };
    }

    if (!files || files.length === 0) {
      console.log(`ℹ️  フォルダが空です: ${bucket}/${oldFolder}`);
      return { success: 0, error: 0, errors: [] };
    }

    // 各ファイルを新しいフォルダに移動
    for (const file of files) {
      try {
        const oldPath = `${oldFolder}/${file.name}`;
        const newPath = `${newFolder}/${file.name}`;

        // ファイルをダウンロード
        const { data: fileData, error: downloadError } = await supabase.storage
          .from(bucket)
          .download(oldPath);

        if (downloadError) {
          console.error(`❌ ダウンロードエラー: ${oldPath} - ${downloadError.message}`);
          errorCount++;
          errors.push(`Download error: ${oldPath} - ${downloadError.message}`);
          continue;
        }

        // 新しいパスにアップロード
        const { error: uploadError } = await supabase.storage
          .from(bucket)
          .upload(newPath, fileData, {
            contentType: file.metadata?.mimetype || 'application/octet-stream',
            upsert: true
          });

        if (uploadError) {
          console.error(`❌ アップロードエラー: ${newPath} - ${uploadError.message}`);
          errorCount++;
          errors.push(`Upload error: ${newPath} - ${uploadError.message}`);
          continue;
        }

        // 古いファイルを削除
        const { error: deleteError } = await supabase.storage
          .from(bucket)
          .remove([oldPath]);

        if (deleteError) {
          console.error(`⚠️  削除エラー: ${oldPath} - ${deleteError.message}`);
          // 削除エラーは致命的ではないので、成功としてカウント
        }

        console.log(`✅ 移動完了: ${oldPath} → ${newPath}`);
        successCount++;

        // API制限を避けるため少し待機
        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (error) {
        console.error(`❌ ファイル処理エラー: ${file.name} - ${error.message}`);
        errorCount++;
        errors.push(`File processing error: ${file.name} - ${error.message}`);
      }
    }

  } catch (error) {
    console.error(`❌ フォルダ移行エラー: ${bucket}/${oldFolder} - ${error.message}`);
    errorCount++;
    errors.push(`Folder migration error: ${bucket}/${oldFolder} - ${error.message}`);
  }

  return { success: successCount, error: errorCount, errors };
}

/**
 * 空のフォルダを削除
 */
async function cleanupEmptyFolders(): Promise<void> {
  console.log('\n🧹 空のフォルダをクリーンアップ中...');
  
  const buckets = ['content-images', 'content-audio'];
  
  for (const bucket of buckets) {
    try {
      // バケット内の全フォルダを取得
      const { data: folders, error } = await supabase.storage
        .from(bucket)
        .list('', { limit: 1000 });

      if (error) {
        console.error(`❌ フォルダ一覧取得エラー: ${bucket} - ${error.message}`);
        continue;
      }

      if (!folders) continue;

      for (const folder of folders) {
        if (folder.name.startsWith('.')) continue; // 隠しフォルダをスキップ

        try {
          // フォルダ内のファイル数を確認
          const { data: files, error: listError } = await supabase.storage
            .from(bucket)
            .list(folder.name);

          if (listError) {
            console.error(`❌ ファイル一覧取得エラー: ${bucket}/${folder.name} - ${listError.message}`);
            continue;
          }

          // フォルダが空の場合、ダミーファイルを作成して削除（フォルダ削除）
          if (!files || files.length === 0) {
            const dummyFile = `.cleanup_${Date.now()}.tmp`;
            const dummyPath = `${folder.name}/${dummyFile}`;
            
            // ダミーファイルを作成
            await supabase.storage
              .from(bucket)
              .upload(dummyPath, new Uint8Array([0]), {
                contentType: 'application/octet-stream',
                upsert: true
              });

            // ダミーファイルを削除（フォルダも削除される）
            await supabase.storage
              .from(bucket)
              .remove([dummyPath]);

            console.log(`🗑️  空フォルダ削除: ${bucket}/${folder.name}`);
          }

        } catch (error) {
          console.error(`❌ フォルダクリーンアップエラー: ${bucket}/${folder.name} - ${error.message}`);
        }
      }

    } catch (error) {
      console.error(`❌ バケットクリーンアップエラー: ${bucket} - ${error.message}`);
    }
  }
}

/**
 * 移行結果のレポート生成
 */
function generateMigrationReport(results: Array<{
  oldFolder: string;
  newFolder: string;
  bucket: string;
  success: number;
  error: number;
  errors: string[];
}>): void {
  console.log('\n📊 移行結果レポート');
  console.log('==================');
  
  let totalSuccess = 0;
  let totalError = 0;
  const allErrors: string[] = [];

  results.forEach(result => {
    totalSuccess += result.success;
    totalError += result.error;
    allErrors.push(...result.errors);
    
    console.log(`📁 ${result.bucket}/${result.oldFolder} → ${result.bucket}/${result.newFolder}`);
    console.log(`   ✅ 成功: ${result.success}ファイル`);
    console.log(`   ❌ エラー: ${result.error}ファイル`);
    
    if (result.errors.length > 0) {
      console.log(`   🔍 エラー詳細:`);
      result.errors.forEach(error => console.log(`      - ${error}`));
    }
    console.log('');
  });

  console.log('📈 総合結果');
  console.log('===========');
  console.log(`✅ 総成功数: ${totalSuccess}ファイル`);
  console.log(`❌ 総エラー数: ${totalError}ファイル`);
  console.log(`📊 成功率: ${totalSuccess > 0 ? ((totalSuccess / (totalSuccess + totalError)) * 100).toFixed(2) : 0}%`);

  if (allErrors.length > 0) {
    console.log('\n🚨 エラー一覧');
    console.log('=============');
    allErrors.forEach((error, index) => {
      console.log(`${index + 1}. ${error}`);
    });
  }
}

/**
 * メイン処理
 */
async function main() {
  console.log('🎯 フォルダ分割数移行スクリプト（200→500ファイル/フォルダ）');
  console.log('============================================================');
  
  // 移行マッピングを取得
  const mappings = getMigrationMapping();
  console.log(`📋 移行対象: ${mappings.length}フォルダ`);
  
  // 確認プロンプト
  const confirm = Deno.args.includes('--confirm');
  if (!confirm) {
    console.log('\n⚠️  このスクリプトは既存のファイルを移動します。');
    console.log('実行するには --confirm フラグを追加してください。');
    console.log('例: deno run --allow-net --allow-read --allow-env 04_migrate_200_to_500_folders.ts --confirm');
    Deno.exit(0);
  }

  console.log('\n🚀 移行処理を開始します...');
  
  const results: Array<{
    oldFolder: string;
    newFolder: string;
    bucket: string;
    success: number;
    error: number;
    errors: string[];
  }> = [];

  // 各フォルダを移行
  for (const mapping of mappings) {
    const result = await migrateFolderFiles(
      mapping.bucket,
      mapping.oldFolder,
      mapping.newFolder
    );
    
    results.push({
      oldFolder: mapping.oldFolder,
      newFolder: mapping.newFolder,
      bucket: mapping.bucket,
      ...result
    });
  }

  // 空のフォルダをクリーンアップ
  await cleanupEmptyFolders();

  // 結果レポートを生成
  generateMigrationReport(results);

  console.log('\n🎉 移行処理が完了しました！');
  console.log('新しい500ファイル/フォルダ構造で運用を開始できます。');
}

// スクリプト実行
if (import.meta.main) {
  main().catch(console.error);
}
