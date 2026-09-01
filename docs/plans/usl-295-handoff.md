# USL-295 引き継ぎ｜法務3ページを静的サイトとして作りVercelで公開する

作成日: 2026-09-01

対象: Notion [USL-295](https://app.notion.com/3cec3d1f59e881f79968ffa0459b7350)
「実装｜法務3ページを静的サイトとして作りVercelで公開する」

## 何が変わったか

2026-09-01 に方針を変えた。

| | 前 | 後 |
|---|---|---|
| 作る場所 | Bubble（`imagicraft-power.bubbleapps.io`） | **このリポジトリ内の静的サイト** |
| 公開先 | Bubble のページ | **Vercel の無料枠** |
| ドメイン | 既存の Bubble アプリのサブパス | **取り直す**（まず `*.vercel.app`） |
| 作る人 | 人間が画面で作る | **AIが生成し、人間が deploy する** |

理由は単純で、3ページとも**文章を出すだけ**であり、Bubble の機能を必要としないため。
リポジトリの Markdown を正本にしたまま生成でき、文書を直せば公開ページも直る状態にできる。

## いまの状態

| 項目 | 値 |
|---|---|
| 文面 | **確定済み**。`docs/legal/published/` の3つの Markdown が正本 |
| サイト | **未作成** |
| 公開URL | **未定**。Vercel で deploy したときに決まる |
| アプリ側の定数 | `LegalDocument.publishedBaseURL` が Bubble の旧URLのまま。**要変更** |

## 変えてはいけない条件

1. **パスは `/terms`、`/privacy`、`/credits` の3つ。**
   アプリは `<base>/terms` の形で開く。変えるならアプリ側の定数も同じコミットで直す。
2. **正本を二重管理しない。**
   文面は `docs/legal/published/*.md` の1か所だけ。HTML は生成物とし、手書きの文章を持たせない。
   2か所に文章があると、片方だけ直したときに「アプリに出ている規約」と「実際の規約」が食い違う。
3. **鍵をリポジトリへ書かない。** Vercel のトークンやプロジェクトIDをコミットしない。
4. **費用の発生する契約はAIが行わない。** 独自ドメインを買う場合は人間が行う。

## 作るもの

```text
apps/legal-web/
├── package.json          … 変換に使う依存（marked など）
├── build.mjs             … docs/legal/published/*.md → public/*.html
├── style.css             … 生成HTMLが読む1枚のCSS
├── vercel.json           … cleanUrls を有効にする
└── public/               … 生成物（index.html, terms.html, privacy.html, credits.html）
```

`vercel.json` で `cleanUrls: true` にすると、`public/terms.html` が `/terms` で開く。

`.gitignore` に `node_modules/` と `.vercel/` を足す。いまどちらも入っていない。

### HTML に求めること

- スマートフォンの幅で横スクロールが出ない
- 文字サイズは相対単位。利用者が文字を大きくしても崩れない
- ダークモードで読める（`prefers-color-scheme`）
- 各ページの先頭に「第1.0版 ／ 施行日: 2026年9月1日」が出る
- 3ページを行き来できるリンクが1か所にある

飾りは要らない。読めることだけが要件。

## 進める順番

```text
1. apps/legal-web/ を作る（AI）
2. ローカルで build して3つのHTMLが出ることを確認（AI）
3. PRを出してマージ（AI）
   ────────────────
4. Vercel アカウントを作り、リポジトリを接続して deploy（人間）
   ルートディレクトリは apps/legal-web/
5. 発行されたURLを確定（人間）※ 例: https://usalingo-legal.vercel.app
   ────────────────
6. LegalDocument.publishedBaseURL をそのURLへ直す（AI）
7. docs/legal/published/README.md の公開先の表を書き換える（AI）
8. 実機で4行すべてをタップして確認（人間）
9. USL-295 と USL-255 を done にする（AI）
```

**3と4の間で人間の作業が入る。** ここで一度止まる前提で進める。

## この先にあるもの

- USL-255（実装｜法務・ライセンス・クレジットをアプリ内で確認できるようにする）— これが解除条件のひとつ
- USL-287（実行｜最初のビルドをTestFlightへ提出して内部テスターへ配る）— M1 の出口

USL-287 では App Store Connect にプライバシーポリシーの**URL**を登録する。
そのURLがこのサイトの `/privacy` になる。

## 次のチャットへ渡すプロンプト

以下をそのまま新しいセッションへ貼る。

---

USL-295「実装｜法務3ページを静的サイトとして作りVercelで公開する」を進めたい。
背景と条件は `docs/plans/usl-295-handoff.md` にある。まずこれを読むこと。

要点。

- 利用規約・プライバシーポリシー・クレジットの3ページを、Vercel の無料枠で公開したい。
  Bubble は使わない。ドメインも取り直す。
- 文面は確定済みで、`docs/legal/published/` の3つの Markdown が正本。**文章は書かない。変換するだけ。**
- アプリは `<公開URL>/terms`、`/privacy`、`/credits` を決め打ちで開く。このパスは動かせない。
- 正本を二重管理しない。HTML は生成物にする。手書きのHTMLに文章を持たせると、
  アプリに出ている規約と実際の規約が食い違う。

やってほしいこと。

1. `apps/legal-web/` を作る。`docs/legal/published/*.md` を読んで
   `public/terms.html`、`public/privacy.html`、`public/credits.html` と索引の `index.html` を
   生成するスクリプト、1枚のCSS、`vercel.json`（`cleanUrls: true`）を置く。
   スタイルは飾らない。スマートフォンで横スクロールが出ないこと、文字サイズが相対単位であること、
   ダークモードで読めることだけ満たす。
2. `.gitignore` に `node_modules/` と `.vercel/` を足す。
3. ローカルで build を実行し、3つのHTMLが生成され、版と施行日が入っていることを確認する。
   生成物をコミットするかどうかは、Vercel 側でビルドを走らせる構成にするなら不要。どちらにするか決めて理由を書く。
4. PR を出す。
5. **ここで一度止まる。** Vercel での deploy は人間の作業。アカウント作成から deploy までの手順を、
   小学生でもわかる比喩で端的に説明する。
6. 公開URLが決まったら、`ProfileDashboardView.swift` の `LegalDocument.publishedBaseURL` と
   `docs/legal/published/README.md` の公開先の表を直す。

守ること。

- `.agents/skills/usalingo-next-ticket` の作業権の手順に従い、着手前に lease を取り、
  書き込み前にもう一度 `worker_id` が自分のままであることを確認する。
- Vercel のトークンやプロジェクトIDをリポジトリへ書かない。
- 費用の発生する契約はAIが行わない。独自ドメインを買う話が出たら人間へ渡す。
- 法務文書の文面は変えない。変換するだけ。
- 説明は小学生でもわかるように比喩的に、端的でシンプルに。

---

## 参照

- [usl-255-handoff.md](usl-255-handoff.md) — USL-255 の状態と、確定した事業者情報
- [milestones.md](milestones.md) — M1 / M2 の全体像
- [../legal/published/README.md](../legal/published/README.md) — 正本と公開先の対応表
