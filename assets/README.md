# アイコン素材の監査結果

最終監査日: 2026-08-16

現行Xcodeプロジェクト、Swiftコード、文書には、`assets/usalingo_app_icon/` または `assets/usalingo_iconcomposer/` をアプリアイコンとして組み込む参照がありません。Asset Catalogもまだなく、採用アイコンは未決定です。そのため画像は削除せず、次の3分類で管理します。

## 1. 再生成に必要な元データ

- `usalingo_iconcomposer/Usalingo.icon/`
  - `icon.json`
  - `Assets/描画.svg`
  - `Assets/すくしょ 2025-08-10 19.03.18.png`
  - `Assets/file.svg`（現在は非表示レイヤーだが、元データを完全に保つため残す）
- `usalingo_iconcomposer/素材01｜背景透過.png`
- `usalingo_iconcomposer/素材02｜背景透過.svg`
- `usalingo_iconcomposer/素材03｜白背景.png`
- `usalingo_app_icon/` のロゴ・背景素材一式

`素材02` と `Usalingo.icon/Assets/描画.svg`、`素材03` と `Usalingo.icon/Assets/すくしょ 2025-08-10 19.03.18.png` はそれぞれ同一ハッシュです。元データの役割が確定していないため、現時点では両方残します。

## 2. 現在採用する候補

- `usalingo_iconcomposer/Icons｜SimpleFlatt/`
- `usalingo_iconcomposer/Icons｜Glassmorphism/`

どちらも生成候補で、Xcodeには未統合です。採用決定後にAsset CatalogまたはIcon Composerの成果物として組み込みます。

## 3. 再生成可能な重複出力

SHA-256で次の完全一致を確認しました。

- Glassmorphism: `Default`、`Dark`、`ClearLight`、`ClearDark`、`TintedLight`、`TintedDark` の各iOS/macOSペア
- SimpleFlatt: `ClearLight`、`ClearDark`、`TintedLight`、`TintedDark` の各iOS/macOSペア
- SimpleFlatt: iOS/macOSの `Default` と `Dark` の4ファイルはすべて同一

各同一グループを1ファイルだけ残す場合、22,471,159 bytes（約21.43 MiB）を削減できます。watchOS出力は重複していません。削除は、採用候補の決定と対象一覧の明示承認後に行います。

復旧方法は、Gitの現在履歴から対象ファイルを戻す方法と、`Usalingo.icon` をIcon Composerで開いて再生成する方法があります。Git履歴の書き換えは行いません。
