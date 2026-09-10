# 決定｜教材の正本をGoogle Spreadsheetにし、大学受験頻出1000語を配る

決定日: 2026-09-07

## 決めること

教材原本の正本が定まっていなかった。[`source-database-v5.md`](../content/source-database-v5.md)
は「Anki・Spreadsheetなどの原本」と書き、両方を許していた。実際には次の3つが並び、
互いに噛み合っていない。

| 定義 | 実体 | 状態 |
|---|---|---|
| リポジトリ内のJSON | [`target-1900-0001-0050.json`](../content/target-1900-0001-0050.json)。50語 | 2026-09-02から50語の正本（[USL-286](usl-286-repo-owned-content.md)） |
| Anki collection | [`scripts/prepare-official-content.py`](../../scripts/prepare-official-content.py) が読む。deck `target-1900-image` | USL-286で取り直し用の経路に格下げ済み |
| Google Spreadsheet `usgs_master_v5` | V5の8シート構成 | 構成は設計書どおり。中身は30語の確認用データ |
| Notion `Word Property` 定義 | `word_meanings` に `synonyms`・`collocations`・`inflections` を持つ旧構成 | V5と別スキーマ |

[USL-286](usl-286-repo-owned-content.md) はAnkiを50語の正本から外し、リポジトリ内のJSONへ
移した。この決定はその続きにあたり、**正本をJSONからGoogle Spreadsheetへ移す**。
Ankiは取り直し用の経路としても使わない。

正本が1つに決まらないと、片方向同期の「元」を定義できない。AIによるデータ生成の
入れ先も決まらない。

## 選択肢

1. Ankiを正本にし、抽出スクリプトを育てる
2. **Google Spreadsheetを正本にし、Ankiは退役させる**
3. 両方を正本とし、役割を分ける

## 決めたこと

**選択肢2を採る。** あわせて、配る教材の範囲と作り方を次のとおり確定する。

| 項目 | 決定 |
|---|---|
| 教材の正本 | **Google Spreadsheet**（V5の8シート）。50語のJSON正本を置き換える |
| Anki | **退役**。1000語ぶんの取り出しは人が手で1回だけ行い、以後は使わない |
| 単語リスト | **大学受験頻出順で1000語** |
| コンセプト | **`simple` 1種のみ**（イラストはMidjourney） |
| 1000語ぶんのデータ | 例文・イラスト・音声・類義語・語源まで既に揃っている。**不足なし** |
| AIによるテキスト生成と校正ループ | **今回は作らない。** 2つ目のコンセプトを足すとき、または1000語を超えるときに設計する |
| Supabase | **AI生成に関与させない。** 配信用の写しとして扱い、人は直接編集しない |
| 同期 | **片方向**（Spreadsheet → Supabase）。削除は同期せず `is_active` で隠す |
| 投入前の検査スクリプト | **作らない。** DBのCHECK制約・NOT NULL・外部キー・UNIQUEを門番にする |
| 投入の順番 | **まず50語で通し、実機で確認してから残り950語** |
| 意味の扱い | 1単語の意味を**すべて `priority` 順にならべて表示**する。例文は**そのうち1つの意味**に付く |

## 理由

**1000語ぶんの教材は、すでに手元にある。** 例文・イラスト・音声・類義語・語源まで
揃っており、不足はない。したがっていま必要なのは「AIで作る仕組み」ではなく
「在るものをアプリまで流す道」である。生成の設計は、道を通して1000語を流し、
何が足りないかを見てからのほうが確実になる。

**Ankiからの取り出しは繰り返さない。** 1回だけの作業のためにスクリプトを保守する
理由がない。以後の教材の追加・修正はSpreadsheet上で行う。

**Supabaseを生成から外すと、配信が揺れない。** 生成が何回失敗しても、利用者へ届く
DBは影響を受けない。運営処理を信頼済み環境に限る
[公式コンテンツ契約](../architecture/official-content-contract.md) §4とも一致する。

**まず50語で通す。** Spreadsheetからアプリまでの道はまだ一度も通っていない。
1000語を入れてから問題が見つかると、やり直しが1000件になる。

## 影響

- [`milestones.md`](../plans/milestones.md) のM2を書き換える。
  旧: 「Ankiの原本から50語を標準デッキとして配れる」。
  新: 「大学受験頻出1000語が、シートからアプリまで自動で届く」
- `USL-280`（調査｜Anki原本から50語を取り出す手順と必要な項目を確定する）は前提が変わる。
  Notion側で見直す
- [`prepare-official-content.py`](../../scripts/prepare-official-content.py) のAnki読み取り部分は
  役目を終える。検査・SQL生成部分も今回は使わない。削除は別の課題として扱う
- [`target-1900-0001-0050.json`](../content/target-1900-0001-0050.json) は50語の正本ではなくなる。
  1000語がSpreadsheetへ入るまでは動作確認用として残し、置き換え後の扱いは別の課題で決める
- [`import-official-content.md`](../operations/import-official-content.md) は
  「JSON正本 → SQL → ローカルSupabase」の手順であり、
  「Spreadsheet → Supabase 片方向同期」へ書き換える
- [`anki-50-extraction.md`](../content/anki-50-extraction.md) は**移動しない**。
  過去の決定記録（[USL-284](usl-284-material-rights.md)、[USL-286](usl-286-repo-owned-content.md)、
  [USL-283](usl-283-media-delivery.md)）が根拠として参照しており、決定記録は書き換えないため。
  文書の冒頭にある「Ankiは記録として残す」注記が、そのまま今回にも当てはまる
- [`anki-data-model.md`](../architecture/anki-data-model.md) は**残す**。
  これはNote・Card・Deckという設計の考え方であり、Ankiのファイル形式とは関係がない
- `source-database-v5.md` の `source_note_guid` は使わない
- アプリ側に3件の修正が要る（下記）

### アプリ側で直すこと

`WordCard.swift` の `toCard()` は、優先度が最も高い意味を1件だけ取り、
その意味に付いた例文だけを読んでいる。

```swift
let meaning = wordMeanings?.sorted { priority }.first
let example = meaning.exampleContents?.first
```

意味をすべて表示する決定により、次の3件を直す。

1. **意味を `priority` 順にすべて表示する。** 例文が優先度1以外の意味に付いている場合、
   いまの実装では例文・訳・画像・音声が4つとも `NULL` になる。
   画像と音声を例文から取っているため、絵の無い、音の出ないカードになる
2. **品詞を意味ごとに持つ。** `WordCard.partOfSpeech` は1件しか持てない。
   `light`（明かり＝名詞／軽い＝形容詞）のように意味ごとに品詞が変わる
3. **類義語と語源の仮表示をやめる。** いまは配信データが無いため表示側でサンプルを
   当てており、その単語のものではない値が出ている

Supabaseへの問い合わせ（`StudyService.swift`）はすでに全部の意味とその例文を
取得している。取得結果を捨てているだけなので、通信量は増えない。

## 決めていないこと

- **例文の品質基準**（保留）。AIによる生成を始める直前に決める
- **例文がどの意味のものかをカードに示すか。** いまは示さない。将来または開発の途中で足す
- **採番の帯。** テストデータのうちは自由でよい。ただし実機で学習記録が付いたあとは
  番号を変えられないため、**本番前に固定する**
- 2つ目以降のコンセプト（ホラー、恋愛など）を足す時期
- 画像生成シートの結合キーの修正。いま動かしていないため、再開する日に扱う
