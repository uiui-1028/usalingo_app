# 決定｜音声のパスは取りこみが作り、空の発音行は残し、シートの共有は変えない

決定日: 2026-09-15

## 決めること

USL-306 の残り3件を決める。

- A1: `03_audio_example_audio.audio_asset_path` が `audio/examples/1.mp3` の形で、
  コンテンツ契約の形（`content-audio/example/simple/0000-0499/1.mp3`）と合わない
- A2: `03_audio_pronunciations` の1000行のうち999行は、パスも声も空である
- A8: シートは「リンクを知っている人は誰でも閲覧可」になっている

## 決めたこと

| # | 決定 |
|---|---|
| A1 | 音声のパスはシートに書かない。取りこみ（USL-308）がIDから契約の形で作り、Storageにファイルがあるときだけ入れる。単語音声の形は `content-audio/word/<range>/<pronunciation-id>.mp3` |
| A2 | 空の行は消さない。`voice_label` が空の行は取りこみで飛ばす |
| A8 | 共有範囲は変えない。USL-308 は認証なしでCSVを読む |

## 理由

**A1: パスはIDで決まる。** 番号とコンセプトがわかれば、パスは1通りに決まる。
人が1000行書くと、書き写しのずれが起きる。ファイルがないのにパスを入れると、
アプリが「ない音声」を読みにいくので、Storageにあるときだけ入れる。

**A2: 作り直しの手間を避ける。** 行を消すと、音声ができたときに行を作り直すことになる。

**A8: 秘密は入っていない。** シートの中身は、アプリで配る教材である。
共有をしぼると、USL-308 にGoogle認証のしくみが増える。
`service_role` などの秘密の値は、これまでどおりシートに置かない。

## 2026-09-15 時点のStorage

| 場所 | 件数 | IDとの対応 |
|---|---:|---|
| `content-audio/example/simple/0000-0499/` | 50 | `1.mp3`〜`50.mp3`。DBとシートの `example_id` 1〜50 と例文が一致 |
| `content-audio/word/4000-4499/` | 50 | `4001.mp3`〜`4050.mp3`。やめた千の位の番号のまま。いまの `pronunciation_id` とは合わない |
| `content-images/simple/0000-0499/` | 50 | `1.webp`〜`50.webp` |

## 影響

- [`source-database-v5.md`](../content/source-database-v5.md) と
  [`official-content-contract.md`](../architecture/official-content-contract.md) を直す
- シートに残っている `audio_asset_path` の列は、取りこみが使わない
- 単語音声50件は、そのままでは取りこみで見つからない。いまの番号の場所へ移すかは、
  本番Storageの変更なので、USL-308 か USL-309 で別に実行承認を得る
- 例文音声1000行のうち、ファイルがあるのは50件。残り950件は `audio_state = blank` で入る
