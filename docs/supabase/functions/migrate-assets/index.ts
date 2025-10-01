import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface MigrationResult {
  sourceBucket: string;
  targetBucket: string;
  movedCount: number;
  errorCount: number;
  errors: string[];
}

/**
 * 既存のStorageバケットからasset-inboxにファイルを移動するEdge Function
 */
Deno.serve(async (req: Request) => {
  try {
    // CORS設定
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      });
    }

    // Supabaseクライアントの初期化
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const results: MigrationResult[] = [];

    // 1. content-imagesバケットのファイルを移動
    const imagesResult = await migrateBucketFiles(
      supabase,
      'content-images',
      'asset-inbox',
      50 // 一度に50ファイルずつ処理
    );
    results.push(imagesResult);

    // 2. content-audioバケットのファイルを移動
    const audioResult = await migrateBucketFiles(
      supabase,
      'content-audio',
      'asset-inbox',
      50 // 一度に50ファイルずつ処理
    );
    results.push(audioResult);

    // 処理結果を返す
    return new Response(JSON.stringify({
      success: true,
      message: 'ファイル移行処理が完了しました',
      results
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });

  } catch (error) {
    console.error('ファイル移行処理エラー:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
});

/**
 * バケット間でファイルを移動する関数
 */
async function migrateBucketFiles(
  supabase: any,
  sourceBucket: string,
  targetBucket: string,
  batchSize: number
): Promise<MigrationResult> {
  const result: MigrationResult = {
    sourceBucket,
    targetBucket,
    movedCount: 0,
    errorCount: 0,
    errors: []
  };

  try {
    // 1. ソースバケットのファイル一覧を取得
    const { data: files, error: listError } = await supabase.storage
      .from(sourceBucket)
      .list('', {
        limit: batchSize
      });

    if (listError) {
      throw new Error(`ファイル一覧取得エラー: ${listError.message}`);
    }

    if (!files || files.length === 0) {
      console.log(`${sourceBucket}バケットは空です`);
      return result;
    }

    console.log(`${sourceBucket}から${files.length}ファイルを処理します`);

    // 2. 各ファイルを移動
    for (const file of files) {
      try {
        // ファイルをダウンロード
        const { data: fileData, error: downloadError } = await supabase.storage
          .from(sourceBucket)
          .download(file.name);

        if (downloadError) {
          throw new Error(`ファイルダウンロードエラー: ${downloadError.message}`);
        }

        // ファイルをターゲットバケットにアップロード
        const { error: uploadError } = await supabase.storage
          .from(targetBucket)
          .upload(file.name, fileData, {
            contentType: file.metadata?.mimetype || 'application/octet-stream'
          });

        if (uploadError) {
          throw new Error(`ファイルアップロードエラー: ${uploadError.message}`);
        }

        // ソースファイルを削除
        const { error: deleteError } = await supabase.storage
          .from(sourceBucket)
          .remove([file.name]);

        if (deleteError) {
          console.warn(`ファイル削除エラー（処理は継続）: ${deleteError.message}`);
        }

        result.movedCount++;
        console.log(`移動完了: ${file.name}`);

      } catch (error) {
        result.errorCount++;
        result.errors.push(`${file.name}: ${error.message}`);
        console.error(`ファイル移動エラー (${file.name}):`, error);
      }
    }

  } catch (error) {
    result.errorCount++;
    result.errors.push(`バッチ処理エラー: ${error.message}`);
    console.error(`バッチ処理エラー:`, error);
  }

  return result;
}
