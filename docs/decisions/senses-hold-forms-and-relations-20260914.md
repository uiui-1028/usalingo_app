# 決定｜意味の行に活用と関連語を収める

決定日: 2026-09-14

## 決めること

V5原本は、活用を `04_extra_forms`、類義語などを `04_extra_relations` に置き、
それぞれ1単語につき1つのJSONオブジェクトとして持っていた。Supabaseでは
`word_forms`・`word_relations` の2表になっている。

1000語をシートへ入れる前に、この分け方を続けるかを決める。

同じ日の決定（[頭文字](sheet-id-prefix-and-1000-at-once-20260914.md)、
[数字のID](sheet-id-keep-numbers-20260914.md)）で「活用・発音記号・派生語は、すでにある置き場を使う」
としていたが、そのうち活用と派生語の置き場は、この決定で取り消す。

## 決めたこと

**`04_extra_forms` と `04_extra_relations` をやめ、`01_core_senses` にまとめる。**
データごとに行やシートを分けず、1つの意味の行に複数のデータを収める。

| 項目 | 決定 |
|---|---|
| シート | `01_core_senses` に `inflections`・`synonyms`・`antonyms`・`derivatives`・`collocations`・`related` の列を足す。`04_` の2シートは使わない |
| 活用のセル | JSONオブジェクトをそのまま書く。例: `{"past":"ran"}` |
| 複数の項目が入るセル | `;` で区切る。例: `jog; sprint` |
| 関連語 | 残す。`word_meanings` に `related` 列を足す |
| DB | `word_forms`・`word_relations` の2表を消す。活用と関連語は `word_meanings` の列に入れる |
| 担当 | migrationと取りこみは USL-308 で行う |
| 発音記号 | これまでどおり `03_audio_pronunciations.ipa` |

## 理由

**入れる箱は、`word_meanings` にもうある。** 最初のスキーマ
（[`20260411000000`](../../supabase/migrations/20260411000000_create_current_baseline_schema.sql)）から、
`word_meanings` は `etymology`・`synonyms`・`antonyms`・`inflections`・`derivatives`・
`collocations` を持っている。アプリも類義語は `word_meanings.synonyms` から読んでいる。
`word_forms`・`word_relations` は、V5で後から足してbackfillした写しである。

**活用は品詞で変わる。** `light` は名詞なら `lights`、形容詞なら `lighter`・`lightest` になる。
単語ごとに1つだと、この違いを持てない。意味の行に置けば、品詞と活用が同じ行にそろう。

**シートの行き来が減る。** 1つの意味について知りたいことが、1つの行で見える。
シートを3枚開いて同じ `word_id` を探す必要がなくなる。

## 影響

- [`source-database-v5.md`](../content/source-database-v5.md) を6シートの構成に書き直す
- 同じ活用を、同じ品詞の別の意味にもう一度書くことがある。書き写しのずれは取りこみでは見つけられない
- 訳や補足の中で `;` を使えない
- 活用のJSONを手で書くので、括弧や引用符のまちがいが起きうる。取りこみ（USL-308）で読めなければ全体を止める
- 本番の `word_forms`・`word_relations` には、過去の50語ぶんが各50行入っている
  （[`import-official-content-production.md`](../operations/import-official-content-production.md)）。
  2表を消すことは本番データの削除にあたるので、本番への適用は別に実行承認を得る
- 次のファイルがこの2表を使っている。USL-308で直すか消す
  - [`scripts/prepare-official-content.py`](../../scripts/prepare-official-content.py)
  - [`supabase/tests/usl_280_source_database_v5.test.sql`](../../supabase/tests/usl_280_source_database_v5.test.sql)
  - [`scripts/sql/usl-286-rollback-merge.sql`](../../scripts/sql/usl-286-rollback-merge.sql)、[`scripts/sql/usl-286-rollback-production.sql`](../../scripts/sql/usl-286-rollback-production.sql)
- [`anki-50-extraction.md`](../content/anki-50-extraction.md) と過去の運用記録は、履歴なので書き換えない
