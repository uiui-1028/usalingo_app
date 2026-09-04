# 公開する法務文書

ここが公開文書の**正本**です。`docs/legal/source/` のPDFは2025-08-15の旧草案で、現行アプリに無い機能を前提にしています。今後はこちらのMarkdownを直し、公開先へ反映します。

> [!IMPORTANT]
> **事業者情報は 2026-09-01 に確定しました。** 事業者は個人の「河合 泰芽」、所在地は〒446-0042 愛知県安城市大山町2-15-18、窓口は `support@usalingo.jp` です。
> **版は文書ごとに持ちます。** 利用規約とプライバシーは第1.0版（2026年9月1日）、クレジットは第1.1版（2026年9月4日）です。1文書だけ改訂したときに他の版まで動かさないため、まとめて1つにしません。
> **未了は次の2つです。** ①プライバシーポリシー第7条の対象年齢と第9条の保存期間が確定待ち、②法的な適否について専門家の確認は未実施。[`../asset-and-privacy-inventory.md`](../asset-and-privacy-inventory.md) の「公開前の確認リスト」7項目もあわせて確認してください。

## 公開先

**2026-09-01 に方針を変えました。Bubble は使いません。** このリポジトリ内（`apps/legal-web/`）に静的サイトを作り、Vercel の無料枠（`https://usalingo-app.vercel.app`）で公開しています。3ページとも文章を出すだけで、Bubble の機能を必要としないためです。作業は Notion [USL-295](https://app.notion.com/3cec3d1f59e881f79968ffa0459b7350)、手順は [`../../plans/usl-295-handoff.md`](../../plans/usl-295-handoff.md) にあります。

| 文書 | 公開先 | アプリ内の表示行 |
|---|---|---|
| [利用規約](terms-of-service.md) | <https://usalingo-app.vercel.app/terms> | 利用規約 |
| [プライバシーポリシー](privacy-policy.md) | <https://usalingo-app.vercel.app/privacy> | プライバシー |
| [クレジット](credits.md) | <https://usalingo-app.vercel.app/credits> | クレジット |

サイトは 2026-09-01 に公開済みです。アプリの `LegalDocument.publishedBaseURL` も同じURLに更新済みで、タップすると各ページが開きます。

パスの `terms`、`privacy`、`credits` は変えられません。アプリがこの形で決め打ちで開きます。

「ライセンス」だけは外部URLではなく、アプリ内の画面です。依存パッケージの一覧を生成物として同梱しているためで、公開ページには置きません。

App Store Connect はプライバシーポリシーの**URL**を求めるため、アプリ内表示だけでは足りません。公開後の `privacy` のURLを登録します。

## いま公開しない文書

| 文書 | 理由 |
|---|---|
| [特定商取引法に基づく表示](../source/Usalingo_特定商取引法.pdf) | 有料プランが未実装。特商法の表示義務は有償取引が前提のため、課金を入れるときに作る |
| [AI生成コンテンツガイドライン](../source/Usalingo_AIGCガイドライン.pdf) | AI生成・共有機能が未実装。機能を追加するときに作る |

無い機能の規約を先に出すと、実装と文書が食い違ったまま公開することになります。

## 旧草案から削ったもの

現行コード（`apps/ios-swiftui/`）に存在しないため、次を削除しました。根拠は [`../asset-and-privacy-inventory.md`](../asset-and-privacy-inventory.md) の第6節です。

| 削ったもの | 理由 |
|---|---|
| Proプラン、自動更新課金、返金、遅延損害金 | 課金SDKも購入画面も無い |
| データ共有サービス、ユーザー生成コンテンツの共有 | 共有・投稿機能が無い |
| プロフィール画像、自己紹介文 | プロフィールはニックネームのみ |
| 端末識別ID、IPアドレス、操作履歴、Cookie | 収集SDKが無い |
| 13歳基準と保護者同意 | 年齢確認も同意UIも無い |

逆に、旧草案に無く現行にあるものとして、**アプリ内からのアカウント削除**を書き足しました（USL-259で実装済み）。

## 直したら何をするか

1. このMarkdownを直す
2. **その文書の**版と施行日を上げる（利用規約・プライバシー: 第1.0版／2026年9月1日、クレジット: 第1.1版／2026年9月4日）
3. Bubble の該当ページへ反映する
4. `apps/ios-swiftui/UsalingoIOS/Features/Profile/ProfileDashboardView.swift` の `LegalDocument.publishedDocuments` の版・施行日を合わせる

4を忘れると、アプリが古い版を表示します。
