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
 * アセット紐付け処理のEdge Function（命名規則対応版）
 * 
 * 処理フロー:
 * 1. word_meaningsとexample_contentsテーブルから未処理レコードを取得
 * 2. 命名規則に基づいてasset_pathを生成
 * 3. asset_pathカラムを更新
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

    const result: ProcessingResult = {
      processed: 0,
      skipped: 0,
      errors: []
    };

    // 1. word_meaningsテーブルの未処理レコードを取得（word_idも含む）
    const { data: wordMeanings, error: wmError } = await supabase
      .from('word_meanings')
      .select('id, word_id, audio_url, audio_asset_path')
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

    // 3. word_meaningsの音声ファイルを処理（命名規則適用）
    if (wordMeanings) {
      for (const record of wordMeanings) {
        if (record.audio_url && !record.audio_asset_path) {
          try {
            // 命名規則: word_{word_id}_{meaning_id}.mp3
            const assetPath = `content-audio/word_${record.word_id}_${record.id}.mp3`;
            
            const { error: updateError } = await supabase
              .from('word_meanings')
              .update({ audio_asset_path: assetPath })
              .eq('id', record.id);
            
            if (updateError) {
              result.errors.push({
                recordId: record.id,
                fileName: record.audio_url,
                error: updateError.message
              });
              result.skipped++;
            } else {
              result.processed++;
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
              'content-images',
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
              'content-audio',
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
      message: 'アセット紐付け処理が完了しました（既存バケット参照方式）',
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
 * 個別アセットの処理関数（既存バケット参照方式）
 */
async function processAsset(
  supabase: any,
  bucketName: string,
  fileName: string,
  tableName: string,
  recordId: number,
  assetPathColumn: string
): Promise<boolean> {
  try {
    // 1. 既存バケットからファイルを検索
    const { data: files, error: listError } = await supabase.storage
      .from(bucketName)
      .list('', {
        search: fileName
      });

    if (listError) {
      throw new Error(`ファイル検索エラー: ${listError.message}`);
    }

    // ファイルが見つからない場合はスキップ
    if (!files || files.length === 0) {
      console.log(`ファイルが見つかりません: ${fileName} in ${bucketName}`);
      return false;
    }

    // 完全一致するファイルを検索
    const targetFile = files.find((file: any) => file.name === fileName);
    if (!targetFile) {
      console.log(`完全一致するファイルが見つかりません: ${fileName} in ${bucketName}`);
      return false;
    }

    // 2. データベースのasset_pathカラムを更新
    const assetPath = `${bucketName}/${fileName}`;
    const updateData: any = {};
    updateData[assetPathColumn] = assetPath;

    const { error: updateError } = await supabase
      .from(tableName)
      .update(updateData)
      .eq('id', recordId);

    if (updateError) {
      throw new Error(`データベース更新エラー: ${updateError.message}`);
    }

    console.log(`処理完了: ${fileName} -> ${assetPath}`);
    return true;

  } catch (error) {
    console.error(`アセット処理エラー (${fileName}):`, error);
    throw error;
  }
}
