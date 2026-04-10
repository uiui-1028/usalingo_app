# Usalingo - 英語学習アプリ

## 📱 概要

Usalingoは、忘却曲線アルゴリズムを活用した効率的な英語学習アプリです。フラッシュカード形式で単語を学習し、個人の記憶パターンに基づいて最適な復習タイミングを提供します。

## 🚀 主な機能

- **フラッシュカード学習**: 直感的なスワイプ操作で単語を学習
- **忘却曲線アルゴリズム**: 科学的根拠に基づいた復習スケジュール
- **カスタマイズ可能なUI**: 複数のデザインテーマに対応
- **学習進捗管理**: 詳細な学習データの可視化
- **オフライン対応**: インターネット接続なしでも学習可能

## 🛠️ 技術スタック

- **フロントエンド（モバイル）**: Flutter (Dart)
- **フロントエンド（Web）**: Next.js (TypeScript)
- **バックエンド**: Supabase
- **データベース**: PostgreSQL
- **認証**: Supabase Auth
- **ストレージ**: Supabase Storage

## 📚 ドキュメント

詳細なドキュメントは `docs/` フォルダを参照してください。

- [アーキテクチャ設計](docs/architecture/)
- [機能仕様](docs/features/)
- [開発ルール](docs/rules/)
- [Supabase設定](docs/supabase/)

## 🌐 Web版（Next.js）

Web版は `apps/web` に配置しています。  
開発フェーズの無料運用と親和性を重視して、デプロイ先は **Vercel** を推奨しています。

```bash
cd apps/web
npm install
cp .env.example .env.local
npm run dev
```

## 🚀 セットアップ

### 前提条件

- Flutter SDK (最新版)
- Dart SDK
- Supabaseアカウント

### インストール

1. リポジトリをクローン

```bash
git clone https://github.com/uiui-1028/usalingo_app_flutter.git
cd usalingo_app_flutter
```

1. 依存関係をインストール

```bash
flutter pub get
```

1. 環境設定

```bash
# Supabaseの設定を追加
cp lib/secrets.dart.example lib/secrets.dart
# secrets.dartにSupabaseの設定を記入
```

1. アプリを実行

```bash
flutter run
```

## 🌐 Web版での実行（永続運用を想定した設定注入）

SupabaseのURL/Anon Keyは、Webデプロイ時に環境として注入できるように `--dart-define` を優先して参照します。

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://xxxx.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="xxxxx"
```

ビルド時も同様です。

```bash
flutter build web \
  --dart-define=SUPABASE_URL="https://xxxx.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="xxxxx"
```

## 📖 開発ガイド

### アーキテクチャ

このプロジェクトはClean Architectureを採用しています：

- `lib/domain/` - ビジネスロジック
- `lib/data/` - データアクセス層
- `lib/presentation/` - UI層

### コーディング規約

詳細は `docs/rules/` を参照してください。

## 🤝 貢献

プルリクエストやイシューの報告を歓迎します。

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。
