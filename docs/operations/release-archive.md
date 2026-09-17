# Releaseアーカイブ手順（USL-282）

作成日: 2026-08-31

対象: `apps/ios-swiftui/` を TestFlight へ出せる形（署名済み Release アーカイブ）にする手順。

配信では Debug ビルドではなく、署名済みの Release アーカイブが要ります。この文書の
とおりにやれば、何度やっても同じ結果になります。

## 0. アーカイブ前に必ず見るもの

> [!WARNING]
> **`Config/Local.xcconfig` に本番の値が入っているか、毎回確認してください。**
> このファイルは鍵を含むため Git に入っていません。値が空のままでもアーカイブは
> **成功してしまい**、起動はするのに通信だけ全部失敗するアプリが出来上がります。
> テスターに配ってから気づくのがいちばん困る失敗です。

```bash
cd apps/ios-swiftui
cat Config/Local.xcconfig
```

`SUPABASE_PROJECT_REF` と `SUPABASE_ANON_KEY` に実際の値が入っていること。
無ければ雛形から作ります。

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# エディタで本番の値を入れる
```

値は `Info.plist` を経由して `Services/SupabaseConfig.swift` が読みます。
Debug と Release の**両方**がこのファイルを参照しているので、Release でも同じ経路で入ります。

## 1. 設定済みのもの（変更不要）

| 設定 | 値 | 意味 |
|---|---|---|
| `DEVELOPMENT_TEAM` | `CTSYH44JRG` | 署名に使うチーム。USL-282 で設定 |
| `CODE_SIGN_STYLE` | `Automatic` | 証明書とプロファイルを Xcode が管理する |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.usalingo.ios` | |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `0.1.0` / `1` | 表示用バージョンとビルド番号 |
| `SWIFT_COMPILATION_MODE`（Release） | `wholemodule` | 最適化 |
| `DEBUG_INFORMATION_FORMAT`（Release） | `dwarf-with-dsym` | クラッシュ解析用のシンボル |
| `ENABLE_NS_ASSERTIONS`（Release） | `NO` | |
| `VALIDATE_PRODUCT`（Release） | `YES` | 成果物の検査 |

ビットコードの設定はありません。Apple が廃止したため、入れないのが正しい状態です。

## 2. アーカイブする

### 手順1: 開発機を最新にする

設定を変えた直後は、開発機のコードが古いままのことがあります。Xcode は古い設定で
署名してしまうため、**先に取り込んでから開きます**。

```bash
cd <リポジトリのパス>
git checkout main
git pull origin main
grep DEVELOPMENT_TEAM apps/ios-swiftui/UsalingoIOS.xcodeproj/project.pbxproj
```

最後の行で `DEVELOPMENT_TEAM = CTSYH44JRG;` が2行出ることを確認します。
Xcode を開いたままなら、**いったん終了して開き直します**。

### 手順2: Xcode から

1. Xcode で `apps/ios-swiftui/UsalingoIOS.xcodeproj` を開く
2. 実行先を **Any iOS Device (arm64)** にする（シミュレータではアーカイブできません）
3. メニューの **Product → Archive**
4. Organizer が開いたら **Distribute App → TestFlight & App Store**

### 手順2の代わり: コマンドから

```bash
cd apps/ios-swiftui
xcodebuild archive \
  -project UsalingoIOS.xcodeproj \
  -scheme UsalingoIOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/UsalingoIOS.xcarchive
```

`build/` は Git に入れません。

## 3. うまくいかないとき

| 症状 | 原因と直し方 |
|---|---|
| `No signing certificate "iOS Distribution" found` | Xcode の Settings → Accounts に Apple Account を追加し、チームを選ぶ。証明書は自動管理なら Xcode が作る |
| `No profiles for 'com.usalingo.ios' were found` | 同じ Bundle ID が Apple 側に登録されていない。Certificates, Identifiers & Profiles で登録するか、Xcode の「Try Again」に任せる |
| アーカイブは通るが通信が全部失敗する | **0章の `Local.xcconfig` を確認**。値が空のまま |
| シミュレータ用しか作れない | 実行先が Any iOS Device になっていない |
| **Organizer の Team が `(Personal Team)` になる** | **開発機のコードが古い。**`DEVELOPMENT_TEAM` の設定がまだ手元へ届いていないと、Xcode は無料枠の仮チームで署名する。2章の手順1を実行して Xcode を開き直す。Personal Team のアーカイブは TestFlight へ出せない |
| 設定を直したのに反映されない | Xcode が起動中は古い設定を保持する。**Xcode を終了して開き直す** |

## 4. この手順に含まれないもの

- **CI での自動化** — 下の7章（USL-291）
- **App Store Connect への提出と自分のiPhoneへの内部配布** — USL-287
- **輸出コンプライアンス、プライバシー、年齢区分の申告** — [TestFlight配信の準備一覧](testflight-release-checklist.md) の6章
- **テストターゲットの署名** — 実機でテストを走らせる場合は `UsalingoIOSTests` にも `DEVELOPMENT_TEAM` が要ります。アーカイブには不要なため設定していません。CI はシミュレータで `CODE_SIGNING_ALLOWED=NO` のため影響しません

## 5. 秘密情報の扱い

- `Config/Local.xcconfig` は `apps/ios-swiftui/.gitignore` で除外済み。追跡されているのは `.example` だけ
- 証明書（`.p12`）、プロビジョニングプロファイル（`.mobileprovision`）はリポジトリへ置かない
- `DEVELOPMENT_TEAM` のチームIDは秘密情報ではありません。署名済みアプリから読み取れる公開値なので、`project.pbxproj` に書いて問題ありません

## 6. 実施記録

**2026-09-01、初回のアーカイブに成功しました。**

| 項目 | 値 |
|---|---|
| Version | `0.1.0 (1)` |
| Identifier | `com.usalingo.ios` |
| Type | `iOS App Archive` |
| Team | `Taiga Kawai`（有料の Developer Program チーム） |
| Architectures | `arm64` |

> [!IMPORTANT]
> Organizer の **Team 欄に `(Personal Team)` が付いていないこと**が、配信できる
> アーカイブかどうかの見分け方です。付いている場合は無料枠の仮チームで署名されており、
> TestFlight へは出せません。

初回で実際に詰まったのは「開発機のコードが古く、Personal Team で署名された」の1点でした。
3章へ追記済みです。以降で新しい症状が出たら、同じように3章へ足してください。

## 7. CIで作ってアップロードする（USL-291）

2回目以降は、手元でアーカイブせずに GitHub Actions の `iOS Release`
（`.github/workflows/ios-release.yml`）で作れます。やることは上の手順と同じで、
アーカイブは署名なしで作り、書き出しのときに App Store Connect の API キーでクラウド署名します。証明書（`.p12`）は使いません。

### 最初に1回だけ: Secrets を登録する

GitHub のリポジトリの Settings → Secrets and variables → Actions に、次の5つを登録します。

| 名前 | 中身 |
|---|---|
| `SUPABASE_PROJECT_REF` | 本番の値（`Config/Local.xcconfig` と同じ） |
| `SUPABASE_ANON_KEY` | 本番の値（`Config/Local.xcconfig` と同じ） |
| `ASC_KEY_ID` | App Store Connect API キーのキーID |
| `ASC_ISSUER_ID` | 同じ画面の発行者ID |
| `ASC_KEY_P8` | ダウンロードした `AuthKey_XXXX.p8` の中身すべて（`-----BEGIN` から `END-----` まで） |

API キーは App Store Connect の「ユーザとアクセス → 統合 → App Store Connect API」で
**チームキー**として作ります。クラウド署名で配布用証明書を扱うため、役割は **Admin** にします。
`.p8` は一度しかダウンロードできません。登録したら手元のファイルは安全な場所へしまいます。

### 毎回: 実行する

1. GitHub の Actions → **iOS Release** → **Run workflow**（ブランチは `main`）
2. `build_number` に**前回アップロードより大きい整数**を入れる。バージョン（`MARKETING_VERSION`）は変わりません
3. `upload` は、そのままなら App Store Connect へ送ります。外すと ipa を作って Artifacts に7日間保存するだけです
4. 終わって数分〜数十分すると、App Store Connect の TestFlight にビルドが出ます。**テスターへの配布は画面から手で行います**。審査提出はしません

| 症状 | 原因と直し方 |
|---|---|
| `Secret ... が登録されていません` | 上の表の Secrets を登録する |
| 何もせずに終わる（ジョブが skipped） | `main` 以外のブランチで押した。`main` を選び直す |
| `Cloud signing permission error` など署名で失敗 | API キーの役割が足りない。Admin のチームキーで作り直す |
| アップロードで「ビルド番号が使用済み」 | `build_number` を前回より大きくする |
