# TestFlight配信の準備一覧（USL-277）

作成日: 2026-08-31

対象: 内部テスターへの TestFlight 配信（M1）。App Store の一般公開は含めない。

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
| Bundle ID（Apple側の登録） | 未確認 | 人間が Certificates, Identifiers & Profiles で同じ ID を登録する。自動署名なら Xcode が登録する場合もある |
| バージョン / ビルド番号 | 済み | `MARKETING_VERSION = 0.1.0`、`CURRENT_PROJECT_VERSION = 1` |
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
| **iOS 26 SDK / Xcode 26** | **未確認** | 2026年4月28日以降、App Store Connect へアップロードするアプリは iOS 26 SDK 以降でビルドしたものに限られる。人間が開発機の Xcode を確認する |
| CI のランナー | 済み（要注意） | `ios-ci.yml` は `macos-15`。**テストには足りるが、将来ここでアーカイブするなら Xcode 26 が載るランナーへ上げる必要がある**（USL-291） |

## 5. App Store Connect

| 項目 | 状態 | やること |
|---|---|---|
| アプリレコード | 未確認 | 人間が作る。**TestFlight を使う前に必須**。アプリ名、主言語、Bundle ID、SKU が要る。アプリ名は App Store 全体で一意 |
| 内部テスターの登録 | 未（人間） | App Store Connect のユーザーを最大 **100人** まで内部テスターにできる。Account Holder / Admin / App Manager / Developer / Marketing のいずれかの役割が要る |
| Beta App Review | 不要 | **内部テストは審査なしで配れる。**外部テスターへ配る場合だけ審査が要る |
| ビルドの有効期限 | 情報 | アップロードしたビルドは **90日** でテストできなくなる |
| テスト情報 | 未（人間） | ベータ版の説明、試してほしいこと、フィードバック用のメールアドレス。内部テストでも入力欄がある |

## 6. 提出時に必ず聞かれること

| 項目 | 状態 | やること |
|---|---|---|
| 輸出コンプライアンス | 未（AI） | 独自の暗号は使っていない（`CryptoKit`、`CommonCrypto`、`SecKey` の利用なし）。通信は HTTPS のみ。`Info.plist` に `ITSAppUsesNonExemptEncryption = false` を入れると、アップロードのたびに聞かれなくなる。最終判断は人間が行う |
| **プライバシーマニフェスト** | **未（AI）** | `PrivacyInfo.xcprivacy` が存在しない。`UserDefaults` を使っている（`Models/DesignSettings.swift`、`App/AppState.swift`）ため、理由の申告が要る API に該当する。**第三者SDKは使っていない**（Swift Package の依存はゼロで、Supabase へは自前の `URLSession` で接続している）ので、自分のコードの分だけ書けば足りる |
| App Privacy（収集する情報の申告） | 未（人間） | App Store Connect で申告する。メールアドレスと学習記録を扱う。既存のプライバシーポリシーと食い違わせない |
| 年齢区分 | 未（人間） | App Store Connect の質問に答える |

## 7. 他チケットが前提になっているもの

- **USL-255** 法務・ライセンス表示 — `Resources/Licenses/` が空。人に配るなら必要
- **USL-245** Anki migration の本番適用 — 適用まで学習記録のバックアップが保存時にエラーになる

## 8. 人間がやることだけを、順番に並べたもの

- [x] Apple Developer Program に加入する（個人で加入済み）
- [x] チームIDを控えて共有する（`CTSYH44JRG`）
- [x] アプリアイコンの絵を用意する（既存素材を採用）
- [x] 開発機の Xcode が 26 以降か確認する（アーカイブが通ったため実質確認済み。提出時に再確認する）
- [ ] App Store Connect でアプリレコードを作る（アプリ名を決める）
- [ ] 内部テスターを招待する
- [ ] App Privacy と年齢区分に答える

残っている4つは、どれから始めても構いません。

## 9. AIが確認できなかったこと

次はリポジトリからは見えないため、この文書では「未確認」としています。誤って
「済み」と書かないための記録です。

- App Store Connect にアプリレコードがあるかどうか

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
