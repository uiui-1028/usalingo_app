## ***【 usalingo_04_01｜開発環境 & 技術スタック 】***

*開発に使用するハードウェア、ソフトウェア、クラウドサービスから、アプリケーションの根幹を成す主要なライブラリまで、本プロジェクトを構成する全ての技術要素を定義する。*

---

### **● ハードウェア環境**

| 開発マシン | MacBook Air (15-inch, M2, 2023)
**チップ**: Apple M2
**メモリ**: 16 GB
**OS**: macOS Sequoia 15.6 |
| --- | --- |
| テスト用実機 | iPhone 12 (64GB) |

---

### **● ソフトウェア環境**

https://github.com/uiui-1028/usalingo_app_flutter

| IDE | Cursur AI Editer (VS Codeベース) |
| --- | --- |
| 言語／フレーム | Flutter (Dart) |
| AIエージェント | Claude Code, Gemini CLI |
| バージョン管理 | Git / GitHub |
| CI／CD | GitHub Actions |
| デザイン | Figma, Canva, iconComposer, ibisPaint |
| プロジェクト管理 | Notion, Gemini, Claude, Cursur, GoogleWorkspace |

---

### **● クラウド環境**

| BaaS | Supabase |
| --- | --- |
| データベース | Supabase Database (PostgreSQL) |
| 認証 | Supabase Auth |
| ストレージ | Supabase Storage (画像・音声) |
| アセット調達 | LottieFiles Marketplace |

---

### **● Flutter ライブラリ／パッケージング**

| 領域 | ライブラリ | 役割・責務 |
| --- | --- | --- |
| **状態管理 & DI** | **flutter_riverpod** | UIとビジネスロジックを分離し、アプリケーション全体の状態（データ）を管理する。各機能が必要とする部品（Repository, Usecaseなど）の供給も担う、`usalingo`の心臓部。 |
| **画面遷移** | **go_router** | URLベースで画面間の移動を宣言的に管理する。Web版への展開やディープリンク実装の基盤となる、アプリケーションの神経系。 |
| **ローカルDB** | **drift** | 忘却曲線アルゴリズムの進捗データなど、オフライン環境で利用する構造化データを型安全に管理する。SQLiteのパワーを最大限に引き出すためのデータ永続化層。 |
| **バックエンド連携** | **supabase_flutter** | BaaSであるSupabaseとの認証、DB同期、ストレージ操作など、サーバーとのあらゆる通信を担う。 |
| **UIアニメーション** | **lottie** | マイクロリワードやローディング画面など、ユーザー体験を豊かにする高品質なアニメーションを再生する。 |