# 開発環境セットアップガイド

## 前提条件

### 必要なソフトウェア
- **Flutter SDK**: 3.8.1以上
- **Dart SDK**: 3.0.0以上
- **Android Studio** / **VS Code**: 推奨IDE
- **Git**: バージョン管理
- **Xcode**: iOS開発用（macOSのみ）

### 推奨ツール
- **Cursor AI Editor**: AI支援開発
- **Claude**: AI支援開発
- **Postman**: APIテスト
- **Supabase CLI**: データベース管理

## セットアップ手順

### 1. Flutter環境の準備
```bash
# Flutter SDKのインストール確認
flutter doctor

# 依存関係のインストール
flutter pub get

# コード品質チェック
flutter analyze
```

### 2. プロジェクト設定
```bash
# プロジェクトのクローン
git clone [repository-url]
cd usalingo_app

# 依存関係のインストール
flutter pub get

# 環境設定ファイルの準備
cp lib/secrets.dart.example lib/secrets.dart
# secrets.dartファイルを編集してAPIキーを設定
```

### 3. データベース設定

#### SQLite設定
```bash
# データベーススキーマの確認
flutter packages pub run build_runner build
```

#### Supabase設定
1. Supabaseプロジェクトの作成
2. 環境変数の設定
3. データベーススキーマの適用

### 4. 開発ツールの設定

#### Cursor AI Editor
- `docs/rules/cursor-rules.md`を設定ファイルに追加
- プロジェクト固有のルールを適用

#### Claude
- `docs/rules/claude-rules.md`を設定ファイルに追加
- プロジェクト固有のルールを適用

## 開発フロー

### 日常的な開発手順
```bash
# 開発開始前
flutter doctor
flutter clean && flutter pub get

# コード品質チェック
flutter analyze
dart format .

# テスト実行
flutter test

# ビルド確認
flutter build apk --debug
flutter build ios --debug
```

### ブランチ戦略
- `main`: 本番環境
- `develop`: 開発環境
- `feature/*`: 機能開発
- `hotfix/*`: 緊急修正

## トラブルシューティング

### よくある問題
1. **依存関係エラー**: `flutter clean && flutter pub get`
2. **ビルドエラー**: `flutter doctor`で環境確認
3. **iOSビルドエラー**: Xcodeの設定確認
4. **Androidビルドエラー**: Android SDKの設定確認

### デバッグ方法
```bash
# ログの確認
flutter logs

# パフォーマンス分析
flutter run --profile

# メモリ使用量の確認
flutter run --trace-startup
```

## 推奨設定

### VS Code設定
```json
{
  "dart.flutterSdkPath": "path/to/flutter",
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  }
}
```

### Git設定
```bash
# コミットメッセージのテンプレート
git config commit.template .gitmessage

# フックの設定
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
``` 