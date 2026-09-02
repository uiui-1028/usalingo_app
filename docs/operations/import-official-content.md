# 公式教材50語をローカルDBへ入れる手順

対象: USL-286 / TARGET-1900の原本番号1〜50

## 結論

Anki原本は直接変更せず、読取用コピーから中間JSONを作り、検査に合格した場合だけ
ローカルSupabase用SQLを生成します。同じSQLは何度実行しても同じ固定IDを更新するため、
単語、意味、例文、音声、Cardが重複しません。

2026-09-02以降、50語の正本は [`../content/target-1900-0001-0050.json`](../content/target-1900-0001-0050.json)
です。**通常はステップ1・2を飛ばし、この正本JSONからステップ3へ進みます。** ステップ1・2は、
Ankiから取り直す必要が生じたときだけ使います。経緯は
[`../decisions/usl-286-repo-owned-content.md`](../decisions/usl-286-repo-owned-content.md) にあります。

生成SQLには教材本文が展開されるため、Gitへ追加せず `/private/tmp` などの一時領域に置きます。
正本JSONはUSL-284の権利確認を経てリポジトリへ入れていますが、生成物は入れません。本番DB・
本番Storageにはこの手順を使いません。

## 変換の流れ

```text
docs/content/target-1900-0001-0050.json（正本）
  → 固定IDと衝突検査を持つ1トランザクションSQL
  → ローカルSupabase

# Ankiから取り直すときだけ通る道
Anki collection.anki2 の読取用コピー
  → 必須値・番号・品詞・media 150件を検査した中間JSON
  → 正本との差分を確認して正本を更新
```

変換規則の正本は [`anki-50-extraction.md`](../content/anki-50-extraction.md)、DB列は
[`source-database-v5.md`](../content/source-database-v5.md)、予定Storageパスは
[`usl-283-media-delivery.md`](../decisions/usl-283-media-delivery.md) です。

## 1. Ankiの読取用コピーを作る（取り直すときだけ）

Ankiを終了してから実行します。profile名が違う場合は、推測せず実際の場所へ読み替えます。
Ankiの原本へは書き込みません。教材の修正は正本JSON側で行います。

```sh
cp "$HOME/Library/Application Support/Anki2/Anki｜Taiga（taiyahehe）/collection.anki2" \
  /private/tmp/usalingo-286-anki-readonly.anki2
chmod 644 /private/tmp/usalingo-286-anki-readonly.anki2
```

コピー先だけを読みます。元の `collection.anki2` へは書き込みません。

## 2. 中間JSONを作って検査する（取り直すときだけ）

```sh
python3 scripts/prepare-official-content.py extract-anki \
  --collection /private/tmp/usalingo-286-anki-readonly.anki2 \
  --media-dir "$HOME/Library/Application Support/Anki2/Anki｜Taiga（taiyahehe）/collection.media" \
  --output /private/tmp/usalingo-286-content.json

python3 scripts/prepare-official-content.py validate \
  --input /private/tmp/usalingo-286-content.json
```

`errors=0` と `valid: 50 entries...` の両方が必要です。エラー時はSQLを作りません。
エラーには、50件不足、番号・単語・GUID重複、必須文字の欠損、未知の品詞、品詞と意味の
分割数不一致、画像・単語音声・例文音声の参照切れが行番号付きで出ます。

複数senseの行では、例文をpriority 1へ接続したという警告が出ます。ローカル構造確認には
使えますが、本番公開前に意味と例文の対応を人間が確認します。2026-09-02にこの22件を全件
照合し、3件（concern / limit / challenge）を正本JSON側で直しました。詳細は
[`../decisions/usl-286-repo-owned-content.md`](../decisions/usl-286-repo-owned-content.md)
にあります。取り直したときは、この3件が消えていないかを差分で確認します。

## 3. ローカル用SQLを作る

```sh
python3 scripts/prepare-official-content.py render-sql \
  --input docs/content/target-1900-0001-0050.json \
  --output /private/tmp/usalingo-286-content.sql
```

Ankiから取り直した場合だけ `--input` を `/private/tmp/usalingo-286-content.json` に読み替え、
先に正本との差分を確認します。

SQLは最初に、既存行が予約ID帯（word 1001〜1050、example 3001〜3050など）、
Anki GUID、原本位置、英単語を別内容で使っていないか
調べます。衝突時はトランザクション全体を停止します。画像と音声はUSL-288で変換・配置する
予定パスを保存し、配置確認前なので状態を `unverified` にします。変換、Storage登録、匿名での
読戻し、状態更新は [`deliver-official-media.md`](deliver-official-media.md) に続きます。

## 4. ローカルSupabaseへ2回入れる

このDB resetは `--local` だけを対象にします。ほかのローカル作業がDBを使っていないことを
確認してから実行します。

```sh
./scripts/test-local-db.sh

docker cp /private/tmp/usalingo-286-content.sql \
  supabase_db_usalingo-local:/tmp/usalingo-286-content.sql

docker exec supabase_db_usalingo-local \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/usalingo-286-content.sql

docker exec supabase_db_usalingo-local \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -f /tmp/usalingo-286-content.sql
```

2回とも `COMMIT` にならない場合は完了にしません。

## 5. 件数と接続を確認する

```sh
docker exec -i supabase_db_usalingo-local \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<'SQL'
select count(*) as words
from public.words
where source_deck_code = 'target-1900-image' and source_position between 1 and 50;

select count(*) as deck_words from public.deck_words where deck_id = 286;
select count(*) as active_cards from public.cards where deck_id = 286 and is_active;

select count(*) as broken_relations
from public.words words
left join public.word_meanings meanings on meanings.word_id = words.id
left join public.example_contents examples on examples.meaning_id = meanings.id
left join public.word_pronunciations pronunciations on pronunciations.word_id = words.id
where words.source_deck_code = 'target-1900-image'
  and words.source_position between 1 and 50
  and (meanings.id is null or examples.id is null or pronunciations.id is null);
SQL
```

`words=50`、`deck_words=50`、`active_cards=50`、`broken_relations=0` が合格です。
投入SQL自身も同じ検査を行い、不一致ならcommit前に停止します。

## 今回しないこと

- 中間JSONや生成SQLをGitへ追加する
- 本番SupabaseへSQLを実行する
- 本番またはローカルStorageへ素材をアップロードする
- 複数senseの例文対応や素材の公開権利を自動で決める

本番投入は、USL-284の権利確認、USL-288のmedia変換・配置・読戻し、対象行と切り戻し方法の
提示、明示承認がそろった別作業で行います。
