# 公式教材50語の画像・音声をStorageへ登録する手順

対象: USL-288 / TARGET-1900の原本番号1〜50

## 結論

画像50枚、単語音声50本、例文音声50本を一時領域へ変換し、150件すべての形式、寸法、
長さ、容量、SHA-256を検査してから登録します。登録処理は既存objectを上書きせず、公開URLを
ログインなしで読み戻してSHA-256が一致した場合だけ、DBのmedia状態を `present` にできます。

USL-284の権利確認が `done` になる前は、本番Storageや本番DBへ実行しません。本番実行時は
StorageアップロードとDB更新を別の変更として扱い、各操作の対象と切り戻し方法を示して
明示承認を得ます。service role key、原本、中間JSON、変換済みmedia、manifest、receipt、
生成SQLはGitへ追加しません。

## 変換と検査の契約

| 種類 | 件数 | 変換後 | 1件の上限 | 長さの上限 |
|---|---:|---|---:|---:|
| 例文画像 | 50 | 768×432 WebP、品質80、metadata除去 | 200 KiB | — |
| 単語音声 | 50 | mono、44.1 kHz、64 kbps MP3、metadata除去 | 40 KiB | 5秒 |
| 例文音声 | 50 | mono、44.1 kHz、64 kbps MP3、metadata除去 | 96 KiB | 12秒 |

原本画像50枚はすべて16:9で、3:4の黒い枠へ収めるとSwiftUIの `scaledToFit` 表示で絵が
小さくなります。このため、[`usl-288-preserve-source-aspect.md`](../decisions/usl-288-preserve-source-aspect.md)
の判断どおり、内容を切り落とさず16:9へ正規化します。再生成や内容の描き換えは行いません。
音声の長さは無音を含む全体で上限以下を要求するため、USL-283より厳しい検査です。
上限超過、欠落、重複path、不正な拡張子はmanifestへまとめて記録し、登録前に停止します。
変換には `ffmpeg`、`ffprobe`、`cwebp` が必要です。起動前に各commandが見つかることを
確認し、見つからない場合は変換を始めません。

## 1. Ankiの読取用コピーと中間JSONを作る

Ankiを終了し、[`import-official-content.md`](import-official-content.md) の手順で
`/private/tmp/usalingo-288-content.json` を作ります。`errors=0` と
`valid: 50 entries...` の両方を確認します。

## 2. 150件を一時領域へ変換する

出力先は空の専用directoryにします。既存ファイルがあるdirectoryへは書きません。

```sh
python3 scripts/prepare-official-media.py stage \
  --input /private/tmp/usalingo-288-content.json \
  --media-dir "$HOME/Library/Application Support/Anki2/Anki｜Taiga（taiyahehe）/collection.media" \
  --output-dir /private/tmp/usalingo-288-media
```

合格時は `staged=150/150` と `errors=0` が表示され、
`/private/tmp/usalingo-288-media/manifest.json` に150件のpath、形式、寸法または長さ、容量、
SHA-256が入ります。失敗時はmanifestの `errors` が欠落・違反一覧です。

## 3. ローカルStorageへ登録して匿名で読み戻す

ローカルSupabaseをStorage API込みで起動します。別作業が同じlocal projectを使っていないことを
先に確認します。CLIの現在の出力名を使い、秘密値を画面や文書へコピーしません。

```sh
supabase start
eval "$(supabase status -o env | grep -E '^(API_URL|SERVICE_ROLE_KEY)=')"
export SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"

python3 scripts/prepare-official-media.py sync \
  --manifest /private/tmp/usalingo-288-media/manifest.json \
  --asset-root /private/tmp/usalingo-288-media \
  --supabase-url "$API_URL" \
  --receipt /private/tmp/usalingo-288-local-receipt.json
```

`sync` は公開URLを先に調べます。objectがなければ新規登録し、同じSHA-256なら再利用し、異なる
内容が同じpathにあれば上書きせず停止します。登録後はAPI keyを付けないGETで150件を読み、
HTTP 200、MIME、`cache-control=3600`、SHA-256を確認します。

## 4. ローカルDBの状態を `present` にする

先にUSL-286の生成SQLをローカルDBへ入れます。その後、読戻しreceiptに対応する状態更新SQLを
作ります。receiptが150件未満、またはmanifestと違う場合はSQLを作れません。

```sh
python3 scripts/prepare-official-media.py render-state-sql \
  --manifest /private/tmp/usalingo-288-media/manifest.json \
  --receipt /private/tmp/usalingo-288-local-receipt.json \
  --output /private/tmp/usalingo-288-media-present.sql

docker cp /private/tmp/usalingo-288-media-present.sql \
  supabase_db_usalingo-local:/tmp/usalingo-288-media-present.sql
docker exec supabase_db_usalingo-local \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/usalingo-288-media-present.sql
```

生成SQLは固定IDとStorage pathが全件一致することを先に確認し、違えばtransaction全体を停止します。
一致した50画像、50単語音声、50例文音声の状態だけを `present` にします。

## 5. 本番実行前の停止線

次が全部そろうまで本番へ書きません。

- USL-284が `done` で、50語150素材の公開可否と表示条件が確定している
- 本番bucketが `content-images` / `content-audio` の公開読取契約と一致している
- 本番DBの対象固定ID・pathに衝突がなく、投入対象行が確定している
- Storage 150件の新規path、合計容量、切り戻し対象を示し、アップロード承認を得ている
- DB更新行と旧値、rollback SQLを示し、DB書き込み承認を得ている

承認後に限り、`sync` へ本番URLと `--allow-remote` を渡します。既存objectの削除・上書き、
bucket設定変更、policy変更はこのコマンドでは行いません。途中失敗時は同じmanifestで再実行でき、
一致済みobjectは再利用します。参照前の新規objectを削除する必要がある場合は、正確な一覧を示して
別途削除承認を得ます。

## 6. 完了確認

- manifest: 画像50、単語音声50、例文音声50、errors 0
- receipt: anonymous GET成功150、manifestとSHA-256一致150
- DB: 50件の `image_state`、50件の単語 `audio_state`、50件の例文 `audio_state` が `present`
- アプリ: 認証利用者のカードから画像・例文音声を取得できる
- 未認証: 公式DBは読めないが、既知の公開media URLは契約どおり取得できる

ローカル確認は本番配信の証明ではありません。本番完了は、本番receipt、DB検証、再起動した
実機アプリでの画像表示・単語音声・例文音声確認を分けて記録します。
