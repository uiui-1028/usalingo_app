# Usalingo - 英語学習アプリ

## 📱 概要

Usalingoは、忘却曲線アルゴリズムを活用した効率的な英語学習アプリです。フラッシュカード形式で単語を学習し、個人の記憶パターンに基づいて最適な復習タイミングを提供します。

## 🚀 主な機能

- **フラッシュカード学習**: 直感的なスワイプ操作で単語を学習
- **忘却曲線アルゴリズム**: 科学的根拠に基づいた復習スケジュール
- **カスタマイズ可能なUI**: 複数のデザインテーマに対応
- **学習進捗管理**: 詳細な学習データの可視化

## 🛠️ 技術スタック

- **iOSアプリ**: Swift / SwiftUI（iOS 17以降）
- **ネットワーク**: Foundation / URLSession
- **バックエンド・データベース**: Supabase / PostgreSQL
- **認証**: Supabase Auth
- **ストレージ**: Supabase Storage
- **音声再生**: AVFoundation / AVPlayer
- **テスト**: XCTest

## 📚 ドキュメント

現行資料の入口は [docs/README.md](docs/README.md) です。

- [Anki型学習コア仕様](docs/architecture/anki-aligned-spec.md)
- [Anki型データモデル](docs/architecture/anki-data-model.md)
- [公式コンテンツ契約](docs/architecture/official-content-contract.md)
- [Supabase運用](docs/README.md)

## 🚀 セットアップ

### 前提条件

- Xcode
- iOS 17以降のSimulatorまたは実機
- Supabaseアカウント

### インストール

1. リポジトリをクローン

```bash
git clone https://github.com/uiui-1028/usalingo_app.git usalingo_app
cd usalingo_app
```

1. iOSアプリの設定ファイルを作成

```bash
cd apps/ios-swiftui
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

1. `Config/Local.xcconfig` にSupabaseの設定を記入

```text
SUPABASE_PROJECT_REF = YOUR_PROJECT_REF
SUPABASE_ANON_KEY = YOUR_SUPABASE_ANON_KEY
```

1. Xcodeでプロジェクトを開き、`UsalingoIOS` スキームを実行

```bash
open UsalingoIOS.xcodeproj
```

### テスト

```bash
xcodebuild -project UsalingoIOS.xcodeproj \
  -scheme UsalingoIOS \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

## 📖 開発ガイド

### アーキテクチャ

現行のiOSアプリは、SwiftUIの機能単位の画面とサービス層で構成しています。

- `apps/ios-swiftui/UsalingoIOS/Features/` - 機能別のSwiftUI画面
- `apps/ios-swiftui/UsalingoIOS/Models/` - データモデル
- `apps/ios-swiftui/UsalingoIOS/Services/` - Supabase通信・認証・音声再生
- `supabase/migrations/` - データベース変更履歴

### コーディング規約

詳細は `docs/operations/` を参照してください。

## 🤝 貢献

プルリクエストやイシューの報告を歓迎します。
