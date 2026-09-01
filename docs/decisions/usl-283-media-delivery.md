# USL-283 画像・音声の置き場所と運び方

決定日: 2026-09-01

対象: TARGET-1900由来の公式教材50語と、将来の全1900語

## 結論

公式教材の画像・単語音声・例文音声は、**Supabase Storageだけに置く**。
アプリ本体への同梱と、同梱・Storageの二重管理は採用しない。

`content-images` と `content-audio` の公開bucketを配信元にし、DBには完全URLではなく
Storage相対パスを保存する。アップロードはiOSアプリ外の信頼済み処理だけが行い、
アプリは公開URLから読み取る。素材の公開可否はUSL-284で確認し、確認前は本番へ運ばない。

## 選んだ理由

| 案 | アプリ容量 | 初回通信 | 差し替え | 管理 | 判定 |
|---|---:|---:|---|---|---|
| アプリへ同梱 | 50語で約9.2 MiB、1900語で約349 MiB増える | 不要 | App Store更新が必要 | 1か所 | 不採用 |
| Supabase Storage | ほぼ増えない | 必要 | ファイルとDBを運営側で更新できる | 1か所 | **採用** |
| 50語だけ同梱し残りはStorage | 約9.2 MiB増える | 一部不要 | 2経路をそろえる必要がある | 2か所 | 不採用 |

現行SwiftUIはStorage相対パスを公開URLへ変換でき、既存の公式コンテンツ契約も公開bucketを
正本にしている。将来の端末キャッシュはUSL-290で扱い、配信元を二重化する理由にはしない。
アプリ起動時に全mediaを一括取得せず、カード表示時に必要な分だけ読むため、教材数を増やしても
起動処理へ全件downloadを足さない。初回通信が遅い場合は既存契約どおり代替表示を使う。

Supabase Storageの公開objectはCDNを利用できる。公式教材は利用者データを含まず、公開読取と
相性がよい。一方、アップロード・更新・削除は公開せず、`service_role` をiOSへ入れない。

## ファイル仕様とパス

| 種類 | 形式 | 変換条件 | Storage相対パス |
|---|---|---|---|
| 例文画像 | WebP | 3:4、最大768×1024 px、sRGB、品質80目安、metadata除去 | `content-images/<theme-slug>/<range>/<example-id>.webp` |
| 単語音声 | MP3 | mono、44.1 kHz、64 kbps、無音を除き5秒以内 | `content-audio/word/<range>/<pronunciation-id>.mp3` |
| 例文音声 | MP3 | mono、44.1 kHz、64 kbps、無音を除き12秒以内 | `content-audio/example/<theme-slug>/<range>/<example-id>.mp3` |

`range` はファイル名に使うIDを500件ごとに分ける。画像・例文音声は `example-id`、
単語音声は `pronunciation-id` を使い、ID 1〜499は `0000-0499` とする。
原本ファイル名や完全URLはDBへ保存しない。V5では単語音声を
`word_pronunciations.audio_asset_path`、例文音声を `example_audio.audio_asset_path` へ保存する。
旧 `example_contents.audio_asset_path` は互換期間だけ同じ例文音声パスを保持する。

objectは新規アップロードを原則とし、存在するパスを無条件に上書きしない。現在の固定IDパスを
訂正するときは対象を確認して明示的に上書きし、ブラウザキャッシュを長く残さないため
`cacheControl=3600`（1時間）を使う。将来、頻繁な差し替えが必要になった場合は、別ticketで
version付きパスとDB制約を設計する。

## 容量の上限

計画では1語につき画像1枚、単語音声1本、例文音声1本とする。

| 種類 | 計画平均 | 1ファイル上限 |
|---|---:|---:|
| 画像 | 100 KiB | 200 KiB |
| 単語音声 | 24 KiB（約3秒） | 40 KiB |
| 例文音声 | 64 KiB（約8秒） | 96 KiB |
| **1語合計** | **188 KiB** | **336 KiB** |

| 語数 | ファイル数 | 計画平均 | 全件が上限の場合 |
|---:|---:|---:|---:|
| 50語 | 150 | 9.18 MiB | 16.41 MiB |
| 1900語 | 5700 | 348.83 MiB | 623.44 MiB |

全1900語の計画平均約349 MiBは、2026-09-01時点のSupabase Free PlanのStorage 1 GB内に収まる。
ただし通信量は別で、50語を全件初回取得すると1人あたり約9.2 MiB、100人で約0.90 GiB、
1000人で約8.97 GiBとなる。Free Planのcached 5 GBとuncached 5 GBは別枠なので、10 GBを
自由に使える1枠とは扱わない。配信前と配信後に両方のegressを確認する。

上限を超えたファイルはアップロード前検査で停止する。bucket設定の変更はこのdecisionには
含めず、投入処理を作るticketで検査を実装する。

## 運び方

```text
Anki原本の読取用コピー
→ 50語と参照ファイルを固定
→ USL-284で公開可否を確認
→ WebP / MP3へ変換
→ MIME・寸法・長さ・容量・SHA-256を検査
→ ローカルStorageへ1語分を置いて公開URLから読み戻す
→ 本番対象と切り戻し方法を示して別承認を得る
→ service_roleを持つ信頼済み処理でmediaを先にアップロード
→ 読み戻しとSHA-256一致を確認
→ DBへStorage相対パスを1トランザクションでupsert
→ アプリで画像表示、単語音声、例文音声を確認
```

mediaをDBより先に置くことで、DBに読めないURLが先に現れる時間を作らない。失敗時はDBの
新しいパスを旧値または `NULL` へ戻し、参照されていない新規objectだけを削除する。
本番Storageへのアップロード、DB更新、bucket設定変更は、それぞれ実施前に対象を示して承認を得る。

## 1語分のローカル確認

2026-09-01に本番へ接続せず、ローカルSupabaseで次を確認した。

- 768×1024 WebP 1枚、64 kbps mono MP3の3秒音声と8秒音声を合成した。
- `content-images` へ画像1件、`content-audio` へ単語音声1件と例文音声1件をアップロードした。
- 3件とも公開URLがHTTP 200となり、MIMEは `image/webp` / `audio/mpeg`、TTLは3600秒だった。
- 読み戻した3件のSHA-256は、それぞれアップロード前と一致した。
- 検査用object 3件は確認後に削除した。

合成画像は単色で1476 bytesと小さいため、画像の平均容量を証明する試料には使わない。
音声は3秒で24493 bytes、8秒で64617 bytesとなり、計画平均の24 KiB / 64 KiBに収まった。

## 今回は含めないこと

- Anki素材の権利確認と公開許可（USL-284）
- 50語または1900語の本番アップロード、DB投入
- 本番bucket、Storage policy、RLS、migrationの変更
- iOSの端末キャッシュ実装（USL-290）
- version付きobject pathへのDB制約変更

## 見直す条件

- 実素材50語の平均または最大が上限を超えたとき
- 画像の文字が768×1024で読めない、または音声64 kbpsで聞き取りにくいと確認されたとき
- 50語配信後のcached / uncached egressが見積もりを大きく超えたとき
- 同じ教材の差し替えを1時間未満で反映する必要が生じたとき
- 公式教材を完全オフラインで保証する要件が決まったとき

## 根拠

- `docs/content/anki-50-extraction.md`（50語、media 150件）
- `docs/content/source-database-v5.md`（V5の音声テーブルと相対パス）
- `docs/architecture/official-content-contract.md`（公開bucket、パス、権限、欠損時動作）
- Supabase公式: [Storage CDN](https://supabase.com/docs/guides/storage/cdn/fundamentals)
- Supabase公式: [Smart CDN](https://supabase.com/docs/guides/storage/cdn/smart-cdn)
- Supabase公式: [Bandwidth & Storage Egress](https://supabase.com/docs/guides/storage/serving/bandwidth)
- Supabase公式: [Egress usage](https://supabase.com/docs/guides/platform/manage-your-usage/egress)
- Supabase公式: [Pricing](https://supabase.com/pricing)
