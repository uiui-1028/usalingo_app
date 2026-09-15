# かんたんマニュアル｜教材シートを Supabase へ同期する

教材の正本は Google Spreadsheet（`usgs_master_v5`）です。シートを直したら、このマニュアルの手順で Supabase へ写します。
流れは **シート → 同期スクリプト → Supabase → アプリ** の一方通行です。Supabase の教材を直接直さないでください。

くわしい仕組みは [`sync-sheet-to-supabase.md`](sync-sheet-to-supabase.md) にあります。

---

## 0. 最初に1回だけ

```sh
supabase login
```

ブラウザが開くので、Supabase にログインします。

---

## 1. 毎回やること（4ステップ）

ターミナルで、リポジトリを最新にしてから始めます。

```sh
cd ~/development/usalingo_app
git switch main
git pull
```

### ステップ1｜Supabase につながるか

```sh
supabase projects list
```

`Usalingo.app` が出ればOKです。

### ステップ2｜シートが読めて、中身が正しいか

```sh
python3 scripts/sync-sheet-to-supabase.py check
```

`sheet ok: ...` と出ればOKです。DB にはさわりません。
問題があると、どのシートの何行目かが並んで止まります。シートを直してから、もう一度流します。

### ステップ3｜本番でお試し（何も書きこまない）

```sh
python3 scripts/sync-sheet-to-supabase.py sync --target production --dry-run
```

`dry run ok (nothing was written)` と、数の表が出ればOKです。最後に取り消すので、本番は変わりません。

### ステップ4｜本番に同期する

```sh
python3 scripts/sync-sheet-to-supabase.py sync --target production --confirm-production udvmzaodsrgwecfybkry
```

最後に数の表が出れば完了です。何度流しても同じ結果になります。途中で失敗したら、何も入りません。

---

## 2. 結果の数の見方

| 項目 | 意味 | ふつうの値 |
|---|---|---|
| `words` / `meanings` / `examples` | シートから入れた行の数 | シートの行数と同じ |
| `images_present` | Storage に画像があった数 | 例文の数と同じ |
| `example_audio_present` | 例文の音声があった数 | 例文の数と同じ |
| `word_audio_present` | 単語の音声があった数 | 単語の数と同じ |
| `active_cards` | デッキのカードの数 | `04_deck_words` の行数と同じ |
| `hidden_cards` | デッキから外して隠したカード | 外した単語の数 |
| `meanings_not_in_sheet` | シートに無い古い意味 | **0**（0でなければアプリに古い意味が並ぶ） |
| `official_decks_not_in_sheet` | シートに無い公式デッキ | **0** |

`*_present` が足りないときは、そのファイルが Storage に無いか、名前が違います（下の3を見てください）。

---

## 3. 画像や音声を足したとき

ファイルを Storage に置いてから、**ステップ3・4をもう一度流します**。置いたファイルだけ「あり」に変わります。

### 名前の決まり

| 種類 | 置き場所と名前（番号1のとき） |
|---|---|
| 例文の画像 | `content-images/simple/000/example-000001.webp` |
| 例文の音声 | `content-audio/example/simple/000/example-000001.mp3` |
| 単語の音声 | `content-audio/word/000/pron-000001.mp3` |

- 番号は6けた。例文は `example_id`、単語の音声は `pronunciation_id`
- 棚（`000` の部分）は番号の頭3けた: 1〜999は `000`、1000〜1999は `001`
- 画像は WebP、音声は MP3 だけ

### Storage に入っているか数える

Supabase の SQL Editor で次を流します（読むだけです）。

```sql
select
  count(*) filter (where bucket_id = 'content-images' and name like 'simple/%/example-%.webp') as images,
  count(*) filter (where bucket_id = 'content-audio' and name like 'example/simple/%/example-%.mp3') as example_audio,
  count(*) filter (where bucket_id = 'content-audio' and name like 'word/%/pron-%.mp3') as word_audio
from storage.objects;
```

---

## 4. 困ったとき

| 出たメッセージ | 直し方 |
|---|---|
| `can't open file ... sync-sheet-to-supabase.py` | リポジトリのフォルダにいない、または古い。1 の `cd` と `git pull` からやり直す |
| `stopped: N problem(s) in the sheet` | 並んだ行をシートで直す |
| `path '...' must be '...'` | シートのパス列を、右側の形に直す |
| `sheet tabs not found` | シートのタブ名を戻す。共有が「リンクを知っている人は閲覧可」か確かめる |
| `a deck_id in 04_decks belongs to a personal deck` | 利用者が作ったデッキと番号がぶつかっている。`04_decks` の番号を変える |
| `violates ... constraint` など | 何も入っていない。表示された列をシートで直す |
| ログインや権限のエラー | `supabase login` をやり直す |

---

## 5. やってはいけないこと

- **Supabase の教材を直接書き換える** → 次の同期でシートの内容に戻る
- **同じ名前のファイルに別の中身を上書きする** → 利用者のスマホに古い絵や声が残る。中身を変えるときは番号を変える
- **学習が始まったあとに ID を付け替える** → 学習記録が別の単語を指してしまう
- **シートに秘密の値（`service_role` キーなど）を書く**
- **シートの共有を「制限付き」にする** → 同期がシートを読めなくなる
