# 教材シートを Supabase へ同期する手順

対象: USL-308。教材の正本 Google Spreadsheet（`usgs_master_v5`）→ Supabase。片方向。

> 手順だけ知りたいときは [かんたんマニュアル](sheet-sync-quick-manual.md) を見てください。

## 結論

```sh
# 1. シートを読んで確かめるだけ（DBに触らない）
python3 scripts/sync-sheet-to-supabase.py check

# 2. ローカルで試す（最後に取り消して、結果だけ見せる）
python3 scripts/sync-sheet-to-supabase.py sync --target local --dry-run

# 3. 本番で試す（書き込みは残らない）
python3 scripts/sync-sheet-to-supabase.py sync --target production --dry-run

# 4. 本番へ書く（実行前に人間の承認を得る）
python3 scripts/sync-sheet-to-supabase.py sync --target production \
  --confirm-production udvmzaodsrgwecfybkry
```

シートを直したら、同じコマンドをもう一度流すだけです。何度流しても同じ結果になります。

## 前提

| 条件 | 確かめ方 |
|---|---|
| Supabase CLI にログインしている | `supabase projects list` に `Usalingo.app` が出る |
| ローカル: Supabase が起動している | `supabase status` |
| migration `20260915100000_prepare_sheet_sync.sql` が当たっている | `supabase migration list` |
| シートが「リンクを知っている人は閲覧可」 | 決定: [`audio-path-built-by-import-20260915.md`](../decisions/audio-path-built-by-import-20260915.md) |

秘密の値（`service_role` キー、DBパスワード）は使いません。本番は CLI のログインで Management API
（`supabase db query --linked`）を通します。ローカルは `supabase db query --local` が1文しか受けつけないため、
ローカルDBのコンテナ（`supabase_db_<config.toml の project_id>`）の `psql` で流します。

## 何をするか

1. 8枚のシートを CSV で読む。タブはシートの名前で探す
2. 確かめる。1つでも問題があれば、**DBに触る前に全部を並べて止まる**
   - IDが1〜999999の数字か（`0001` も可）、同じシートで重複していないか
   - 参照先の行があるか、同じデッキに同じ単語が2回ないか
   - `inflections` がJSONオブジェクトか、`/&/` の間に空の項目がないか
   - パス列が [コンテンツ契約](../architecture/official-content-contract.md) の形か
3. 1トランザクションのSQLを作り、IDごとに上書きする。制約に当たれば何も入らない

| シート | DB | 決め方 |
|---|---|---|
| `02_content_concepts` | `content_concepts` | そのまま |
| `01_core_words` | `words` | そのまま |
| `01_core_senses` | `word_meanings` | 一覧の列は `/&/` で区切る。`derivatives`・`collocations` はJSON配列、`inflections` はJSONオブジェクト |
| `02_content_examples` | `example_contents` | 画像は Storage にあれば `present` とパス、なければ `blank` と空。例文音声のパスも入れる（アプリの互換） |
| `03_audio_pronunciations` | `word_pronunciations` | `voice_label` が空の行は飛ばす。`accent` は `US` |
| `03_audio_example_audio` | `example_audio` | `voice_label` が空の行は飛ばす |
| `04_decks` | `decks` | 個人デッキの番号なら止まる |
| `04_deck_words` | `cards` | 出題形式ごとに1枚。行の並び＝`sort_order`（0始まり）、`sense_id`＝`primary_meaning_id` |

- 状態（`present`/`blank`）・標準の声・順番は、シートに書かず同期が決める
- **シートから消した行はDBから消さない。** デッキから外した単語のカードだけ `is_active = false` にする

## 画像と音声を置いたあと

Storage にファイルを置いたら、もう一度 `sync` を流します。置いたファイルだけ `present` に変わります。
ファイル名は契約の形です（例: `content-images/simple/000/example-000001.webp`）。

## 結果の読み方

最後に次の数が出ます。

| 項目 | 意味 |
|---|---|
| `words` / `meanings` / `examples` | シートから入れた行数 |
| `images_present` / `example_audio_present` / `word_audio_present` | Storage にファイルがあった数 |
| `active_cards` / `hidden_cards` | シートのデッキのカード。隠したカードは学習記録のために残る |
| `meanings_not_in_sheet` | シートの単語なのに、シートに無い意味。**0でなければアプリに古い意味が並ぶ**。消すのは別に承認を得る |
| `official_decks_not_in_sheet` | シートに無い公式デッキ。同期は触らない |

## 本番の注意

- `--dry-run` なしで本番へ書くときは、実行前に人間の承認を得る（`--confirm-production` が無いと拒否する）
- 生成SQLには教材本文が入る。`render` で書き出した場合も Git へ追加しない

## 困ったとき

| 表示 | 直し方 |
|---|---|
| `stopped: N problem(s) in the sheet` | 並んだ行をシートで直す |
| `sheet tabs not found` | タブの名前を戻す、または共有設定を確かめる |
| `a deck_id in 04_decks belongs to a personal deck` | `04_decks` の番号を、公式デッキの番号にする |
| 制約違反（`violates check constraint` など） | 何も入っていない。表示の列をシートで直す |
