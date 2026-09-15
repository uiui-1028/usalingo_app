# 決定｜IPAとカナは意味の行に置く

決定日: 2026-09-14

## 決めること

設計書では、IPAは `03_audio_pronunciations.ipa` に置くことになっていた。
一方、シートの `01_core_senses` には `pronunciation_ipa`・`pronunciation_kana` の列があった。
どちらに置くかを決める。

[意味の行に活用と関連語を収める](senses-hold-forms-and-relations-20260914.md) では
「発音記号はこれまでどおり `03_audio_pronunciations.ipa`」としていたが、この決定で取り消す。

## 決めたこと

**IPAとカナは `01_core_senses` の `pronunciation_ipa`・`pronunciation_kana` に置く。**
`03_audio_pronunciations` から `ipa` の列を外す。

| 項目 | 決定 |
|---|---|
| シート | `01_core_senses.pronunciation_ipa`、`01_core_senses.pronunciation_kana` |
| DB | `word_meanings` の同名の列（最初のスキーマからある） |
| `word_pronunciations.ipa` | 取りこみは `NULL`、`ipa_state` は `blank` を入れる |

## 理由

**品詞で発音が変わる単語がある。** `increase`・`object`・`conduct` などは、名詞と動詞で強く読む
場所が変わる。意味の行は品詞ごとに分けてあるので、意味の行に置けば品詞と発音がそろう。
単語ごとの発音の行に置くと、この違いを持てない。

**入れる箱は、もうある。** `word_meanings` は最初のスキーマ
（[`20260411000000`](../../supabase/migrations/20260411000000_create_current_baseline_schema.sql)）から
`pronunciation_ipa`・`pronunciation_kana` を持っている。migrationを足さなくてよい。

**シートにはもう入っている。** 2026-09-14 に1288行ぶんのIPAとカナを `01_core_senses` へ入れた。

## 影響

- [`source-database-v5.md`](../content/source-database-v5.md) の `01_core_senses` と
  `03_audio_pronunciations` の列、取りこみが決める値を直す
- [音声シートの状態・標準・順番の列は、取りこみで決める](audio-sheet-derived-columns-20260914.md) の
  `ipa_state` の決め方（`ipa` があれば `present`）は、シートに `ipa` がなくなるため、いつも `blank` になる
- `word_pronunciations.ipa` と `ipa_state` の列は使われなくなる。消すかどうかは、アプリの読み先を
  切り替えるときに別に決める
