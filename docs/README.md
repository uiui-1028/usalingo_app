# Usalingo documentation

現行アプリは `apps/ios-swiftui/` のSwiftUI版です。旧Flutter・SQLite・旧DB・旧MVPの資料は履歴として分離しています。実装や判断では、次の順に参照します。

## 現行資料

1. [Anki型学習コア仕様](architecture/anki-aligned-spec.md)
2. [Anki型データモデルと移行設計](architecture/anki-data-model.md)
3. [公式コンテンツのDB・Storage契約](architecture/official-content-contract.md)
4. [Supabase運用](supabase/README.md)
5. [`supabase/migrations/`](../supabase/migrations/) — 実行可能SQLの正本
6. [現行SwiftUI 開発環境・技術スタック](development/technology-stack.md)
7. [現行リポジトリ構成](development/repository-layout.md)
8. [法務文書・旧PDFと公開前ドラフト](Fo｜02｜Terms%20of%20Use/README.md)

実装は `apps/ios-swiftui/UsalingoIOS/`、テストは `apps/ios-swiftui/UsalingoIOSTests/` を確認します。

## 検討中資料

次はまだ確定仕様ではありません。履歴資料を判断材料として残していますが、実装の正本にはしません。

- 退会仕様: USL-254・USL-257で判断予定。旧案は [ワークフロー設計](archive/legacy-spec-v2/workflow-design.md)
- 法務・AIGC: 公開前ドラフトは [法務文書](Fo｜02｜Terms%20of%20Use/README.md)。AI生成・共有機能はUSL-249・USL-255で判断予定。旧案は [AIGC方針](archive/legacy-spec-v2/aigc-policy.md)
- 類義語DB索引: 未採用のresearch。[検討レポート](archive/legacy-spec-v2/dynamic-synonym-index-research.md)

## 履歴資料

- [履歴資料の入口](archive/README.md)
- `Usalingo｜Specification Ver.2.0/` は、旧パスから移動先を案内する文書と、今回対象外の事業・コンテンツ・デザイン履歴を含みます。

履歴資料にはFlutter、SQLite、旧DB構造、旧MVP、Google Playなどの記述があります。現行の技術仕様として使用しません。

## 開発ルール

- [ルール一覧](rules/README.md)
- [Codexクレジット消費 最適化ルール](rules/codex-credit-optimization.md)
- [Supabase SQL・migration運用](rules/SQL_Query_Rules.md)
