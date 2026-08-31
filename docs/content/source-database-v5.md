# 英単語原本データベース V5

最終更新日: 2026-08-31
対象: 教材原本、Supabase公式コンテンツ、SwiftUIアプリ

## 1. 正本と役割

教材の内容はV5原本を正本とし、Supabaseはアプリへ配るDBとします。

```text
Anki・Spreadsheetなどの原本
  → 検査済みの中間JSON
  → Supabase公式コンテンツ
  → SwiftUIアプリ
```

- この文書: 原本と配信用DBの論理契約
- [`supabase/migrations/`](../../supabase/migrations/): 実行可能なDB構造の正本
- [`official-content-contract.md`](../architecture/official-content-contract.md): Storage、欠損時動作、アクセス権
- [`anki-50-extraction.md`](anki-50-extraction.md): 最初の50語を取り出す手順と実測結果

学習履歴、利用者設定、デッキ内のCard順などの運用データはSupabaseだけで管理します。

## 2. 設計の中心

```text
word（見出し語）
  └─ sense（意味・品詞）
       └─ example（例文・画像）
            ├─ concept（シンプル、ホラーなど）
            └─ example_audio（例文音声）

word
  ├─ pronunciation（発音・単語音声）
  ├─ forms_json（語形）
  └─ relations_json（類義語など）
```

独立して増える意味、例文、発音、音声は行を分けます。まとめて見る語形と関連語は、1単語につき1つのJSONオブジェクトにします。

## 3. 原本の8シート

| シート | 主キー | 必須項目 | 用途 |
|---|---|---|---|
| `01_core_words` | `word_id` | `word_text` | 見出し語 |
| `01_core_senses` | `sense_id` | `word_id`, `priority`, `part_of_speech_en`, `definition_jp` | 意味と品詞 |
| `02_content_concepts` | `concept_id` | `concept_code`, `concept_name`, `is_active` | 教材コンセプト |
| `02_content_examples` | `example_id` | `sense_id`, `concept_id`, `sentence_en`, `sentence_jp`, `image_state`, `display_order` | 例文と画像 |
| `03_audio_pronunciations` | `pronunciation_id` | `word_id`, `ipa_state`, `audio_state`, `voice_label`, `is_primary`, `display_order` | 発音と単語音声 |
| `03_audio_example_audio` | `example_audio_id` | `example_id`, `audio_state`, `voice_label`, `is_primary`, `display_order` | 例文音声 |
| `04_extra_forms` | `word_id` | `forms_json` | 語形 |
| `04_extra_relations` | `word_id` | `relations_json` | 類義語など |

共通ルール:

- IDは固定し、一度使ったIDを別データへ再利用しない。
- 外部キーは単語文字列ではなくIDで接続する。
- 必須文字列は空文字にせず、欠損行を公開しない。
- 時刻はタイムゾーン付きISO 8601を使う。
- CEFRは `A1`, `A2`, `B1`, `B2`, `C1`, `C2` または未設定とする。
- `concept_code` は半角小文字、数字、ハイフンだけを使う。

## 4. 各シートの列

### `01_core_words`

| 列 | 必須 | 内容 |
|---|---:|---|
| `word_id` | 必須 | 固定ID |
| `word_text` | 必須 | 見出し語 |
| `source_note_guid` | 任意 | Ankiなど原本側の安定ID |
| `source_deck_code` | 任意 | 原本デッキの固定コード |
| `source_position` | 任意 | 原本内の1始まりの順番 |
| `created_at`, `updated_at` | 必須 | 管理時刻 |

`source_deck_code + source_position` と `source_note_guid` は、それぞれ重複させません。Ankiの復習予定順 `due` は原本順として使いません。

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
| `etymology` | 任意 | 語源 |

1つの原本セルに「動詞／名詞」「増加する／増加」のような複数の意味がある場合は、対応する順番で複数のsenseへ分けます。

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
| `image_state` | 必須 | 画像の状態 |
| `display_order` | 必須 | 同一sense・concept内の順番 |

### `03_audio_pronunciations`

| 列 | 必須 | 内容 |
|---|---:|---|
| `pronunciation_id` | 必須 | 固定ID |
| `word_id` | 必須 | 見出し語 |
| `accent` | 必須 | `US`, `UK`, `unspecified` など |
| `ipa` | 任意 | IPA |
| `ipa_state` | 必須 | IPAの状態 |
| `audio_asset_path` | 任意 | 単語音声のStorage相対パス |
| `audio_state` | 必須 | 音声の状態 |
| `voice_label` | 必須 | `default`, `male` など |
| `is_primary` | 必須 | 標準音声か。1単語につき最大1件 |
| `display_order` | 必須 | 表示順 |

### `03_audio_example_audio`

`example_id`, `audio_asset_path`, `audio_state`, `voice_label`, `is_primary`, `display_order` を持ちます。標準音声は1例文につき最大1件です。

### `04_extra_forms`

```json
{
  "third_person": "runs",
  "past": "ran",
  "past_participle": "run",
  "present_participle": "running"
}
```

### `04_extra_relations`

```json
{
  "synonyms": ["large", "huge"],
  "antonyms": ["small"],
  "derivatives": ["bigness"],
  "related": ["size"]
}
```

どちらもJSON配列ではなくJSONオブジェクトを最上位に置きます。

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
| `04_extra_forms` | `word_forms` |
| `04_extra_relations` | `word_relations` |

既存SwiftUIとの互換期間は、`word_meanings.audio_asset_path`、`word_meanings.inflections`、`example_contents.theme`、`example_contents.audio_asset_path` などの旧列を残します。新しい投入処理はV5テーブルへ書き、アプリ切替後の別migrationで旧列を廃止します。

既存の `example_contents.theme = 'シンプル'` は、固定コード `content_concepts.concept_code = 'simple'` へbackfillします。

構造を合わせるmigrationは [`20260831121553_align_source_database_v5.sql`](../../supabase/migrations/20260831121553_align_source_database_v5.sql) です。既存行を保持して追加テーブルへbackfillし、公式コンテンツの公開範囲は広げません。

## 7. 公開前の検査

- 固定ID、原本GUID、`source_deck_code + source_position` が重複していない。
- 外部キー切れが0件。
- 見出し語、最優先の意味、例文、例文訳が空でない。
- 状態と値が一致する。`present` / `unverified` は非NULL、`blank` / `not_applicable` はNULLである。
- JSONがオブジェクトである。
- Storage参照が実ファイルへつながる。
- 認証利用者は公式コンテンツを読めるが書けない。
- `anon` は公式DBを読めない。

出典、ライセンス、公開可否は素材権利の課題で別途確認します。AI生成履歴や承認ワークフローは、この教材スキーマへ混ぜません。
