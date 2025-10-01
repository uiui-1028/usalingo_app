import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface AssetRecord {
  id: number;
  illustration_url?: string;
  audio_url?: string;
  illustration_asset_path?: string;
  audio_asset_path?: string;
}

interface ProcessingResult {
  processed: number;
  skipped: number;
  errors: Array<{
    recordId: number;
    fileName: string;
    error: string;
  }>;
}

/**
 * アセット紐付け処理のEdge Function
 * 
 * 処理フロー:
 * 1. word_meaningsとexample_contentsテーブルから未処理レコードを取得
 * 2. asset-inboxバケットからファイルを検索
 * 3. ファイルをpublicバケットに移動
 * 4. データベースのasset_pathカラムを更新
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

    const result: ProcessingResult = {
      processed: 0,
      skipped: 0,
      errors: []
    };

    // 1. word_meaningsテーブルの未処理レコードを取得
    const { data: wordMeanings, error: wmError } = await supabase
      .from('word_meanings')
      .select('id, audio_url, audio_asset_path')
      .or('audio_asset_path.is.null,and(audio_url.not.is.null)');

    if (wmError) {
      throw new Error(`word_meanings取得エラー: ${wmError.message}`);
    }

    // 2. example_contentsテーブルの未処理レコードを取得
    const { data: exampleContents, error: ecError } = await supabase
      .from('example_contents')
      .select('id, illustration_url, audio_url, illustration_asset_path, audio_asset_path')
      .or('illustration_asset_path.is.null,and(illustration_url.not.is.null),audio_asset_path.is.null,and(audio_url.not.is.null)');

    if (ecError) {
      throw new Error(`example_contents取得エラー: ${ecError.message}`);
    }

    console.log(`処理対象: word_meanings ${wordMeanings?.length || 0}件, example_contents ${exampleContents?.length || 0}件`);

    // 3. word_meaningsの音声ファイルを処理
    if (wordMeanings) {
      for (const record of wordMeanings) {
        if (record.audio_url && !record.audio_asset_path) {
          try {
            const success = await processAsset(
              supabase,
              'asset-inbox',
              'public',
              record.audio_url,
              'word_meanings',
              record.id,
              'audio_asset_path'
            );
            
            if (success) {
              result.processed++;
            } else {
              result.skipped++;
            }
          } catch (error) {
            result.errors.push({
              recordId: record.id,
              fileName: record.audio_url,
              error: error.message
            });
            result.skipped++;
          }
        }
      }
    }

    // 4. example_contentsの画像・音声ファイルを処理
    if (exampleContents) {
      for (const record of exampleContents) {
        // イラスト画像の処理
        if (record.illustration_url && !record.illustration_asset_path) {
          try {
            const success = await processAsset(
              supabase,
              'asset-inbox',
              'public',
              record.illustration_url,
              'example_contents',
              record.id,
              'illustration_asset_path'
            );
            
            if (success) {
              result.processed++;
            } else {
              result.skipped++;
            }
          } catch (error) {
            result.errors.push({
              recordId: record.id,
              fileName: record.illustration_url,
              error: error.message
            });
            result.skipped++;
          }
        }

        // 音声ファイルの処理
        if (record.audio_url && !record.audio_asset_path) {
          try {
            const success = await processAsset(
              supabase,
              'asset-inbox',
              'public',
              record.audio_url,
              'example_contents',
              record.id,
              'audio_asset_path'
            );
            
            if (success) {
              result.processed++;
            } else {
              result.skipped++;
            }
          } catch (error) {
            result.errors.push({
              recordId: record.id,
              fileName: record.audio_url,
              error: error.message
            });
            result.skipped++;
          }
        }
      }
    }

    // 処理結果を返す
    return new Response(JSON.stringify({
      success: true,
      message: 'アセット紐付け処理が完了しました',
      result
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });

  } catch (error) {
    console.error('アセット紐付け処理エラー:', error);
    
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
 * 個別アセットの処理関数
 */
async function processAsset(
  supabase: any,
  sourceBucket: string,
  targetBucket: string,
  fileName: string,
  tableName: string,
  recordId: number,
  assetPathColumn: string
): Promise<boolean> {
  try {
    // 1. asset-inboxバケットからファイルを検索
    const { data: files, error: listError } = await supabase.storage
      .from(sourceBucket)
      .list('', {
        search: fileName
      });

    if (listError) {
      throw new Error(`ファイル検索エラー: ${listError.message}`);
    }

    // ファイルが見つからない場合はスキップ
    if (!files || files.length === 0) {
      console.log(`ファイルが見つかりません: ${fileName}`);
      return false;
    }

    // 完全一致するファイルを検索
    const targetFile = files.find((file: any) => file.name === fileName);
    if (!targetFile) {
      console.log(`完全一致するファイルが見つかりません: ${fileName}`);
      return false;
    }

    const sourcePath = `${sourceBucket}/${fileName}`;
    const targetPath = `${targetBucket}/${fileName}`;

    // 2. ファイルをpublicバケットにコピー
    const { data: copyData, error: copyError } = await supabase.storage
      .from(sourceBucket)
      .copy(fileName, `${targetBucket}/${fileName}`);

    if (copyError) {
      throw new Error(`ファイルコピーエラー: ${copyError.message}`);
    }

    // 3. データベースのasset_pathカラムを更新
    const updateData: any = {};
    updateData[assetPathColumn] = `${targetBucket}/${fileName}`;

    const { error: updateError } = await supabase
      .from(tableName)
      .update(updateData)
      .eq('id', recordId);

    if (updateError) {
      throw new Error(`データベース更新エラー: ${updateError.message}`);
    }

    // 4. asset-inboxからファイルを削除
    const { error: deleteError } = await supabase.storage
      .from(sourceBucket)
      .remove([fileName]);

    if (deleteError) {
      console.warn(`ファイル削除エラー（処理は継続）: ${deleteError.message}`);
    }

    console.log(`処理完了: ${fileName} -> ${targetPath}`);
    return true;

  } catch (error) {
    console.error(`アセット処理エラー (${fileName}):`, error);
    throw error;
  }
}
