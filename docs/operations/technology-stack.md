# 現行SwiftUI 開発環境・技術スタック

最終更新日: 2026-08-27
対象: 現行iOSアプリ `apps/ios-swiftui/`

この文書は、現在のSwiftUI版Usalingoで実際に使っている技術を示します。Flutter、Dart、Riverpod、`go_router`、`drift`、`supabase_flutter` は旧実装の技術であり、現行アプリでは使用しません。

## 対象プラットフォーム

| 項目 | 現在値 |
|---|---|
| 対象 | iPhone向けネイティブiOSアプリ |
| 最低OS | iOS 17.0 |
| 言語 | Swift 5 |
| UI | SwiftUI |
| プロジェクト | `apps/ios-swiftui/UsalingoIOS.xcodeproj` |
| アプリ識別子 | `com.usalingo.ios` |

iPad、Apple Watch、ウィジェット、Android、Webは現在の学習コア完成範囲に含めません。

## 開発・検証環境

| 領域 | 採用技術・道具 | 役割 |
|---|---|---|
| IDE・ビルド | Xcode / `xcodebuild` | SwiftUIアプリの編集、ビルド、Simulatorテスト |
| バージョン管理 | Git / GitHub | 変更履歴とブランチ管理 |
| 自動テスト | XCTest | 復習計算、Card ID、画像・音声パス、学習フローの確認 |
| UI状態 | SwiftUI `ObservableObject` / `@Published` | セッション、デザイン設定、画面状態の共有 |
| 設定保存 | Keychain / UserDefaults | 認証セッションと端末内の軽量設定を保存 |

CI/CDは将来の公開準備で整備します。現在確認できる正本は、ローカルのXcodeプロジェクトとXCTestです。

## バックエンド

| 領域 | 採用技術 | 役割 |
|---|---|---|
| BaaS | Supabase | 認証、PostgreSQL、Storage、Data API |
| 通信 | Foundation `URLSession` | Auth APIとREST Data APIへの通信 |
| 認証 | Supabase Auth | メール・パスワード認証 |
| データベース | Supabase Database (PostgreSQL) | 公式コンテンツ、Card、利用者ごとの学習進捗 |
| 権限 | PostgreSQL GRANT / RLS | 公式データの読み取り専用化と本人進捗の分離 |
| メディア | Supabase Storage | 運営が用意したWebP画像とMP3音声の配信 |

実行可能なDB変更は `supabase/migrations/` を正本とします。本番適用前には、対象プロジェクト、既存データ、RLS、GRANT、Storage policyを再監査します。

## iOS側の主要技術

| 領域 | 採用技術 | 現在の責任 |
|---|---|---|
| 画面 | SwiftUI | 認証、学習、デッキ、単語、プロフィール、デザイン画面 |
| 画面遷移 | `NavigationStack` / SwiftUI状態 | 画面間の遷移と学習セッション表示 |
| 通信モデル | `Codable` | SupabaseのJSONとSwiftモデルの変換 |
| 音声 | AVFoundation `AVPlayer` | 運営が用意した音声URLの再生 |
| 画像 | `AsyncImage` | 公開Storage画像の表示と欠損時の代替表示 |
| 復習計算 | Swiftモデル | 2択SM-2ハイブリッドによる次回復習日の計算 |

端末TTSは使いません。

## 外部パッケージの方針

**2026-08-27に方針を変更しました。** それまでの「外部パッケージへ依存せず、Apple標準フレームワークだけで構成する」という宣言は撤回します。

汎用的で枯れた処理まで自作すると、開発時間と生成AIの利用コストが増え、不具合の原因も増えます。今後は、次の基準を満たすものに限り外部パッケージを採用します。

| 基準 | 内容 |
|---|---|
| 対象 | 汎用処理であり、自作すると規模が大きくなるもの。学習アルゴリズムや画面体験など、Usalingoの差別化にあたる部分は自作を続ける |
| 導入方法 | Swift Package Manager のみ。CocoaPods と Carthage は使わない |
| 保守状態 | 直近1年以内に更新があり、iOS 17に対応していること |
| ライセンス | MIT、Apache-2.0など、表示だけで条件を満たせるもの。GPL系は採用しない |
| 取り外しやすさ | 呼び出し側から直接使わず、`Services/` に薄いラッパを1枚置いて包む |
| 記録 | `Package.resolved` をGitへ登録し、追加のたびにアプリ内ライセンス表示を更新する |

採用したパッケージと採用理由は、この文書の「iOS側の主要技術」表へ追記します。

### 薄いラッパの置き方

外部パッケージの型を `View` から直接使わないこと、これが唯一の約束です。差し替えや撤去のとき、直す場所がラッパ1枚で済みます。

| 決めごと | 内容 |
|---|---|
| 置き場所 | `apps/ios-swiftui/UsalingoIOS/Services/` 直下。関連ファイルが増えるならその下にフォルダを作る |
| 公開する型 | Usalingo側で決めた名前と型だけを出す。パッケージの型を戻り値や引数に出さない |
| 設定 | 上限、有効期限、再試行などの設定はラッパの中の1か所へ集める。呼び出し側へ散らさない |
| import | パッケージの `import` はラッパのファイルだけに書く |

判断に迷ったら「このパッケージをやめるとき、消すファイルはどれか」を数えます。1枚で済まないなら、まだ包み方が足りません。

### ライセンス表示の集め方

依存のライセンス一覧は手で書かず、[LicensePlist](https://github.com/mono0926/LicensePlist)（MIT）で生成します。手書きの一覧は依存を足すたびに古くなり、表示義務を満たせなくなるためです。

- 設定は `apps/ios-swiftui/license_plist.yml`
- 生成は `sh scripts/generate-licenses.sh`
- 出力は `apps/ios-swiftui/UsalingoIOS/Resources/Licenses/Acknowledgements.md`。生成物ですがGitへ登録します
- 生成物が古くないかは `sh scripts/generate-licenses.sh --check` で確かめます

LicensePlist は開発機で動かすコマンドであり、アプリへ同梱する依存ではありません。Swift Package以外の素材（フォント、イラスト、音声）は `license_plist.yml` の `manual` へ足します。素材の出典台帳は [`docs/legal/asset-and-privacy-inventory.md`](../legal/asset-and-privacy-inventory.md) が正本です。

## 現在含めないもの

- 通知
- 課金
- 複数の復習アルゴリズム
- Android・Web向けクロスプラットフォーム実装
- App Store公開設定

オフライン用ローカルキャッシュ、画像キャッシュ、学習記録の可視化、法務・ライセンス表示は、[`docs/plans/external-package-adoption-plan.md`](../plans/external-package-adoption-plan.md) で扱います。

学習コアの完成条件と範囲は `docs/architecture/anki-aligned-spec.md` を正本とします。
