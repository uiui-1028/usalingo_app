# Usalingo 法務文書

更新日: 2026-08-16  
状態: 公開前ドラフト。法務確認と公開前チェックが完了するまで外部公開しない。

## このフォルダの使い方

- PDF 5点は2025年作成の原本として保持する。内容を直接更新せず、経緯確認に使う。
- 今後の編集はMarkdownを正本候補として行う。
- 公開可否は [`公開前チェックリスト.md`](公開前チェックリスト.md) で管理する。
- 実装や販売条件が変わったときは、公開文書とApp Store Connectの表示を同時に見直す。

## 文書一覧

| 文書 | 用途 | 現在の扱い |
| --- | --- | --- |
| [`利用規約_公開前ドラフト.md`](利用規約_公開前ドラフト.md) | サービス利用の基本契約 | 現行iOS版に合わせて整理。要確認箇所あり |
| [`プライバシーポリシー_公開前ドラフト.md`](プライバシーポリシー_公開前ドラフト.md) | 取得情報と取扱い | 現行コードに合わせて整理。委託先・保存期間は要確認 |
| [`著作権表示_公開前ドラフト.md`](著作権表示_公開前ドラフト.md) | 権利帰属の平易な案内 | 利用規約の補足文書 |
| [`AI生成コンテンツガイドライン_機能導入前ドラフト.md`](AI生成コンテンツガイドライン_機能導入前ドラフト.md) | 将来のAI生成・共有機能 | 現行アプリでは未確認。機能導入まで非公開 |
| [`特定商取引法に基づく表記_有料機能導入前テンプレート.md`](特定商取引法に基づく表記_有料機能導入前テンプレート.md) | 有料機能の販売表示 | StoreKit実装・販売条件確定まで非公開 |

## 現行実装との照合結果

2026-08-16時点の `apps/ios-swiftui/` と `supabase/migrations/` を確認した。

確認できたもの:

- iOS 17以降を対象とするSwiftUIアプリ
- メールアドレスとパスワードによるSupabase Auth認証
- ニックネーム、学習履歴、復習予定、正誤・反復回数の保存
- ユーザー固有の単語編集内容とタグの保存
- 認証セッションのKeychain保存、表示設定のUserDefaults保存
- 運営が用意した単語、例文、画像、音声の配信

確認できなかったもの:

- StoreKitによる有料プラン・自動更新購読
- Android版
- AI生成機能
- ユーザー間のコンテンツ共有・一般公開
- 広告SDK・専用の分析SDK・Cookie
- アプリ内のアカウント削除機能

未確認機能を旧PDFの文面どおり公開すると、実態と表示が食い違う。機能追加時に関連文書を有効化する。

## 旧PDFからの主な改善点

- Notion由来の `status`、`workspace`、警告記号、草案メタデータを公開本文から分離した。
- 未実装のProプラン、Android、AI生成、共有機能を現行規約から切り離した。
- 一律の「一切責任を負わない」という表現を避け、消費者契約法が適用される場合を考慮した。
- 規約変更を「掲載しただけで即時発効・継続利用で同意」とせず、変更内容と効力発生日の周知を前提にした。
- プライバシーポリシーに保存期間、削除方法、委託先、国外取扱いの確認欄を設けた。
- 特定商取引法表示から、未確定価格・Android・連絡不能と読める電話案内を公開値として外した。

## 参照した公式情報

- [e-Gov法令検索: 民法（定型約款の変更は第548条の4）](https://laws.e-gov.go.jp/law/129AC0000000089)
- [消費者庁: 消費者契約法の逐条解説](https://www.caa.go.jp/policies/policy/consumer_system/consumer_contract_act/annotations)
- [消費者庁: 通信販売広告の表示事項](https://www.no-trouble.caa.go.jp/what/mailorder/advertising.html)
- [個人情報保護委員会: 外国にある第三者への提供編](https://www.ppc.go.jp/personalinfo/legal/guidelines_offshore/)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple: Auto-renewable Subscriptions](https://developer.apple.com/app-store/subscriptions/)

## 注意

これらは開発・運用上の整理案であり、弁護士による法的助言ではない。公開前に、実際のデータフロー、法人登記、販売条件、対象年齢、提供地域を確定し、日本法に詳しい専門家の確認を受ける。
