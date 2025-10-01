import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface RenameOperation {
  action: string;
  bucket: string;
  old_path: string;
  new_path: string;
  source_table: string;
  record_id: number;
}

interface RenameResult {
  success: number;
  failed: number;
  errors: Array<{
    operation: RenameOperation;
    error: string;
  }>;
}

/**
 * 既存ファイルの命名規則対応リネーム処理のEdge Function
 * 
 * 処理フロー:
 * 1. データベースからリネーム対象のファイル情報を取得
 * 2. Supabase Storageでファイルをリネーム
 * 3. データベースのasset_pathを更新
 * 
 * 命名規則:
 * - 単語音声: word_{word_id}_{meaning_id}.mp3
 * - 例文音声: example_{example_id}.mp3
 * - 例文イラスト: example_{example_id}.webp
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

    const result: RenameResult = {
      success: 0,
      failed: 0,
      errors: []
    };

    // 1. リネーム対象のファイル情報を取得
    const { data: renameOperations, error: queryError } = await supabase
      .rpc('get_rename_operations');

    if (queryError) {
      throw new Error(`リネーム対象取得エラー: ${queryError.message}`);
    }

    if (!renameOperations || renameOperations.length === 0) {
      return new Response(JSON.stringify({
        message: 'リネーム対象のファイルがありません。',
        result: result
      }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`リネーム対象: ${renameOperations.length}件`);

    // 2. 各ファイルをリネーム
    for (const operation of renameOperations) {
      try {
        console.log(`リネーム中: ${operation.old_path} → ${operation.new_path}`);

        // Supabase Storageでファイルをコピー
        const { data: copyData, error: copyError } = await supabase.storage
          .from(operation.bucket)
          .copy(operation.old_path, operation.new_path);

        if (copyError) {
          throw new Error(`ファイルコピーエラー: ${copyError.message}`);
        }

        // 元ファイルを削除
        const { error: deleteError } = await supabase.storage
          .from(operation.bucket)
          .remove([operation.old_path]);

        if (deleteError) {
          console.warn(`元ファイル削除エラー（無視）: ${deleteError.message}`);
        }

        // データベースのasset_pathを更新
        let updateError;
        if (operation.source_table === 'word_meanings') {
          const { error } = await supabase
            .from('word_meanings')
            .update({ audio_asset_path: operation.new_path })
            .eq('id', operation.record_id);
          updateError = error;
        } else if (operation.source_table === 'example_contents') {
          // illustration_asset_pathまたはaudio_asset_pathを更新
          const updateData: any = {};
          if (operation.bucket === 'content-images') {
            updateData.illustration_asset_path = operation.new_path;
          } else if (operation.bucket === 'content-audio') {
            updateData.audio_asset_path = operation.new_path;
          }

          const { error } = await supabase
            .from('example_contents')
            .update(updateData)
            .eq('id', operation.record_id);
          updateError = error;
        }

        if (updateError) {
          throw new Error(`データベース更新エラー: ${updateError.message}`);
        }

        result.success++;
        console.log(`✅ 成功: ${operation.old_path} → ${operation.new_path}`);

      } catch (error) {
        result.failed++;
        result.errors.push({
          operation: operation,
          error: error.message
        });
        console.error(`❌ 失敗: ${operation.old_path} - ${error.message}`);
      }
    }

    return new Response(JSON.stringify({
      message: 'ファイルリネーム処理が完了しました。',
      result: result,
      summary: {
        total: renameOperations.length,
        success: result.success,
        failed: result.failed,
        success_rate: `${Math.round((result.success / renameOperations.length) * 100)}%`
      }
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('リネーム処理エラー:', error);
    return new Response(JSON.stringify({ 
      error: error.message,
      message: 'ファイルリネーム処理中にエラーが発生しました。'
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
