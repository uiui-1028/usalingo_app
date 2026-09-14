# 決定｜音声シートの状態・標準・順番の列は、取りこみで決める

決定日: 2026-09-14

## 決めること

`03_audio_pronunciations` と `03_audio_example_audio` には、人が書く列のほかに、
ほかの列や行の並びから決められる列がある。シートの列をできるだけ減らすため、
これらを人が書き続けるかを決める。

## 決めたこと

**次の列をシートから消し、取りこみ（USL-308）で自動で決める。** DBの列はそのまま残す。

| シート | 消す列 |
|---|---|
| `03_audio_pronunciations` | `ipa_state`、`audio_state`、`is_primary`、`display_order` |
| `03_audio_example_audio` | `audio_state`、`is_primary`、`display_order` |

| DBの列 | 決め方 |
|---|---|
| `ipa_state` | `ipa` があれば `present`、なければ `blank` |
| `audio_state` | `audio_asset_path` があれば `present`、なければ `blank` |
| `display_order` | 同じ単語（例文音声は同じ例文）の行のうち、シートで上から何番目か（1始まり） |
| `is_primary` | 同じ単語（例文）の行のうち、シートで一番上の行だけ `true` |

## 理由

**書かなくても決まる列を人が書くと、ずれる。** 状態はとなりの列に値があるかどうかで決まる。
順番と標準の声は、シートの行の並びで表せる。人が別に書くと、値を消したのに状態が
`present` のまま、という食い違いが起きる。

**DBの門番は残る。** DBには、状態と値が合わない行を拒むCHECK制約
（[`20260831121553`](../../supabase/migrations/20260831121553_align_source_database_v5.sql) の
`*_matches_value`・`*_matches_path`）と、標準の声を1件までにする一意インデックスがある。
取りこみで決めた値もこの門番を通る。

## 影響

- [`source-database-v5.md`](../content/source-database-v5.md) の2シートの列を減らす
- `not_applicable`（作らない）と `unverified`（未確認）は、シートからは表せなくなる。
  必要になったら、状態の列をシートへ戻す
- 標準の声を変えるときは、シートの行の並びを入れ替える
- USL-308 に入っていた「状態と値のCHECK制約を足す（旧USL-307）」は、制約がすでにあるため、
  効いていることの確認に置き換える
