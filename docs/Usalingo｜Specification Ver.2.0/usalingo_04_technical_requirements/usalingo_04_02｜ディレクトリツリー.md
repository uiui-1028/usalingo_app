# usalingo_04_02｜ディレクトリツリー

最終更新日: 2026-08-15
対象: 現行SwiftUIアプリとSupabase migration

現行アプリは `apps/ios-swiftui/` にあります。旧Flutter構成の `lib/`、`android/`、`web/`、`pubspec.yaml` などは現行構造ではありません。

```text
usalingo_app/
├── AGENTS.md                         # Codexが守るリポジトリルール
├── apps/
│   └── ios-swiftui/                  # 現行iOSアプリ
│       ├── README.md                 # セットアップとテスト方法
│       ├── Config/
│       │   └── Local.xcconfig.example # 秘密値を含まない設定例
│       ├── UsalingoIOS.xcodeproj/    # Xcodeプロジェクト
│       ├── UsalingoIOS/              # アプリ本体
│       │   ├── UsalingoIOSApp.swift  # アプリの入口
│       │   ├── App/
│       │   │   └── AppState.swift    # セッションなどの全体状態
│       │   ├── DesignSystem/
│       │   │   └── AppStyle.swift    # 共通色・カード・背景
│       │   ├── Features/             # 画面と機能単位のUI
│       │   │   ├── Auth/             # ログイン・アカウント作成
│       │   │   ├── Decks/            # デッキ一覧と進捗
│       │   │   ├── Design/           # デザイン設定
│       │   │   ├── Learning/         # 学習ダッシュボード
│       │   │   ├── Profile/          # プロフィール
│       │   │   ├── Shell/            # タブとアプリ外枠
│       │   │   ├── Study/            # カード表示と学習セッション
│       │   │   └── Words/            # 単語一覧、タグ、個人編集
│       │   ├── Models/               # Deck、WordCard、学習進捗など
│       │   └── Services/             # Auth、Supabase、学習、音声
│       └── UsalingoIOSTests/         # XCTest
│           ├── LearningProgressTests.swift
│           └── WordCardTests.swift
├── docs/
│   ├── README.md                     # 文書の読み順
│   ├── architecture/                 # 現行アーキテクチャの正本
│   │   ├── anki-aligned-spec.md
│   │   ├── anki-data-model.md
│   │   └── official-content-contract.md
│   ├── rules/                        # SQL、Codexなどの運用ルール
│   ├── supabase/                     # Supabase文書の入口
│   └── Usalingo｜Specification Ver.2.0/ # 事業・内容・UIの仕様と履歴
├── supabase/
│   └── migrations/                   # 実行可能SQLの正本
└── assets/                           # アイコンなどの制作素材
```

## 置き場所のルール

- 現行Swiftコードは `apps/ios-swiftui/UsalingoIOS/` に置く。
- Swiftテストは `apps/ios-swiftui/UsalingoIOSTests/` に置く。
- 実行可能なDB変更は `supabase/migrations/` に置く。
- 現行アーキテクチャの判断は `docs/architecture/` に置く。
- `Config/Local.xcconfig` は端末固有の秘密設定としてGitへ登録しない。
- Xcodeの `xcuserdata`、DerivedData、ビルド生成物は仕様や共有コードとして扱わない。

フォルダ名や責任を変えた場合は、コードだけでなくこの文書と `docs/README.md` の案内も更新します。
