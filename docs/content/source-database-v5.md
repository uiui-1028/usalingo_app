# 英単語原本データベース V5

最終更新日: 2026-09-14
対象: 教材原本、Supabase公式コンテンツ、SwiftUIアプリ

## 1. 正本と役割

教材の内容は**Google SpreadsheetのV5原本**を正本とし、Supabaseはアプリへ配るDBとします。
Supabaseは配信用の写しであり、人が直接編集しません。

```text
Google Spreadsheet（V5の8シート）
  → Supabase公式コンテンツ
  → SwiftUIアプリ
```

同期は片方向です。行を消しても同期先からは消さず、`is_active` で隠します。
正本をSpreadsheetに定めた経緯は
[教材の正本と単語リスト](../decisions/content-source-and-word-list-20260907.md) にあります。

Ankiは退役しました。1000語ぶんの取り出しは人が手で1回だけ行い、以後は使いません。
[`anki-data-model.md`](../architecture/anki-data-model.md) は残りますが、あれはNote・Card・Deckと
いう設計の考え方であり、Ankiのファイル形式とは関係がありません。

- この文書: 原本と配信用DBの論理契約
- [`supabase/migrations/`](../../supabase/migrations/): 実行可能なDB構造の正本
- [`official-content-contract.md`](../architecture/official-content-contract.md): Storage、欠損時動作、アクセス権
- [`anki-50-extraction.md`](anki-50-extraction.md): 最初の50語をAnkiから取り出したときの記録。履歴であり、いまの手順ではない

学習履歴、利用者設定、デッキ内のCard順などの運用データはSupabaseだけで管理します。

## 2. 設計の中心

```text
word（見出し語）
  ├─ sense（意味・品詞・活用・類義語など）
  │    └─ example（例文・画像）
  │         ├─ concept（シンプル、ホラーなど）
  │         └─ example_audio（例文音声）
  └─ pronunciation（発音・単語音声）

deck（デッキ）
  └─ deck_word（並び順と、主の意味 sense）
```

独立して増える意味、例文、発音、音声は行を分けます。活用と類義語などの関連語は、行を分けずに
意味の行の中へ収めます。品詞が変わると活用も変わるため（`light` の名詞と形容詞など）、
単語ではなく意味ごとに持ちます。経緯は
[意味の行に活用と関連語を収める](../decisions/senses-hold-forms-and-relations-20260914.md) にあります。

## 3. 原本の8シート

| シート | 主キー | 必須項目 | 用途 |
|---|---|---|---|
| `01_core_words` | `word_id` | `word_text` | 見出し語 |
| `01_core_senses` | `sense_id` | `word_id`, `priority`, `part_of_speech_en`, `definition_jp` | 意味、品詞、活用、関連語 |
| `02_content_concepts` | `concept_id` | `concept_code`, `concept_name`, `is_active` | 教材コンセプト |
| `02_content_examples` | `example_id` | `sense_id`, `concept_id`, `sentence_en`, `sentence_jp` | 例文と画像 |
| `03_audio_pronunciations` | `pronunciation_id` | `word_id`, `voice_label` | 発音と単語音声 |
| `03_audio_example_audio` | `example_audio_id` | `example_id`, `voice_label` | 例文音声 |
| `04_decks` | `deck_id` | `deck_name`, `concept_id` | デッキ |
| `04_deck_words` | なし（`deck_id` と `sense_id` の組で重複させない） | `deck_id`, `sense_id` | デッキに入れる単語、並び順、主の意味 |

共通ルール:

- IDは固定し、一度使ったIDを別データへ再利用しない。
- 外部キーは単語文字列ではなくIDで接続する。
- 必須文字列は空文字にせず、欠損行を公開しない。
- 時刻はタイムゾーン付きISO 8601を使う。
- CEFRは `A1`, `A2`, `B1`, `B2`, `C1`, `C2` または未設定とする。
- `concept_code` は半角小文字、数字、ハイフンだけを使う。

### IDの形

シートのIDは整数にし、頭文字は付けません。シートの数字が、そのままSupabaseの整数IDとStorageパスの数字になります。
番号は**シートごとに1から**数えます。シートでは `0001` のようにゼロ埋めしても、`1` と書いてもかまいません。
取りこみが整数に直すので、DBとStorageパスでは `1` になります。
IDが重複してはいけないのは、同じシートの中だけです。別のシートで同じ数字を使ってもかまいません。

千の位でシートを見分ける付け方（単語 `1001`、意味 `2001`、例文 `3001`、発音 `4001`）は使いません。
1つのシートが999件を超えると守れないためです。
経緯は [シートのIDは頭文字を付けず、これまでどおり数字にする](../decisions/sheet-id-keep-numbers-20260914.md) にあります。

## 4. 各シートの列

### `01_core_words`

| 列 | 必須 | 内容 |
|---|---:|---|
| `word_id` | 必須 | 固定ID |
| `word_text` | 必須 | 見出し語 |
| `source_note_guid` | 任意 | 原本側の安定ID。Ankiの退役により、いまは使いません |
| `source_deck_code` | 任意 | 原本デッキの固定コード |
| `source_position` | 任意 | 原本内の1始まりの順番 |

`source_deck_code + source_position` と `source_note_guid` は、それぞれ重複させません。
管理時刻（`created_at`、`updated_at`）はシートに書きません。DBが自動で入れます。

### `01_core_senses`

| 列 | 必須 | 内容 |
|---|---:|---|
| `sense_id` | 必須 | 固定ID |
| `word_id` | 必須 | 見出し語 |
| `priority` | 必須 | 小さい値を優先 |
| `part_of_speech_en` | 必須 | `verb`, `noun` など |
| `part_of_speech_jp` | 任意 | 日本語表示 |
| `definition_jp` | 必須 | 日本語の意味 |
| `cefr_level` | 任意 | Usalingoで採用したCEFR |
| `pronunciation_ipa` | 任意 | IPA（米国発音）。品詞で発音が変わる単語（`increase` など）は意味ごとに書く |
| `pronunciation_kana` | 任意 | カタカナの読み |
| `etymology` | 任意 | 語源 |
| `inflections` | 任意 | 活用。JSONオブジェクトをそのまま書く |
| `synonyms` | 任意 | 類義語。` /&/ ` 区切り |
| `antonyms` | 任意 | 反意語。` /&/ ` 区切り |
| `derivatives` | 任意 | 派生語。` /&/ ` 区切り |
| `collocations` | 任意 | コロケーション。` /&/ ` 区切り |
| `related` | 任意 | 関連語。` /&/ ` 区切り |

1つの原本セルに「動詞／名詞」「増加する／増加」のような複数の意味がある場合は、対応する順番で複数のsenseへ分けます。

`inflections` は、最上位をJSONオブジェクトにします。

```json
{"third_person": "runs", "past": "ran", "past_participle": "run", "present_participle": "running"}
```

` /&/ ` 区切りの列は、1つのセルに複数の項目を入れます。1項目は `単語 :: 訳 :: 補足` にします
（訳と補足は省けます）。前後の空白は取りこみで除きます。単語・訳・補足の中では `/&/` と `::` を使いません。
アプリの `WordSynonym.parse` がこの形を読みます。経緯は
[複数の項目が入るセルは ` /&/ ` で区切る](../decisions/list-cell-separator-20260914.md) にあります。

```text
make :: 作る :: 最も一般的で「無から有を生み出す」広い意味で使われる /&/ produce :: 生産する :: 工業的または農作物を「作り出す」結果に重点がある /&/ generate :: 生み出す :: 電気・利益・アイディアなどを「発生させる」際に使う
```

### `02_content_concepts`

| 列 | 必須 | 内容 |
|---|---:|---|
| `concept_id` | 必須 | 固定ID |
| `concept_code` | 必須 | アプリ内部コード。例: `simple` |
| `concept_name` | 必須 | 表示名。例: `シンプル` |
| `description` | 任意 | 説明 |
| `is_active` | 必須 | 現在使うか |

### `02_content_examples`

| 列 | 必須 | 内容 |
|---|---:|---|
| `example_id` | 必須 | 固定ID |
| `sense_id` | 必須 | 対応する意味 |
| `concept_id` | 必須 | コンセプト |
| `sentence_en`, `sentence_jp` | 必須 | 例文と訳 |
| `image_asset_path` | 任意 | Storage相対パス |

### `02_content_examples` で取りこみが決める値

例文シートは、画像の状態と順番の列を持ちません。取りこみがDBの列を次のように決めます。

| DBの列 | 決め方 |
|---|---|
| `image_state` | `image_asset_path` があれば `present`、なければ `blank` |
| `display_order` | 同じ意味・同じコンセプトの行のうち、シートで上から何番目か（1始まり） |

### `03_audio_pronunciations`

| 列 | 必須 | 内容 |
|---|---:|---|
| `pronunciation_id` | 必須 | 固定ID |
| `word_id` | 必須 | 見出し語 |
| `audio_asset_path` | 任意 | 単語音声のStorage相対パス |
| `voice_label` | 必須 | `default`, `male` など |

### `03_audio_example_audio`

`example_audio_id`, `example_id`, `audio_asset_path`, `voice_label` を持ちます。

### 音声シートで取りこみが決める値

音声の2シートは、状態・標準・順番・アクセントの列を持ちません。取りこみがDBの列を次のように決めます。

| DBの列 | 決め方 |
|---|---|
| `ipa`、`ipa_state`（`word_pronunciations`） | いつも `NULL` と `blank`。IPAは `01_core_senses.pronunciation_ipa` に置く |
| `audio_state` | `audio_asset_path` があれば `present`、なければ `blank` |
| `display_order` | 同じ単語（例文音声は同じ例文）の行のうち、シートで上から何番目か（1始まり） |
| `is_primary` | 同じ単語（例文）の行のうち、シートで一番上の行だけ `true`。標準音声は1単語・1例文につき最大1件 |
| `accent`（`word_pronunciations`） | いつも `US`。別のアクセントを足すときは、シートに列を戻す |

標準の声を変えるときは、シートの行の並びを入れ替えます。経緯は
[音声シートの状態・標準・順番の列は、取りこみで決める](../decisions/audio-sheet-derived-columns-20260914.md) にあります。

### `04_decks`

| 列 | 必須 | 内容 |
|---|---:|---|
| `deck_id` | 必須 | 固定ID |
| `deck_name` | 必須 | 表示名。例: `大学受験頻出1000語` |
| `concept_id` | 必須 | このデッキの例文に使うコンセプト |

### `04_deck_words`

| 列 | 必須 | 内容 |
|---|---:|---|
| `deck_id` | 必須 | デッキ |
| `sense_id` | 必須 | **主の意味**。単語は、この意味の `word_id` で決まる |

- 行の並びが、デッキ内の並び順です。
- 1つのデッキに、同じ単語を2回入れません（同じ単語の別の意味を2行書かない）。
- 主の意味は、カードで大きく表示し、例文・画像・音声もこの意味のものを出します。
  同じ単語のほかの意味は、副として `priority` 順に表示します。
- 同じ単語でも、デッキごとに主の意味を変えられます。
- 主の意味に、デッキのコンセプトの例文がないと、カードに例文が出ません。

経緯は [デッキごとに単語の主の意味を決める](../decisions/deck-primary-sense-20260914.md) にあります。

## 5. 状態値

画像、音声、IPAだけに次の状態を使います。

| 状態 | 意味 | 値との関係 |
|---|---|---|
| `present` | 使用できる値がある | 対応する値が必須 |
| `blank` | まだ作っていない | 対応する値は `NULL` |
| `not_applicable` | 不要 | 対応する値は `NULL` |
| `unverified` | 値はあるが未確認 | 対応する値が必須。公開用出力では扱わない |

空文字は中間変換時に `NULL` へ直します。

## 6. Supabase対応

| V5原本 | Supabase |
|---|---|
| `01_core_words` | `words` |
| `01_core_senses` | `word_meanings` |
| `02_content_concepts` | `content_concepts` |
| `02_content_examples` | `example_contents` |
| `03_audio_pronunciations` | `word_pronunciations` |
| `03_audio_example_audio` | `example_audio` |
| `04_decks` | `decks`（`concept_id` 列あり） |
| `04_deck_words` | `cards`（`deck_id`、`word_id`、`primary_meaning_id`、`sort_order`） |

`04_deck_words` の1行から、デッキの出題形式（`card_templates`）ごとに `cards` を作ります。
`word_id` は `sense_id` の単語、`primary_meaning_id` は `sense_id`、`sort_order` はシートの行の並びです。
`cards.primary_meaning_id` はUSL-308のmigrationで足し、その単語の意味しか指せないように外部キーで止めます。
カードの一意条件（`word_id + card_template_id + deck_id`）は変えないので、主の意味を変えても学習記録は残ります。

`01_core_senses` の活用と関連語は、`word_meanings` の同じ名前の列へ入れます。

| シートの列 | `word_meanings` の列 | 型 |
|---|---|---|
| `pronunciation_ipa`, `pronunciation_kana` | 同名 | `text` |
| `inflections` | `inflections` | `jsonb`（オブジェクト） |
| `synonyms`, `antonyms` | 同名 | `text[]` |
| `derivatives`, `collocations` | 同名 | `jsonb`（配列） |
| `related` | `related` | `text[]`。USL-308のmigrationで足す |

`word_forms`・`word_relations` の2表は使いません。USL-308のmigrationで消します。
本番には過去の50語ぶん（各50行）が入っているため、本番への適用は別に実行承認を得ます。

既存SwiftUIとの互換期間は、`word_meanings.audio_asset_path`、`example_contents.theme`、`example_contents.audio_asset_path` などの旧列を残します。新しい投入処理はV5テーブルへ書き、アプリ切替後の別migrationで旧列を廃止します。

既存の `example_contents.theme = 'シンプル'` は、固定コード `content_concepts.concept_code = 'simple'` へbackfillします。

構造を合わせるmigrationは [`20260831121553_align_source_database_v5.sql`](../../supabase/migrations/20260831121553_align_source_database_v5.sql) です。既存行を保持して追加テーブルへbackfillし、公式コンテンツの公開範囲は広げません。

## 7. 公開前の検査

- 固定ID、原本GUID、`source_deck_code + source_position` が重複していない。
- 外部キー切れが0件。
- 見出し語、最優先の意味、例文、例文訳が空でない。
- 状態と値が一致する。`present` / `unverified` は非NULL、`blank` / `not_applicable` はNULLである。
- `inflections` がJSONオブジェクトである。
- Storage参照が実ファイルへつながる。
- 認証利用者は公式コンテンツを読めるが書けない。
- `anon` は公式DBを読めない。

出典、ライセンス、公開可否は素材権利の課題で別途確認します。AI生成履歴や承認ワークフローは、この教材スキーマへ混ぜません。
