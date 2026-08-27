# Usalingo documentation

現行アプリは `apps/ios-swiftui/` のSwiftUI版です。旧Flutter・SQLite・旧DB・旧MVPの資料は履歴として分離しています。実装や判断では、次の順に参照します。

## 方向づけ

- [Usalingoのいちばん大きな計画](usalingo-simple-product-plan.md)
- [学習ワークフローと初期機能要件の決定](decisions/usalingo-core-workflow-requirements.md)
- [ワークフロー設計 実行計画書](usalingo-workflow-planning-execution-plan.md)
- [ワークフロー策定の記録](workflow-records/README.md)

## これからの計画

- [既製品採用 実行計画書](plans/external-package-adoption-plan.md) — 法務表示、画像キャッシュ、学習記録、オフライン
- [`docs/` 整理 実行計画書](plans/docs-restructure-plan.md) — 文書の置き場所の作り直し
- [`docs/` 整理 実施計画書](plans/docs-restructure-execution.md) — 上の計画を実行するための手順

## 現行資料

1. [Anki型学習コア仕様](architecture/anki-aligned-spec.md)
2. [Anki型データモデルと移行設計](architecture/anki-data-model.md)
3. [公式コンテンツのDB・Storage契約](architecture/official-content-contract.md)
4. [退会・復元・最終削除のデータ契約](architecture/account-deletion-contract.md)
5. [Supabase運用](supabase/README.md)
6. [`supabase/migrations/`](../supabase/migrations/) — 実行可能SQLの正本
7. [現行SwiftUI 開発環境・技術スタック](development/technology-stack.md)
8. [現行リポジトリ構成](development/repository-layout.md)

実装は `apps/ios-swiftui/UsalingoIOS/`、テストは `apps/ios-swiftui/UsalingoIOSTests/` を確認します。

## 検討中資料

次はまだ確定仕様ではありません。履歴資料を判断材料として残していますが、実装の正本にはしません。

- 法務・AIGC: USL-249・USL-255で判断予定。旧案は [AIGC方針](archive/legacy-spec-v2/aigc-policy.md)
- 類義語DB索引: 未採用のresearch。[検討レポート](archive/legacy-spec-v2/dynamic-synonym-index-research.md)

## 履歴資料

- [履歴資料の入口](archive/README.md)
- `Usalingo｜Specification Ver.2.0/` は、旧パスから移動先を案内する文書と、今回対象外の事業・コンテンツ・デザイン履歴を含みます。

履歴資料にはFlutter、SQLite、旧DB構造、旧MVP、Google Playなどの記述があります。現行の技術仕様として使用しません。

## 開発ルール

- [ルール一覧](rules/README.md)
- [Codexクレジット消費 最適化ルール](rules/codex-credit-optimization.md)
- [Supabase SQL・migration運用](rules/SQL_Query_Rules.md)
