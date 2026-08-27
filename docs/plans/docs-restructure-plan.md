# `docs/` 整理 実行計画書

状態: **計画（未着手・実施の合図待ち）**

作成日: 2026-08-27

対象: `docs/` 配下すべて

> [!IMPORTANT]
> この計画では**移動と削除だけ**を行い、文章の中身は書き直しません。同時にやると、差分が大きくなって確認できなくなります。

## いまの状態（実測）

`docs/` にはMarkdownが68ファイル、合計9,259行あります。PDFが5点、別にあります。

| 場所 | ファイル数 | 行数 | 性質 |
|---|---|---|---|
| `Usalingo｜Specification Ver.2.0/` | 21 | 2,526 | 旧仕様。うち10ファイル（50行）は移動案内だけの空っぽ |
| `archive/` | 8 | 2,386 | 履歴。入口READMEあり |
| `supabase/` | 3 | 1,116 | うち997行は教材データの原本設計（現行で使う） |
| `workflow-records/` | 13 | 877 | 終わった策定作業の記録 |
| `usalingo-workflow-planning-execution-plan.md` | 1 | 344 | 上の作業のための計画書。役目は終わっている |
| `architecture/` | 4 | 823 | 現行の正本 |
| `decisions/` | 5 | 530 | 決定の記録 |
| `rules/` | 3 | 218 | 開発ルール |
| その他 | 10 | 439 | 入口、製品計画、品質ゲート、調査、手順書 |

**履歴（`archive` と `Ver.2.0`）だけで全体の53%を占めています。** いま作っているものを判断するために毎回読む必要がある文書は、実際には2,000行ほどです。

## 見つかった問題

1. **入口が二重になっている。** 履歴の入口が `archive/README.md` と `Usalingo｜Specification Ver.2.0/README.md` の2か所にあり、`docs/README.md` が両方を案内しています。どちらを見ればよいのか決まりません。

2. **ファイル名の事故がある。**
   - `Usalingo｜Specification Ver.2.0/usalingo_05_aigc_policy.md/` は、`.md` で終わる**ディレクトリ**です。中に同じ名前のファイルが入っています。
   - `usalingo_01_business_requirements.md.md` は拡張子が二重で、隣に本体の `usalingo_01_business_requirements.md` があります。

3. **パスに全角記号と空白が入っている。** `Usalingo｜Specification Ver.2.0`、`Fo｜02｜Terms of Use`、`Usalingo 英単語原本データベース V5 設計書.md`。`｜` と空白は、検索、シェル、相対リンク、将来のCIで壊れます。この調査中も、実際に行数を数えるコマンドが一度失敗しました。

4. **終わった作業の記録が、現行の棚に置いてある。** `workflow-records/` と `usalingo-workflow-planning-execution-plan.md` は、ワークフローを決めるための作業記録です。結論は [`decisions/usalingo-core-workflow-requirements.md`](../decisions/usalingo-core-workflow-requirements.md) に出ています。役目は終わっています。

5. **成果物と文書が混ざっている。** `Fo｜02｜Terms of Use/` のPDF 5点は「読むための文書」ではなく「公開する成果物」です。

6. **「最終更新日」を手で書いている。** `technology-stack.md` は2026-08-15のままでした。手書きの日付は必ず古くなります。

## 初心者向けの原則（3つだけ）

置き場所で迷ったら、この3つに当てはめます。

### 1. 正本は1つ

同じことを2か所に書きません。片方は必ずリンクにします。2か所にあると、片方だけ直したときに、どちらが正しいか分からなくなります。

### 2. 文書を「寿命」で分ける

内容ではなく、**いつまで有効か**で棚を分けます。

| 寿命 | 例 | 棚 |
|---|---|---|
| ずっと変わらない | 何を作るか、誰のために作るか | `product/` |
| いま有効（変わったら書き換える） | データ構造、契約、開発環境 | `architecture/` `operations/` `content/` |
| 一度書いたら書き換えない | 決定の記録、これからの計画 | `decisions/` `plans/` |
| もう有効ではない | 旧仕様、終わった作業記録 | `archive/` |

書き換える棚と、書き換えない棚を混ぜないことが要点です。

### 3. 毎回読ませる文書を小さく固定する

生成AIが毎回読む文書は、**入口1枚とルール1枚**に固定します。それ以外は必要になったときだけ開きます。ここが大きいほど、毎回のコストが増えます。

## 目指す形

```text
docs/
├── README.md              # 入口。20行以内。毎回読む唯一の文書
├── product/               # 何を作るか
│   ├── plan.md            # ← usalingo-simple-product-plan.md
│   └── workflow.md        # ← decisions/usalingo-core-workflow-requirements.md
├── architecture/          # いまの仕様の正本（そのまま）
│   ├── anki-aligned-spec.md
│   ├── anki-data-model.md
│   ├── official-content-contract.md
│   └── account-deletion-contract.md
├── content/               # 教材データの作り方
│   └── source-database-v5.md   # ← supabase/Usalingo 英単語原本データベース V5 設計書.md
├── decisions/             # 1決定1ファイル。過去は消さない
├── plans/                 # これからやること（本計画で新設済み）
├── operations/            # 開発環境・ルール・手順書をここへ統合
│   ├── repository-layout.md
│   ├── technology-stack.md
│   ├── supabase-local-development.md
│   ├── sql-rules.md
│   ├── credit-optimization.md
│   ├── release-quality-gate.md
│   └── runbooks/
├── legal/                 # 公開文書の原本と素材台帳
│   ├── README.md
│   └── source/            # ← Fo｜02｜Terms of Use/ のPDF
└── archive/               # 履歴。ここから現行資料へリンクしない
    ├── README.md          # 旧パス対応表もここに1枚だけ置く
    ├── legacy-spec-v2/
    ├── legacy-spec-v2-business/   # ← Ver.2.0 の事業・コンテンツ・デザイン
    └── workflow-records/          # ← workflow-records/ と実行計画書
```

棚は9つです。増やしません。迷ったら `decisions/` に日付つきで置いて、あとで移します。

## 移動と削除の対応表

| いまの場所 | 行き先 | 理由 |
|---|---|---|
| `usalingo-simple-product-plan.md` | `product/plan.md` | 変わりにくい方向づけ |
| `decisions/usalingo-core-workflow-requirements.md` | `product/workflow.md` | 決定というより現行の製品仕様。決定記録としては `decisions/` にリンクを残す |
| `architecture/*` | そのまま | 正本 |
| `supabase/Usalingo 英単語原本データベース V5 設計書.md` | `content/source-database-v5.md` | 現行で使う。名前を半角に |
| `supabase/local-development.md` | `operations/supabase-local-development.md` | 開発環境の手順 |
| `supabase/README.md` | 削除 | 入口が減るので `docs/README.md` に統合 |
| `rules/*` | `operations/` | ルールも運用 |
| `rules/README.md` | 削除 | 同上 |
| `release-quality-gate.md` | `operations/` | 運用 |
| `runbooks/` | `operations/runbooks/` | 運用 |
| `development/*` | `operations/` | 運用 |
| `research/usl-249-*.md` | `legal/asset-and-privacy-inventory.md` | 法務まわりの台帳として使い続ける |
| `Fo｜02｜Terms of Use/*.pdf` | `legal/source/` | 半角名へ。中身は触らない |
| `workflow-records/` | `archive/workflow-records/` | 終わった作業の記録 |
| `usalingo-workflow-planning-execution-plan.md` | `archive/workflow-records/` | 上と同じ作業の計画書 |
| `Usalingo｜Specification Ver.2.0/` の実体11ファイル | `archive/legacy-spec-v2-business/` | 旧仕様。半角名へ |
| `Usalingo｜Specification Ver.2.0/` の移動案内10ファイル | **削除** | 中身がなく、行き先は `archive/README.md` の対応表で足りる |
| `Usalingo｜Specification Ver.2.0/usalingo_05_aigc_policy.md/`（ディレクトリ） | **削除** | 事故。中身は `archive/legacy-spec-v2/aigc-policy.md` にある |
| `usalingo_01_business_requirements.md.md` | **削除** | 二重拡張子。本体が隣にある |

削除は10〜13ファイル、いずれも中身が別の場所にあるものだけです。**内容が1か所にしかない文書は削除しません。**

### 迷ったときの判断

その文書について3つ聞きます。

1. いまの実装を判断するのに使うか。
2. その内容の正本はこの文書か（他にないか）。
3. 3か月以内に読んだか。

- 1つでも「はい」なら残す。
- 全部「いいえ」なら `archive/` へ。
- 全部「いいえ」で、しかも同じ内容が `archive/` にすでにあるなら削除する。

## 進め方

| 手順 | 内容 | 誰が |
|---|---|---|
| 1 | 68ファイルを「正本 / 履歴 / 重複 / 削除」に仕分けた表を作り、上の対応表を確定する。1ディレクトリずつ確認する | AIが下書き、人間が確定 |
| 2 | 安全な削除から。移動案内10ファイルと、ディレクトリ名の事故、二重拡張子を消す。消す前に `git log` で中身が別の場所にあることを確認する | AI |
| 3 | `git mv` で移す。**1つのプルリクエストでまとめて動かす。** 分けると、参照が切れている期間が長くなる | AI |
| 4 | リンクを直す。`grep -rn "](.*\.md)" docs` で相対リンクを全部見る。`README.md` からの導線も直す | AI |
| 5 | `docs/README.md` を20行以内に作り直す。`operations/repository-layout.md` の `docs/` ツリーを新しい形に更新する | AI |
| 6 | 「新しい文書をどこに置くか」を `operations/repository-layout.md` に1節足す。原則3つをそのまま書く | AI |
| 7 | `AGENTS.md` が指す「毎回読む文書」を `docs/README.md` と `operations/credit-optimization.md` の2つに固定する | AI |

### 手順3で使うコマンドの形

```bash
git mv "docs/usalingo-simple-product-plan.md" "docs/product/plan.md"
```

`git mv` を使うと履歴がつながります。消して作り直すと、その文書の経緯が追えなくなります。

## やらないこと

- 文章の書き直し。移動と削除だけです。
- 履歴文書の内容の要約や圧縮。読まなくてよい場所へ移すだけで目的は達成します。
- Notionとの構造の統一。今回はリポジトリの中だけを扱います。

## 完了のしるし

- `docs/` 直下にあるMarkdownは `README.md` 1つだけになる。
- `docs/README.md` が20行以内で、9つの棚をそれぞれ1行で案内している。
- 現行として読む文書（`archive/` 以外）が2,000行以内に収まる。
- パスに全角記号と空白を含むファイルが1つもない。
- `grep -rn "](.*\.md)" docs` で見つかる相対リンクが、すべて実在するファイルを指す。
- `operations/repository-layout.md` の `docs/` ツリーが実際の構造と一致する。

## 気をつけること

**Notionや過去のリンクが切れます。** いまの移動案内10ファイルは、そのために置かれたものです。同じ役目は `archive/README.md` の「旧パス対応表」1枚で果たせます。10ファイルを維持するより、表1つの方が管理できます。

## いつやるか

[`external-package-adoption-plan.md`](external-package-adoption-plan.md) の領域0より**先**に、単独のプルリクエストで行うことを勧めます。理由は2つです。

- 整理してから作業を始めた方が、以後の毎回の読み込みが軽くなります。
- コードを触る作業と同時に動かすと、どちらが原因で何が壊れたのか分からなくなります。

## 見直す条件

- 棚が9つで足りなくなったとき（増やす前に、既存の棚に入らない理由を書く）。
- Notionをリポジトリより上位の正本にすると決めたとき。
- CIで文書の検査を始めるとき（リンク切れ検査を手順4の代わりにする）。
