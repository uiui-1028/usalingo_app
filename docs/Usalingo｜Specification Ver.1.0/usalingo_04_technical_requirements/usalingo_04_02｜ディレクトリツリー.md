## ***【 usalingo_04_02｜ディレクトリツリー 】***

*クリーンアーキテクチャの設計思想に基づき、ソースコードやアセットが格納されるファイルとフォルダの階層構造を定義し、プロジェクト全体の保守性と見通しの良さを担保する。*

```yaml
# 【 最終更新：2025/08/03 】
usalingo_app/
├── .git/                    # Gitリポジトリの管理ファイル
├── .dart_tool/              # Dartツールのキャッシュと設定
├── .idea/                   # IntelliJ IDEAの設定ファイル
├── build/                   # ビルド出力ディレクトリ
├── lib/                     # メインのDartソースコード
│   ├── app/                 # アプリケーションの初期化とDI設定
│   │   ├── app.dart         # アプリケーションのメイン設定
│   │   └── providers.dart   # 依存性注入のプロバイダー設定
│   ├── data/                # データ層（Clean Architecture）
│   │   ├── datasources/     # データソース（Supabase、SQLite等）
│   │   │   ├── learning_progress_datasource.dart  # 学習進捗データソース
│   │   │   ├── local_word_datasource.dart         # ローカル単語データソース
│   │   │   └── sqlite_schema.dart                 # SQLiteスキーマ定義
│   │   ├── models/          # データ転送オブジェクト（DTO）
│   │   └── repositories/    # リポジトリの実装
│   │       ├── learning_progress_repository_impl.dart  # 学習進捗リポジトリ実装
│   │       ├── word_repository_impl.dart              # 単語リポジトリ実装
│   │       ├── word_repository_selector.dart          # リポジトリ選択ロジック
│   │       ├── word_repository_sqlite.dart            # SQLite単語リポジトリ
│   │       └── word_repository_supabase.dart          # Supabase単語リポジトリ
│   ├── domain/              # ドメイン層（Clean Architecture）
│   │   ├── entities/        # ビジネスエンティティ
│   │   │   ├── learning_progress.dart  # 学習進捗エンティティ
│   │   │   └── word.dart               # 単語エンティティ
│   │   ├── repositories/    # リポジトリのインターフェース
│   │   └── usecases/       # ビジネスロジック（ユースケース）
│   │       ├── get_due_today_cards.dart      # 今日学習すべきカード取得
│   │       ├── get_learning_progress.dart    # 学習進捗取得
│   │       ├── get_next_word.dart            # 次の単語取得
│   │       └── mark_card_result.dart         # カード結果記録
│   ├── presentation/        # プレゼンテーション層（Clean Architecture）
│   │   ├── pages/          # 画面UIと状態管理
│   │   │   ├── flashcard_page.dart              # フラッシュカード画面
│   │   │   ├── learning_progress_test_page.dart # 学習進捗テスト画面
│   │   │   ├── root_page.dart                   # ルート画面
│   │   │   ├── supabase_test_page.dart          # Supabaseテスト画面
│   │   │   ├── test_3d_card_screen.dart         # 3Dカードテスト画面
│   │   │   ├── theme_selector_page.dart         # テーマ選択画面
│   │   │   └── word_list_page.dart              # 単語リスト画面
│   │   ├── theme/          # テーマ設定
│   │   │   ├── app_theme.dart                   # アプリテーマ設定
│   │   │   ├── app_theme_provider.dart          # テーマプロバイダー
│   │   │   └── themes/                          # 各テーマの実装
│   │   │       ├── flat_theme.dart              # フラットテーマ
│   │   │       ├── material_theme.dart          # Materialテーマ
│   │   │       ├── mockup_theme.dart            # モックアップテーマ
│   │   │       ├── neumorphism_theme.dart       # ニューモーフィズムテーマ
│   │   │       ├── pixel_art_theme.dart         # ピクセルアートテーマ
│   │   │       └── wireframe_theme.dart         # ワイヤーフレームテーマ
│   │   └── blocks/        # 再利用可能なブロック
│   │       ├── flashcard_block.dart            # フラッシュカードブロック
│   │       └── lottie_feedback_block.dart      # Lottieフィードバックブロック
│   ├── main.dart           # アプリケーションのエントリーポイント
│   └── secrets.dart        # 機密情報（APIキー等）
├── docs/                     # メインのDartソースコード
│   ├── README.md                  # ドキュメント全体の概要
│   ├── rules/                     # 開発ルール（既存）
│   │   ├── README.md
│   │   ├── common-rules.md        # Cursor AI Editor用のルール
│   │   ├── cursor-rules.md        # Claude用のルール
│   │   └── claude-rules.md        # 共通ルール（重複部分）
│   ├── architecture/              # アーキテクチャ設計
│   │   └── overview.md            # システム設計概要
│   ├── development/               # 開発ガイド
│   │   └── setup.md               # 開発環境セットアップ
│   ├── features/                  # 機能仕様書
│   │   └── flashcard-system.md    # フラッシュカード機能
│   └── troubleshooting/           # トラブルシューティング
│       └── common-issues.md       # よくある問題と解決方法
├── assets/                 # 静的アセット
│   ├── audio/              # 音声ファイル
│   └── lottie/             # Lottieアニメーションファイル
├── android/                # Androidプラットフォーム固有のファイル
├── ios/                    # iOSプラットフォーム固有のファイル
├── linux/                  # Linuxプラットフォーム固有のファイル
├── macos/                  # macOSプラットフォーム固有のファイル
├── windows/                # Windowsプラットフォーム固有のファイル
├── web/                    # Webプラットフォーム固有のファイル
├── test/                   # テストコード
├── .DS_Store               # macOSシステムファイル
├── .flutter-plugins-dependencies # Flutterプラグイン依存関係
├── .gitignore              # Git除外設定
├── .metadata               # Flutterメタデータ
├── analysis_options.yaml    # Dart解析設定
├── devtools_options.yaml   # Flutter DevTools設定
├── pubspec.lock            # 依存関係ロックファイル
├── pubspec.yaml            # プロジェクト設定と依存関係
├── README.md               # プロジェクト概要
└── usalingo_app.iml       # IntelliJ IDEAプロジェクト設定
```