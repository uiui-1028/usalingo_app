# Usalingo documentation

現行アプリは `apps/ios-swiftui/` のSwiftUI版です。文書は「いつまで有効か」で棚を分けています。

| 棚 | 中身 |
|---|---|
| [product/](product/) | 何を作るか。製品計画と学習ワークフロー |
| [architecture/](architecture/) | いまの仕組みの正本。学習コア、データモデル、コンテンツ契約、退会 |
| [content/](content/) | 教材データの原本設計 |
| [operations/](operations/) | 開発環境、技術スタック、SQL・クレジットのルール、手順書 |
| [decisions/](decisions/) | 決めたことの記録。あとから書き換えない |
| [plans/](plans/) | これからやることの計画書。優先順位は [plans/milestones.md](plans/milestones.md) が決める |
| [legal/](legal/) | 公開する文書と、素材・プライバシーの台帳 |
| [archive/](archive/) | 昔の資料。いまの判断には使わない |

実行できるDB変更は [`supabase/migrations/`](../supabase/migrations/) が正本です。実装は `apps/ios-swiftui/UsalingoIOS/`、テストは `apps/ios-swiftui/UsalingoIOSTests/` にあります。

新しい文書をどこへ置くかは [operations/repository-layout.md](operations/repository-layout.md) に書いてあります。
