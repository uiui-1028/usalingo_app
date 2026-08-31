# Anki原本から最初の50語を取り出す手順

調査日: 2026-08-31
対象: USL-280

## 結論

最初の50語は、Ankiの画像付きTARGET-1900デッキの `00｜Number` が `0001`〜`0050` のノートを選びます。復習状況で変わるCardの `due` 順や画面表示順は使いません。

対象100語のうち番号1〜50はちょうど50件で、番号・英単語の重複は0件でした。必須項目と画像・単語音声・例文音声・語源に欠損はなく、media参照150件はすべて実ファイルへ接続しました。

この確認はローカルAnki原本の読み取りだけです。50語のSupabase投入、Storageアップロード、素材の公開可否確認は含みません。

## 対象を固定する

| 項目 | 値 |
|---|---|
| Ankiプロファイル | `Anki｜Taiga（taiyahehe）` |
| 親デッキ | `【 ENGLISH 】 > 単語｜TARGET-1900 > 🔴｜01｜画像 > Words｜01｜800` |
| 調査した子デッキ | `●｜0001-0100` |
| Anki deck ID | `1748673634399` |
| ノート型 | `Note｜🔴｜Word & Voice & Image｜Material（dark）` |
| ノート型ID | `1751695639914` |
| 選定条件 | `Number` を整数化し、1〜50を含む行 |

deck IDとnotetype IDはローカルAnki内の識別子です。別環境では、名前とフィールド集合も確認し、数値IDだけに依存しません。

## 原本フィールドとV5の対応

| Anki ord | 原本フィールド（接頭辞省略） | V5 / 中間JSON | 変換 |
|---:|---|---|---|
| 0 | `00｜Index` | `source.index` | 監査用。公開DBの主キーにはしない |
| 1 | `00｜Number` | `words.source_position` | 先頭0を外して整数化 |
| 2 | `01｜Stage` | `source.stage` | 監査用文字列 |
| 3 | `02｜English word` | `words.word_text` | HTML除去、前後空白除去、小文字比較で重複検査 |
| 4 | `02-voice｜English word` | `word_pronunciations.audio_source_file` | `[sound:FILE]` からFILEを取り出す |
| 5 | `03｜Part of speech` | `word_meanings.part_of_speech_jp/en` | `／` で対応するsenseへ分割し、英語コードへ変換 |
| 6 | `04｜Example sentence` | `example_contents.sentence_en` | HTML除去。必須 |
| 7 | `04-voice｜Example sentence` | `example_audio.audio_source_file` | `[sound:FILE]` からFILEを取り出す |
| 8 | `05｜Example sentence image` | `example_contents.image_source_file` | `<img src="FILE">` からFILEを取り出す |
| 9 | `06｜Japanese word` | `word_meanings.definition_jp` | `／` で対応するsenseへ分割 |
| 10 | `07｜Translation of example sentece` | `example_contents.sentence_jp` | HTML除去。必須 |
| 11 | `08｜Etymology` | `word_meanings.etymology` | HTMLを許可リストで整形 |
| 12 | `09｜Synonym` | `word_relations.relations_json` | 構造化できた値だけ保存 |
| 13 | `99｜Temp-Memo` | 取り込まない | 制作メモ。公開データにしない |

Ankiのnote GUIDは `words.source_note_guid`、固定コード `target-1900-image` は `words.source_deck_code` に保存します。

## 品詞の変換

| 原本 | `part_of_speech_en` |
|---|---|
| 名詞 | `noun` |
| 動詞 | `verb` |
| 形容詞 | `adjective` |
| 副詞 | `adverb` |
| 前置詞 | `preposition` |
| 接続詞 | `conjunction` |

`動詞／名詞` のような複合値は、意味欄も同じ区切り数であることを確認し、priority 1, 2の複数senseにします。区切り数が合わない行は自動補完せず検査エラーにします。

## 中間JSON

1ノートを次の形へ変換します。配信用の整数IDは、投入処理が既存行との衝突を確認してから決めます。

```json
{
  "source": {
    "note_guid": "anki-guid",
    "deck_code": "target-1900-image",
    "position": 1,
    "stage": "source-stage"
  },
  "word": "create",
  "senses": [
    {
      "priority": 1,
      "part_of_speech_en": "verb",
      "part_of_speech_jp": "動詞",
      "definition_jp": "作り出す、創造する",
      "etymology": "...",
      "example": {
        "concept_code": "simple",
        "sentence_en": "...",
        "sentence_jp": "...",
        "image_source_file": "...webp",
        "image_state": "present"
      }
    }
  ],
  "pronunciations": [
    {
      "accent": "unspecified",
      "voice_label": "default",
      "audio_source_file": "...mp3",
      "audio_state": "present",
      "is_primary": true
    }
  ]
}
```

例文がどのsenseに対応するか曖昧な複合品詞行は自動で複製せず、公開前の人間確認対象にします。

## 実行手順

1. Ankiを終了するか、最新backupから読取用コピーを作る。
2. 対象デッキ名、フィールド14件、ノート型名が上表と一致することを確認する。
3. `Number` 1〜50を抽出し、件数50、番号重複0、単語重複0を確認する。
4. Anki HTML、`[sound:...]`、`<img src="...">` を解析して中間JSONへ変換する。
5. 必須値、品詞と意味の分割数、mediaファイルの存在、JSON構造を検査する。
6. mediaをStorage契約のWebP・MP3へ変換し、相対パスを組み立てる。原本ファイル名をそのまま公開パスにしない。
7. ローカルSupabaseへ1語を投入し、word → sense → example、発音、例文音声の接続を確認する。
8. 50語を1トランザクションでupsertし、件数、重複、孤児、RLS、アプリ読取を確認する。
9. 本番投入とStorageアップロードは、対象件数・更新行・切り戻し方法を示して別途承認を得る。

## 検査結果

| 検査 | 結果 |
|---|---:|
| 子デッキ内ノート | 100 |
| `Number` 1〜50 | 50 |
| 番号重複 | 0 |
| 英単語重複 | 0 |
| 英単語、日本語意味、品詞の欠損 | 各0 |
| 例文、例文訳の欠損 | 各0 |
| 画像、単語音声、例文音声の参照欠損 | 各0 |
| 語源の欠損 | 0 |
| media存在確認 | 150 / 150 |

## 足りない情報と扱い

| 足りない／未確定 | 今回の扱い |
|---|---|
| `part_of_speech_en` | 上の対応表で生成。未知値は停止 |
| `concept_id` | 50語は固定コード `simple` を参照 |
| IPA、accent | 推測しない。(`ipa_state=blank`, `accent=unspecified`) |
| CEFR | 推測しない。(`NULL`) |
| Storage相対パス | 変換・アップロード工程で生成 |
| 複合品詞行の例文とsenseの対応 | 公開前に確認 |
| 素材の権利・表示条件 | USL-284で確認。確認前は本番公開しない |

## 完了条件

- この対応表にない原本フィールドが現れたら停止する。
- 50語で必須値、重複、参照切れが0件である。
- 1語のローカル変換でV5の全接続を再現できる。
- 本番変更と素材公開を、この調査だけで実施済みと扱わない。
