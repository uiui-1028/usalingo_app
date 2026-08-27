# 公開する法務文書

ここが公開文書の**正本**です。`docs/legal/source/` のPDFは2025-08-15の旧草案で、現行アプリに無い機能を前提にしています。今後はこちらのMarkdownを直し、公開先へ反映します。

> [!WARNING]
> **ここにある会社情報・日付・URLはサンプルデータです。** 実際の値ではありません。公開前に責任者が確定し、[`../asset-and-privacy-inventory.md`](../asset-and-privacy-inventory.md) の「公開前の確認リスト」7項目をそろえてください。法的な適否は専門家が判断します。

## 公開先

Bubble の公開ページを使います。

| 文書 | ページのURL | アプリ内の表示行 |
|---|---|---|
| [利用規約](terms-of-service.md) | `https://imagicraft-power.bubbleapps.io/version-test/terms` | 利用規約 |
| [プライバシーポリシー](privacy-policy.md) | `https://imagicraft-power.bubbleapps.io/version-test/privacy` | プライバシー |
| [クレジット](credits.md) | `https://imagicraft-power.bubbleapps.io/version-test/credits` | クレジット |

**Bubble側でこの3つのページを作る必要があります。** ページ名（slug）を `terms`、`privacy`、`credits` にしてください。アプリはこのURLをそのまま開きます。

「ライセンス」だけは外部URLではなく、アプリ内の画面です。依存パッケージの一覧を生成物として同梱しているためで、公開ページには置きません。

App Store Connect はプライバシーポリシーの**URL**を求めるため、アプリ内表示だけでは足りません。上の `privacy` のURLを登録します。

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
2. 版と施行日を上げる
3. Bubble の該当ページへ反映する
4. `apps/ios-swiftui/UsalingoIOS/Features/Profile/ProfileDashboardView.swift` の `LegalDocument.publishedDocuments` の版・施行日を合わせる

4を忘れると、アプリが古い版を表示します。
