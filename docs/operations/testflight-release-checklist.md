# TestFlight配信の準備一覧（USL-277）

作成日: 2026-08-31

対象: 自分のiPhoneだけで試す内部TestFlight配信（M1）。App Store の一般公開は含めない。

配信でいちばん詰まりやすいのはコードではなく Apple 側の手続きです。この文書は
「何が要るのか」を先に一覧にして、あとから驚かないためのものです。

状態は次の4つに分けています。

- **済み** — リポジトリで確認できた
- **未（AI）** — このリポジトリの変更で終わる。AIが対応できる
- **未（人間）** — Apple のアカウント操作、契約、素材の用意が要る
- **未確認** — AIからは見えない。人間が App Store Connect などで確認する

## 1. Apple Developer Program

| 項目 | 状態 | 誰が何をすれば済むか |
|---|---|---|
| プログラム加入 | 済み（2026-08-31） | 個人として加入済み |
| 個人か組織かの選択 | 済み | **個人**で加入。App Store の売り主名は個人名になる |
| チームID | 済み | `CTSYH44JRG`。`DEVELOPMENT_TEAM` へ入れるのは USL-282 |

> [!NOTE]
> 加入は2026-08-31に完了しました。ここが最大の待ち時間でした。
> 更新は年1回です。費用が発生するため、AIは契約と支払いを行いません。

## 2. アプリの識別

| 項目 | 状態 | 現在の値 / やること |
|---|---|---|
| Bundle ID（コード側） | 済み | `com.usalingo.ios`（`UsalingoIOS.xcodeproj/project.pbxproj`） |
| Bundle ID（Apple側の登録） | 済み（USL-287） | アプリレコードを作れたので、Apple 側にも登録されている |
| バージョン / ビルド番号 | 済み | 配るたびに上げる。2026-09-17 時点で `MARKETING_VERSION = 2.0.0`、`CURRENT_PROJECT_VERSION = 2` |
| 表示名 | 済み | `Usalingo`（`Info.plist` の `CFBundleDisplayName`） |
| アプリのカテゴリ | 済み | `public.app-category.education` |
| アプリアイコン | 済み（USL-281） | `Resources/Assets.xcassets/AppIcon.appiconset` に 1024×1024 の PNG（透過なし）を追加済み。素材は `assets/usalingo_iconcomposer/Icons｜SimpleFlatt/` の Default。あとから差し替えられる |
| `AccentColor` | 未（保留） | ビルド設定が参照しているが実体が無い。アプリは全画面で `.tint(WireColor.ink)` を明示しているため実害はない。デザインシステムの色を増やす判断が要るので保留 |
| 最低対応OS | 済み | iOS 17.0 |

## 3. 署名とアーカイブ

| 項目 | 状態 | やること |
|---|---|---|
| 署名方式 | 済み | `CODE_SIGN_STYLE = Automatic`（自動管理） |
| アーカイブ手順書 | 済み（USL-282） | [Releaseアーカイブ手順](release-archive.md) |
| `DEVELOPMENT_TEAM` | 済み（USL-282） | `CTSYH44JRG` を Debug・Release 両方へ設定済み |
| 配布証明書・プロビジョニングプロファイル | 済み（2026-09-01） | 自動管理で Xcode が作成。`Taiga Kawai` チームでのアーカイブに成功済み |
| Releaseアーカイブ | 済み（2026-09-01） | `0.1.0 (1)` / `com.usalingo.ios` / arm64 で成功。詰まったときの対処は [Releaseアーカイブ手順](release-archive.md) の3章 |
| CI での署名 | 済み（意図的） | `ios-ci.yml` は `CODE_SIGNING_ALLOWED=NO` で走る。CI は署名を検証しない。署名の確認は開発機で行う |

## 4. ビルド環境

| 項目 | 状態 | やること |
|---|---|---|
| iOS 26 SDK / Xcode 26 | 済み（2026-09-04） | 2026年4月28日以降、App Store Connect へアップロードするアプリは iOS 26 SDK 以降でビルドしたものに限られる。開発機でのアーカイブとアップロードが通ったため確認済み。提出のたびに再確認する |
| CI のランナー | 済み | テストの `ios-ci.yml` は `macos-15`。配布用の `ios-release.yml` は Xcode 26 が載る `macos-26`（USL-291） |

## 5. App Store Connect

| 項目 | 状態 | やること |
|---|---|---|
| アプリレコード | 済み（USL-287） | 人間が作った。**TestFlight を使う前に必須**。アプリ名、主言語、Bundle ID、SKU が要る。アプリ名は App Store 全体で一意 |
| 自分の内部テスト利用 | 済み（2026-09-04、USL-287） | 内部グループ「自分用」に自分のApple Accountだけを入れ、本人のiPhoneでTestFlightから起動できた。追加のテスター招待は行っていない |
| Beta App Review | 不要 | **自分だけの内部テストは審査なしで配れる。**外部テストはこのチケットの対象外 |
| ビルドの有効期限 | 情報 | アップロードしたビルドは **90日** でテストできなくなる |
| テスト情報 | 済み（USL-287） | ベータ版の説明、試してほしいこと、フィードバック用のメールアドレス。内部テストでも入力欄がある |

## 6. 提出時に必ず聞かれること

| 項目 | 状態 | やること |
|---|---|---|
| 輸出コンプライアンス | 済み | 独自の暗号は使っていない（`CryptoKit`、`CommonCrypto`、`SecKey` の利用なし）。通信は HTTPS のみ。`Info.plist` に `ITSAppUsesNonExemptEncryption = false` を入れてあるので、アップロードのたびには聞かれない |
| プライバシーマニフェスト | 済み | `Resources/PrivacyInfo.xcprivacy` がある。`UserDefaults` を使っている（`Models/DesignSettings.swift`、`App/AppState.swift`）ため、理由の申告が要る API に該当する。**第三者SDKは使っていない**（Supabase へは自前の `URLSession` で接続している）ので、自分のコードの分だけ書けば足りる |
| App Privacy（収集する情報の申告） | 未（人間） | App Store Connect で申告する。メールアドレスと学習記録を扱う。公開中のプライバシーポリシー（`https://usalingo-app.vercel.app/privacy`）と食い違わせない |
| 年齢区分 | 未（人間） | App Store Connect の質問に答える。決まったらプライバシーポリシー第7条（対象年齢）にも反映する |

## 7. 他チケットが前提になっているもの

- **USL-255** 法務・ライセンス表示 — 済み（2026-09-02）
- **USL-245** Anki migration の本番適用 — 済み（2026-08-31）

## 8. 人間がやることだけを、順番に並べたもの

- [x] Apple Developer Program に加入する（個人で加入済み）
- [x] チームIDを控えて共有する（`CTSYH44JRG`）
- [x] アプリアイコンの絵を用意する（既存素材を採用）
- [x] 開発機の Xcode が 26 以降か確認する（アーカイブが通ったため実質確認済み。提出時に再確認する）
- [x] App Store Connect でアプリレコードを作る（USL-287）
- [x] 自分のApple Accountで内部TestFlightを利用できることを確認する（2026-09-04、USL-287）
- [ ] App Privacy と年齢区分に答える

残りは App Privacy と年齢区分だけです。Notion の Taskspace でチケットにしています。
人間向けの同じ一覧は Notion の Knowledge「Xcode｜TestFlight 配信の準備一覧」にもあります。

## 9. AIが確認できなかったこと

App Store Connect の中身はリポジトリからは見えません。アプリレコードと内部テストは、
USL-287 の完了報告（2026-09-04）を根拠に「済み」としています。App Privacy と
年齢区分は、答えたという記録がまだないため「未（人間）」のままです。

証明書、プロビジョニングプロファイル、Xcode のバージョンは、2026-09-01 に
アーカイブが成功したことで確認済みになりました。

## 10. 根拠

- [Apple Developer Program への加入](https://developer.apple.com/programs/enroll/)
- [メンバーシップの比較](https://developer.apple.com/support/compare-memberships/)
- [TestFlight の概要](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [内部テスターの追加](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- [今後の要件（SDKの最低バージョン）](https://developer.apple.com/news/upcoming-requirements/)
- [プライバシーマニフェスト](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [理由の申告が要る API](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

Apple の要件は変わります。この一覧を使う前に、上のリンクで現在の内容を確認してください。
