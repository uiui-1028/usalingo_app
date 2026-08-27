# 現行リポジトリ構成

最終更新日: 2026-08-27
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
│   ├── product/                      # 何を作るか（製品計画・学習ワークフロー）
│   ├── content/                      # 教材データの原本設計
│   ├── decisions/                    # 決めたことの記録（書き換えない）
│   ├── plans/                        # これから行う作業の計画書
│   ├── operations/                   # 開発環境、技術スタック、ルール、手順書
│   ├── legal/                        # 公開文書と素材・プライバシーの台帳
│   └── archive/                      # 現行仕様ではない履歴・検討資料
├── supabase/
│   └── migrations/                   # 実行可能SQLの正本
└── assets/                           # アイコンなどの制作素材
```

## 置き場所のルール

- 現行Swiftコードは `apps/ios-swiftui/UsalingoIOS/` に置く。
- Swiftテストは `apps/ios-swiftui/UsalingoIOSTests/` に置く。
- 実行可能なDB変更は `supabase/migrations/` に置く。
- 文書は `docs/` に置く。棚は下の3つの原則で選ぶ。
- `Config/Local.xcconfig` は端末固有の秘密設定としてGitへ登録しない。
- Xcodeの `xcuserdata`、DerivedData、ビルド生成物は仕様や共有コードとして扱わない。

フォルダ名や責任を変えた場合は、コードだけでなくこの文書と `docs/README.md` の案内も更新します。

## 文書をどこへ置くか

置き場所で迷ったら、この3つに当てはめます。

### 1. 正本は1つ

同じことを2か所に書きません。片方は必ずリンクにします。2か所にあると、片方だけ直したときにどちらが正しいか分からなくなります。

### 2. 内容ではなく「寿命」で棚を分ける

| 寿命 | 例 | 棚 |
|---|---|---|
| ずっと変わらない | 何を作るか、誰のために作るか | `docs/product/` |
| いま有効（変わったら書き換える） | データ構造、契約、開発環境、教材の作り方 | `docs/architecture/` `docs/operations/` `docs/content/` |
| 一度書いたら書き換えない | 決定の記録、これからの計画 | `docs/decisions/` `docs/plans/` |
| もう有効ではない | 旧仕様、終わった作業記録 | `docs/archive/` |
| 公開するもの | 規約、ポリシー、素材台帳 | `docs/legal/` |

書き換える棚と、書き換えない棚を混ぜないことが要点です。

### 3. 毎回読ませる文書を小さく固定する

生成AIが毎回読む文書は `docs/README.md` と `docs/operations/credit-optimization.md` の2つだけです。ここが大きくなるほど、毎回のコストが増えます。増やす前に、本当に毎回必要かを確かめます。

棚は8つです。増やしません。迷ったら `docs/decisions/` に日付つきで置いて、あとで移します。

ファイル名は半角の英小文字とハイフンにします。全角の `｜` や空白は、検索、シェル、相対リンク、CIで壊れます。

整理の経緯は [`docs/plans/docs-restructure-plan.md`](../plans/docs-restructure-plan.md) と [`docs/plans/docs-restructure-execution.md`](../plans/docs-restructure-execution.md) にあります。
