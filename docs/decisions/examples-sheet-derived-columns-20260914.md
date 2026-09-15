# 決定｜例文シートの画像の状態と順番の列は、取りこみで決める

決定日: 2026-09-14

## 決めること

シートの監査で、`02_content_examples` から `image_state` と `display_order` の列が消えていた。
設計書では必須のままだった。列をシートへ戻すか、取りこみで決めるかを決める。

あわせて、設計書で必須になっていた `01_core_words` の `created_at`・`updated_at` がシートにない件も決める。

## 決めたこと

**`02_content_examples` の `image_state`・`display_order` はシートに書かず、取りこみ（USL-308）で決める。**
DBの列はそのまま残す。

| DBの列 | 決め方 |
|---|---|
| `image_state` | `image_asset_path` があれば `present`、なければ `blank` |
| `display_order` | 同じ意味・同じコンセプトの行のうち、シートで上から何番目か（1始まり） |

**`01_core_words` の `created_at`・`updated_at` はシートに書かない。** DBが自動で入れる。

## 理由

[音声シートの状態・標準・順番の列は、取りこみで決める](audio-sheet-derived-columns-20260914.md) と同じ理由である。
状態はとなりの列に値があるかで決まり、順番は行の並びで表せる。人が別に書くと、ずれる。
状態と値が合わない行は、DBのCHECK制約
（[`20260831121553`](../../supabase/migrations/20260831121553_align_source_database_v5.sql) の
`example_contents_image_state_matches_path`）が拒む。

管理時刻は、人が書いても正しさを保証できず、DBの既定値で足りる。

## 影響

- [`source-database-v5.md`](../content/source-database-v5.md) から3列を外し、取りこみの決め方を書く
- 画像の `not_applicable`（作らない）と `unverified`（未確認）は、シートからは表せない。
  必要になったら、状態の列をシートへ戻す
