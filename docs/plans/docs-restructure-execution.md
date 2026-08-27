# `docs/` 整理 実施計画書（作業手順）

状態: **実施待ち**

作成日: 2026-08-27

前提: [`docs-restructure-plan.md`](docs-restructure-plan.md)（なぜ整理するか）

> [!IMPORTANT]
> この作業では**動かす・消す・リンクを直す**の3つだけを行います。文章の中身は1文字も書き直しません。

## いまの数（実測）

| 項目 | 数 |
|---|---|
| Markdown | 65ファイル / 9,287行 |
| PDF | 5ファイル |
| うち履歴（`archive/` と `Ver.2.0/`） | 29ファイル / 4,912行（**53%**） |
| 移動後に消えるファイル | 13 |
| リンクを直す必要があるファイル | 18（うち4つは `docs/` の外） |

## 作業のまとめ

- 新しく作る棚: `product/` `content/` `operations/` `legal/`（`plans/` は作成済み）
- なくなる棚: `rules/` `development/` `research/` `runbooks/` `supabase/` `workflow-records/` `Usalingo｜Specification Ver.2.0/` `Fo｜02｜Terms of Use/`
- 残る棚: `architecture/` `decisions/` `archive/` `plans/`

最終的に `docs/` 直下のMarkdownは `README.md` の1つだけになります。

---

## Step 1: 消す（13ファイル）

消すのは**中身が別の場所にあるものだけ**です。実際の文章は1つも失われません。

### 1-A. 移動案内だけの空ファイル（10個・各5行）

中身は「◯◯へ移動しました」の1行だけです。行き先は Step 5 で `archive/README.md` に対応表として1枚にまとめます。

```bash
cd /Users/art0/development/usalingo_app
git rm "docs/Usalingo｜Specification Ver.2.0/wireframe_components.md" \
       "docs/Usalingo｜Specification Ver.2.0/類義語の動的DB索引方法.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_01_business/usalingo_01_business_requirements.md.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_01｜開発環境 & 技術スタック.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_02｜ディレクトリツリー.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_03｜データベース設計.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_04｜アルゴリズム設計.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_05｜ワークフロー設計.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_04_technical_requirements/usalingo_04_06｜アセット管理設計.md" \
       "docs/Usalingo｜Specification Ver.2.0/usalingo_05_aigc_policy.md/usalingo_05_aigc_policy.md"
```

最後の1つを消すと、`.md` で終わるディレクトリという事故も一緒に片づきます。

### 1-B. 入口が重複しているREADME（3個）

内容は Step 5 で `docs/README.md` と `docs/archive/README.md` に吸収します。

```bash
git rm "docs/Usalingo｜Specification Ver.2.0/README.md" \
       docs/supabase/README.md \
       docs/rules/README.md
```

### 消す前の確認

```bash
git log --oneline -1 -- docs/archive/legacy-spec-v2/
```

`archive/legacy-spec-v2/` に実体があることを目で見てから消します。

---

## Step 2: 新しい棚を作る

```bash
mkdir -p docs/product docs/content docs/operations/runbooks docs/legal/source docs/archive/legacy-spec-v2-business
```

---

## Step 3: 動かす（`git mv` を使う）

`git mv` を使うと、その文書がいつ誰に書かれたかの記録が切れずに残ります。消して作り直してはいけません。

### 3-A. 製品（何を作るか）

```bash
git mv docs/usalingo-simple-product-plan.md docs/product/plan.md
git mv docs/decisions/usalingo-core-workflow-requirements.md docs/product/workflow.md
```

### 3-B. 教材データ

```bash
git mv "docs/supabase/Usalingo 英単語原本データベース V5 設計書.md" docs/content/source-database-v5.md
```

### 3-C. 開発の運用

```bash
git mv docs/development/repository-layout.md   docs/operations/repository-layout.md
git mv docs/development/technology-stack.md    docs/operations/technology-stack.md
git mv docs/supabase/local-development.md      docs/operations/supabase-local-development.md
git mv docs/rules/SQL_Query_Rules.md           docs/operations/sql-rules.md
git mv docs/rules/codex-credit-optimization.md docs/operations/credit-optimization.md
git mv docs/release-quality-gate.md            docs/operations/release-quality-gate.md
git mv docs/runbooks/account-deletion-edge-function.md docs/operations/runbooks/account-deletion-edge-function.md
```

### 3-D. 法務

PDFの名前はそのままにします。全角の `｜` と空白が入っているのはフォルダ名だけだからです。

```bash
git mv docs/research/usl-249-legal-privacy-license-inventory.md docs/legal/asset-and-privacy-inventory.md
git mv "docs/Fo｜02｜Terms of Use/Usalingo_利用規約.pdf"           docs/legal/source/
git mv "docs/Fo｜02｜Terms of Use/Usalingo_プライバシーポリシー.pdf" docs/legal/source/
git mv "docs/Fo｜02｜Terms of Use/Usalingo_AIGCガイドライン.pdf"    docs/legal/source/
git mv "docs/Fo｜02｜Terms of Use/Usalingo_特定商取引法.pdf"        docs/legal/source/
git mv "docs/Fo｜02｜Terms of Use/Usalingo_著作権について.pdf"      docs/legal/source/
```

### 3-E. 履歴へ移す（終わった作業）

```bash
git mv docs/workflow-records docs/archive/workflow-records
git mv docs/usalingo-workflow-planning-execution-plan.md docs/archive/workflow-records/00-execution-plan.md
```

### 3-F. 履歴へ移す（旧Ver.2.0の本体10ファイル）

長い日本語のファイル名を、番号つきの短い半角名に変えます。読む順番がそのまま名前になります。

```bash
V="docs/Usalingo｜Specification Ver.2.0"
D="docs/archive/legacy-spec-v2-business"
git mv "$V/usalingo_01_business/usalingo_00_definitions.md"            "$D/01-definitions.md"
git mv "$V/usalingo_01_business/usalingo_01_business_requirements.md"  "$D/02-business-requirements.md"
git mv "$V/usalingo_02_content_requirements/usalingo_02_01｜コンテンツ基本方針.md"        "$D/03-content-policy.md"
git mv "$V/usalingo_02_content_requirements/usalingo_02_02｜コアコンテンツ定義.md"        "$D/04-core-content.md"
git mv "$V/usalingo_02_content_requirements/usalingo_02_03｜コンテンツパッケージ定義.md"  "$D/05-content-packages.md"
git mv "$V/usalingo_02_content_requirements/usalingo_02_04｜コンテンツ運用フロー.md"      "$D/06-content-operations.md"
git mv "$V/usalingo_03_design_requirements/usalingo_03_01｜UIUX 基本原則.md"              "$D/07-uiux-principles.md"
git mv "$V/usalingo_03_design_requirements/usalingo_03_02｜サイトマップ &ユーザーフロー.md" "$D/08-sitemap-user-flow.md"
git mv "$V/usalingo_03_design_requirements/usalingo_03_03｜レイアウト & ブロック定義.md"    "$D/09-layout-blocks.md"
git mv "$V/usalingo_03_design_requirements/usalingo_03_04｜コンポーネント & インタラクション設計.md" "$D/10-components-interaction.md"
```

### Step 3 のあとの確認

```bash
find docs -type d -empty -delete
git -c core.quotepath=false ls-files docs | grep -E '｜| ' | cat
```

2つ目のコマンドが**何も出さない**ことを確認します。出たら、全角記号か空白がまだ残っています。

---

## Step 4: リンクを直す（18ファイル）

移動したパスを指している文書が18あります。**4つは `docs/` の外**なので、忘れやすい場所です。

### `docs/` の外（4ファイル）

| ファイル | 直す内容 |
|---|---|
| `AGENTS.md` | `docs/rules/codex-credit-optimization.md` → `docs/operations/credit-optimization.md` |
| `README.md`（リポジトリ直下） | `docs/` への案内 |
| `apps/ios-swiftui/README.md` | `docs/development/` への案内 |
| `.agents/skills/usalingo-git-cleanup/SKILL.md` | 同上 |
| `.agents/skills/usalingo-next-ticket/SKILL.md` | 同上 |
| `.agents/skills/usalingo-project-manager/references/notion-setup.md` | 同上 |

### `docs/` の中

`archive/README.md`、`decisions/` の各文書、`plans/` の2つの計画書、`operations/sql-rules.md` などが対象です。

### 総点検

```bash
grep -rn '](\.\./\|](\./\|](docs/' --include='*.md' . | grep -v '^./.git'
```

出てきたリンクの行き先が全部あるかを、次で機械的に確かめます。

```bash
python3 - <<'PY'
import re, pathlib
for p in pathlib.Path('.').rglob('*.md'):
    if '.git' in p.parts: continue
    for m in re.finditer(r'\]\(([^)\s#]+\.(?:md|pdf))(?:#[^)]*)?\)', p.read_text(encoding='utf-8')):
        t = m.group(1)
        if t.startswith(('http', 'mailto')): continue
        if not (p.parent / t).exists():
            print('切れています:', p, '->', t)
PY
```

**何も出なくなるまで直します。** これが Step 4 の完了条件です。

---

## Step 5: 入口を作り直す

### 5-A. `docs/README.md` を20行以内に

9つの棚を1行ずつ案内するだけにします。個々の文書の一覧は各棚のREADMEか、棚の中身そのものに任せます。

```text
docs/
├── README.md      これ
├── product/       何を作るか
├── architecture/  いまの仕組みの正本
├── content/       教材データの作り方
├── decisions/     決めたことの記録
├── plans/         これからやること
├── operations/    開発環境・ルール・手順書
├── legal/         公開する文書と素材の台帳
└── archive/       昔の資料（いまの判断には使わない）
```

### 5-B. `docs/archive/README.md` に旧パス対応表を足す

Step 1 で消した10個の移動案内の代わりです。「昔のこのパス → いまのこのファイル」の表を1つ作ります。Notionや過去のリンクから来た人は、ここだけ見れば分かります。

### 5-C. `docs/operations/repository-layout.md` を更新

`docs/` のツリーを新しい形に直し、「新しい文書をどこに置くか」の節を足します。中身は [`docs-restructure-plan.md`](docs-restructure-plan.md) の原則3つをそのまま書きます。

### 5-D. `AGENTS.md` の「毎回読む文書」を2つに固定

- `docs/README.md`
- `docs/operations/credit-optimization.md`

---

## 完了のしるし

上から順に確認します。

1. `docs/` 直下のMarkdownが `README.md` だけ。
2. パスに `｜` と空白を含むファイルが0。
3. リンク切れ検査のスクリプトが何も出さない。
4. `archive/` を除いた行数が2,000行以内。
5. `git log --follow docs/product/plan.md` で、移動前の履歴がたどれる。
6. `docs/operations/repository-layout.md` のツリーが実物と一致する。

```bash
git -c core.quotepath=false ls-files docs | grep '\.md$' | grep -v '^docs/archive/' | tr '\n' '\0' | xargs -0 wc -l | tail -1
```

---

## やめ方

まだコミットしていないなら、こう戻します。

```bash
git reset --hard HEAD
```

コミット済みなら、そのコミットを打ち消します。

```bash
git revert <コミットのID>
```

**この作業は必ず新しいブランチで行い、`main` へは直接コミットしません。**

---

## 進め方

- 1つのプルリクエストでまとめて行います。分けると、リンクが切れている期間が長くなります。
- Step 1 から Step 5 まで通しで行い、途中でコードには触りません。
- [`external-package-adoption-plan.md`](external-package-adoption-plan.md) の作業は、この整理が終わってから始めます。

## この作業でやらないこと

- 文章の書き直し、要約、圧縮。
- 履歴文書の削除（`archive/` へ移すだけ）。
- Notion側の構造の変更。
