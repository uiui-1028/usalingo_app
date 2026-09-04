# 公式教材50語を本番Supabaseへ入れる手順

対象: USL-286 / USL-288 の本番投入。TARGET-1900の原本番号1〜50

> [!IMPORTANT]
> **2026-09-04に前提が変わりました。** 本番には手作業で入れた1000語がすでにあり、その
> **1〜50は今回の50語と同じ英単語**でした（例文まで一致）。`words.word_text` は UNIQUE
> なので、新規投入（`render-sql`、ID帯 1001-1050）は**使えません**。
> 既存の1〜50を差し替える [「A. 既存50語を差し替える」](#a-既存50語を差し替える) を使ってください。
> 下の新規投入手順は、まっさらな環境へ入れる場合の記録として残しています。

## 結論

正本JSONから1トランザクションのSQLを作り、本番の固定ID帯へ新規投入します。既存の
`Starter Deck`（1000語）とはデッキIDもID帯も重ならないため、既存データは消しません。
投入したあと、Storageの読戻しreceiptと一致した場合だけmedia状態を `present` にします。

ローカル用は [`import-official-content.md`](import-official-content.md)、Storage登録は
[`deliver-official-media.md`](deliver-official-media.md) です。**この文書は本番だけを扱います。**

## 前提（すべて満たしてから始める）

| 条件 | 状態（2026-09-02時点） |
|---|---|
| USL-284の権利確認が `done` | 済。[`../decisions/usl-284-material-rights.md`](../decisions/usl-284-material-rights.md) |
| Google Cloud TTSの商用利用可否 | 権利者の判断で可 |
| 正本JSONが最新 | [`../content/target-1900-0001-0050.json`](../content/target-1900-0001-0050.json) |
| 複数sense 22語の意味づけ確認 | 済。3件修正。[`../decisions/usl-286-repo-owned-content.md`](../decisions/usl-286-repo-owned-content.md) |
| 本番Storageに150件が登録済み | 済。匿名GET・SHA-256とも150/150 |
| 本番の対象ID帯が空 | 要再確認（下の手順1） |
| 投入対象行とrollbackを示した承認 | **実行のたびに取り直す** |

## 投入するもの

| テーブル | 件数 | ID帯 |
|---|---:|---|
| `decks` | 1 | `id = 286` |
| `words` | 50 | `1001`〜`1050` |
| `word_meanings` | 73 | `2000 + position*10 + priority` |
| `example_contents` | 50 | `3001`〜`3050` |
| `word_pronunciations` | 50 | `4001`〜`4050` |
| `example_audio` | 50 | `5001`〜`5050` |
| `deck_words` | 50 | `deck_id = 286` |
| `cards` | 50 | `deck_id = 286` |
| `word_forms` / `word_relations` | 各50 | `word_id 1001`〜`1050` |

デッキの `license` は `proprietary-rights-holder`、`description` は権利者が生成AIで作成した旨を
入れます。検証用の文言（`local verification batch` / `rights-review-pending`）は本番へ出しません。

## 1. 本番の対象ID帯が空であることを確かめる

投入直前に必ず実行します。1件でも0でなければ止めて、原因を調べます。

```sql
select 'decks 286' k, count(*) n from decks where id=286
union all select 'words 1001-1050', count(*) from words where id between 1001 and 1050
union all select 'word_meanings 2001-2510', count(*) from word_meanings where id between 2001 and 2510
union all select 'example_contents 3001-3050', count(*) from example_contents where id between 3001 and 3050
union all select 'word_pronunciations 4001-4050', count(*) from word_pronunciations where id between 4001 and 4050
union all select 'example_audio 5001-5050', count(*) from example_audio where id between 5001 and 5050
union all select 'deck_words 286', count(*) from deck_words where deck_id=286
union all select 'cards 286', count(*) from cards where deck_id=286
union all select 'words source_deck_code', count(*) from words where source_deck_code='target-1900-image'
order by k;
```

生成SQL自体も、予約ID帯・Anki GUID・原本位置・英単語が別内容で使われていないかを最初に調べ、
衝突すればトランザクション全体を停止します。

## 2. 投入SQLを作る

```sh
python3 scripts/prepare-official-content.py render-sql \
  --input docs/content/target-1900-0001-0050.json \
  --output /private/tmp/usalingo-286-production.sql
```

生成物には教材本文が展開されます。**Gitへ追加しません。**

## 3. 承認を取る

次を示して、DB書き込みの承認を得ます。Storage登録の承認とは別です。

- 上の「投入するもの」の表（テーブル・件数・ID帯）
- 手順1の結果（全件0であること）
- 切り戻し方法（下記）

## 4. 投入する

Supabaseダッシュボードの SQL Editor、または `psql` で
`/private/tmp/usalingo-286-production.sql` を実行します。1トランザクションなので、
途中で止まれば何も入りません。

## 5. media状態を `present` にする

Storageの登録は済んでいますが、状態更新には**manifestに対応するreceipt**が要ります。
2026-09-02の本番登録では端末側が中断されreceiptが残っていないため、`sync` を
もう一度実行して作り直します。**再実行は新規アップロードを行いません**（同じSHA-256の
objectは再利用され、`uploaded 0 / already matching 150` になります）。

```sh
python3 scripts/prepare-official-media.py sync \
  --manifest /private/tmp/usalingo-288-media/manifest.json \
  --asset-root /private/tmp/usalingo-288-media \
  --supabase-url https://udvmzaodsrgwecfybkry.supabase.co \
  --receipt /private/tmp/usalingo-288-prod-receipt.json \
  --allow-remote
```

service role keyは環境変数 `SUPABASE_SERVICE_ROLE_KEY` から読みます。コマンドへ書かず、
終わったら `unset` します。

```sh
python3 scripts/prepare-official-media.py render-state-sql \
  --manifest /private/tmp/usalingo-288-media/manifest.json \
  --receipt /private/tmp/usalingo-288-prod-receipt.json \
  --output /private/tmp/usalingo-288-media-present.sql
```

receiptが150件未満、またはmanifestと一致しない場合、SQLは作られません。作られたSQLを
本番で実行し、50画像・50単語音声・50例文音声の状態を `present` にします。

## 6. 完了確認

```sql
select
  (select count(*) from words where id between 1001 and 1050) words,
  (select count(*) from cards where deck_id=286 and is_active) cards,
  (select count(*) from example_contents where id between 3001 and 3050 and image_state='present') images,
  (select count(*) from word_pronunciations where id between 4001 and 4050 and audio_state='present') word_audio,
  (select count(*) from example_audio where id between 5001 and 5050 and audio_state='present') example_audio;
```

50 / 50 / 50 / 50 / 50 になること。そのうえで、**再起動した実機アプリ**で対象デッキを開き、
画像の表示、単語音声、例文音声を確認します。SQLの件数は配信の証明にならないため、
実機確認を別の証拠として記録します。

## 切り戻し

[`../../scripts/sql/usl-286-rollback-production.sql`](../../scripts/sql/usl-286-rollback-production.sql)
を実行します。固定ID帯だけを消し、ほかのデッキ・単語には触りません。

このSQLには番人が入っています。次のどちらかがあれば、**何も消さずに停止**します。

- 対象デッキのカードを誰かが学習している（`user_card_progress` が RESTRICT）
- 対象単語に個人の上書きやタグがある（`user_word_overrides` / `user_word_tags` が CASCADE）

つまり**利用者が触る前なら確実に戻せますが、触ったあとは利用者データの削除承認が別に要ります**。
投入後に配布して学習が始まると、切り戻しの難易度が上がる点を承知して進めます。

Storageの150 objectはこのSQLでは消えません。必要なら
`/private/tmp/usalingo-288-paths.json` の一覧を示して別途承認を得ます。

### 切り戻しの検証結果（2026-09-04・ローカルSupabase）

50語一式が入ったローカルDBで3通り試し、いずれも期待どおりだった。**本番では未実行。**

| 試験 | 仕込み | 結果 |
|---|---|---|
| 1 | `user_word_tags` を1件（word 1001） | `USL-286 rollback stopped: 0 user_word_overrides and 1 user_word_tags rows would be cascade-deleted` で停止。**1行も消えず** |
| 2 | `user_card_progress` を1件（deck 286のcard） | `USL-286 rollback stopped: 1 user_card_progress rows depend on deck 286` で停止。**1行も消えず** |
| 3 | 利用者データ 0件 | `DELETE 50 / 50 / 50 / 1` のあと消え残り検査を通過してCOMMIT |

試験3の前後の全件数。対象だけが消え、他のデッキ・単語は残った。

```text
          decks words meanings examples pron exaudio deck_words cards forms relations
before        2    51       74       51   50      50         51    51    50        50
after         1     1        1        1    0       0          1     1     0         0
restored      2    51       74       51   50      50         51    51    50        50
```

`restored` は `render-sql` の出力をもう一度流した結果で、`before` と完全に一致する。
つまり**この切り戻しは、同じSQLで元に戻せる**。試験用に作った利用者・タグ・学習履歴は
すべて削除済みで、ローカルDBは試験前の状態に戻している。

## A. 既存50語を差し替える

本番の `words.id` 1〜50 は、権利者が手作業で入れた同じ50語です。新規投入の代わりに、
その行を正本JSONの内容へ更新します。

### 何が変わるか

| 対象 | 変わること |
|---|---|
| `words` 1-50 | `source_note_guid` / `source_deck_code` / `source_position` が入り、**Ankiのどのカード由来かたどれる**ようになる |
| `word_meanings` | `挑戦する／挑戦` のような1本の文字列を、**意味ごとの行へ分割**（50行 → 73行）。concern の定義の誤りもここで直る |
| `example_contents` | 例文の本文だけ合わせる |
| `word_pronunciations` | **単語音声が入る**。本番は1000件すべて `blank` で、発音が配信されていない |
| `word_forms` / `word_relations` | 0行 → 各50行 |

### 何を変えないか

**画像と例文音声のパスは触りません。** `example_contents` の
`*_asset_path_contract` は、パスの末尾を行のidから決めています（id=1 なら
`.../0000-0499/1.webp`）。USL-288で登録した `3000-3499` / `4000-4499` のファイルは、
この契約上どうしても 1〜50 の行から指せません。既存の配信を止めないため、画像と例文音声は
手作業版のまま残します。単語音声だけはパスの形が縛られていないので、登録済みファイルを
指せます。

USL-288で登録した画像50件と例文音声50件は、当面どこからも参照されません。

### 手順

```sh
python3 scripts/prepare-official-content.py render-merge-sql \
  --input docs/content/target-1900-0001-0050.json \
  --output /private/tmp/usalingo-286-merge.sql
```

差し替えSQLは、更新の前に**同じトランザクションの中で差し替え前の値を
`public.usl286_pre_merge_snapshot` へ控えます**。人が値を書き写さないので、転記ミスで
戻せなくなることがありません。2回目以降の実行は最初の控えを残します。

番人が次を確かめ、1つでも合わなければ何も更新しません。

- 差し替え先が、同じidかつ同じ英単語の既存行であること
- 同じ英単語を別のidの行が持っていないこと
- 意味・例文・発音・例文音声の既存行がそろっていること
- 追加する2つ目以降の意味が、別の単語の行を奪わないこと
- Anki GUIDを別の単語が持っていないこと
- 控えがちょうど50件になったこと

### 切り戻し

[`../../scripts/sql/usl-286-rollback-merge.sql`](../../scripts/sql/usl-286-rollback-merge.sql)
を実行します。控えの表から元の値へ戻し、追加した意味・活用・関連を消します。
**`words` 行を消さないので、利用者のメモ・タグ・学習履歴は巻き込まれません**（単語ごと消す
`usl-286-rollback-production.sql` とは別物です）。

### 検証結果（2026-09-04・使い捨てDB）

作業用ローカルDBには触らず、`usl286_test` を作って本番と同じ形（意味50行・活用0行・
単語音声 `blank`）の試験台を組み、往復させた。**本番では未実行。**

```text
              意味 活用 関連 単語音声present 追跡情報あり  id=17の定義
BEFORE          50    0    0              0            0  関係する、心配させる／関心、懸念
MERGED          73   50   50             50           50  関係する、心配させる
ROLLED BACK     50    0    0              0            0  関係する、心配させる／関心、懸念
```

`BEFORE` と `ROLLED BACK` が完全一致した。差し替えを2回続けて流しても件数が変わらないこと
（冪等）も確認済み。試験後に `usl286_test` は削除し、作業用ローカルDBは無傷。

## この手順に含めないこと

- 51語目以降の投入
- `Starter Deck`（1000語）の削除・整理
- bucket設定、policy、公開範囲の変更
- [`../legal/published/credits.md`](../legal/published/credits.md) の更新。第3節・第4節が
  本番の実態とずれている件は別課題として扱う
