# 履歴資料

この配下は、過去の設計や未採用の検討を失わないための保存場所です。**現行仕様として使用しません。** 現行資料は [`docs/README.md`](../README.md) から参照してください。

## 旧Specification Ver.2.0（技術）

- [旧データベース設計](legacy-spec-v2/database-design.md)
- [旧アルゴリズム設計](legacy-spec-v2/algorithm-design.md)
- [旧ワークフロー設計](legacy-spec-v2/workflow-design.md)
- [旧アセット管理設計](legacy-spec-v2/asset-management-design.md)
- [旧ワイヤーフレームコンポーネント](legacy-spec-v2/wireframe-components.md)
- [類義語DB索引の検討](legacy-spec-v2/dynamic-synonym-index-research.md)
- [旧AIGC方針案](legacy-spec-v2/aigc-policy.md)

## 旧Specification Ver.2.0（事業・コンテンツ・デザイン）

- [用語定義](legacy-spec-v2-business/01-definitions.md)
- [事業要件](legacy-spec-v2-business/02-business-requirements.md)
- [コンテンツ基本方針](legacy-spec-v2-business/03-content-policy.md)
- [コアコンテンツ定義](legacy-spec-v2-business/04-core-content.md)
- [コンテンツパッケージ定義](legacy-spec-v2-business/05-content-packages.md)
- [コンテンツ運用フロー](legacy-spec-v2-business/06-content-operations.md)
- [UIUX基本原則](legacy-spec-v2-business/07-uiux-principles.md)
- [サイトマップとユーザーフロー](legacy-spec-v2-business/08-sitemap-user-flow.md)
- [レイアウトとブロック定義](legacy-spec-v2-business/09-layout-blocks.md)
- [コンポーネントとインタラクション設計](legacy-spec-v2-business/10-components-interaction.md)

これらにはFlutter、SQLite、旧DB構造、旧MVP、Google Play、Proプラン、端末TTSなど、現行実装と一致しない記述が含まれます。

## ワークフロー策定の記録

- [策定の記録](workflow-records/README.md) — 競合調査からMVP分岐までの作業記録
- [策定の実行計画書](workflow-records/00-execution-plan.md)

結論は [`docs/product/workflow.md`](../product/workflow.md) に出ています。作業記録の方は判断の材料として残しています。

## 終わった計画書

- [`docs/` 整理の計画](docs-restructure/plan.md) — なぜ棚を8つに分けたか
- [`docs/` 整理の手順](docs-restructure/execution.md) — 実際に行った作業（2026-08-27）

現在の棚の構成と置き場所のルールは [`docs/operations/repository-layout.md`](../operations/repository-layout.md) が正本です。

- [学習タブ ゲストファースト再構築の計画](learning-tab-guest-first/plan.md) — なぜログイン不要にしたか（2026-08-28完了）

学習コアの現行仕様は [`docs/architecture/anki-aligned-spec.md`](../architecture/anki-aligned-spec.md) が正本です。積み残した未決事項（U-1〜U-4）はこの計画書の9章にあります。

## 旧パス対応表

2026-08-27の整理より前のパスから来た場合は、次を参照してください。旧パスに置いていた移動案内ファイルは、この表に置き換えました。

| 旧パス | いまの場所 |
|---|---|
| `docs/Usalingo｜Specification Ver.2.0/wireframe_components.md` | [legacy-spec-v2/wireframe-components.md](legacy-spec-v2/wireframe-components.md) |
| `docs/Usalingo｜Specification Ver.2.0/類義語の動的DB索引方法.md` | [legacy-spec-v2/dynamic-synonym-index-research.md](legacy-spec-v2/dynamic-synonym-index-research.md) |
| `.../usalingo_01_business/usalingo_00_definitions.md` | [legacy-spec-v2-business/01-definitions.md](legacy-spec-v2-business/01-definitions.md) |
| `.../usalingo_01_business/usalingo_01_business_requirements.md` | [legacy-spec-v2-business/02-business-requirements.md](legacy-spec-v2-business/02-business-requirements.md) |
| `.../usalingo_02_content_requirements/usalingo_02_01｜コンテンツ基本方針.md` | [legacy-spec-v2-business/03-content-policy.md](legacy-spec-v2-business/03-content-policy.md) |
| `.../usalingo_02_02｜コアコンテンツ定義.md` | [legacy-spec-v2-business/04-core-content.md](legacy-spec-v2-business/04-core-content.md) |
| `.../usalingo_02_03｜コンテンツパッケージ定義.md` | [legacy-spec-v2-business/05-content-packages.md](legacy-spec-v2-business/05-content-packages.md) |
| `.../usalingo_02_04｜コンテンツ運用フロー.md` | [legacy-spec-v2-business/06-content-operations.md](legacy-spec-v2-business/06-content-operations.md) |
| `.../usalingo_03_01｜UIUX 基本原則.md` | [legacy-spec-v2-business/07-uiux-principles.md](legacy-spec-v2-business/07-uiux-principles.md) |
| `.../usalingo_03_02｜サイトマップ &ユーザーフロー.md` | [legacy-spec-v2-business/08-sitemap-user-flow.md](legacy-spec-v2-business/08-sitemap-user-flow.md) |
| `.../usalingo_03_03｜レイアウト & ブロック定義.md` | [legacy-spec-v2-business/09-layout-blocks.md](legacy-spec-v2-business/09-layout-blocks.md) |
| `.../usalingo_03_04｜コンポーネント & インタラクション設計.md` | [legacy-spec-v2-business/10-components-interaction.md](legacy-spec-v2-business/10-components-interaction.md) |
| `.../usalingo_04_01｜開発環境 & 技術スタック.md` | [`docs/operations/technology-stack.md`](../operations/technology-stack.md) |
| `.../usalingo_04_02｜ディレクトリツリー.md` | [`docs/operations/repository-layout.md`](../operations/repository-layout.md) |
| `.../usalingo_04_03｜データベース設計.md` | [legacy-spec-v2/database-design.md](legacy-spec-v2/database-design.md) |
| `.../usalingo_04_04｜アルゴリズム設計.md` | [legacy-spec-v2/algorithm-design.md](legacy-spec-v2/algorithm-design.md) |
| `.../usalingo_04_05｜ワークフロー設計.md` | [legacy-spec-v2/workflow-design.md](legacy-spec-v2/workflow-design.md)（現行の決定は [退会・復元・最終削除のデータ契約](../architecture/account-deletion-contract.md)） |
| `.../usalingo_04_06｜アセット管理設計.md` | [legacy-spec-v2/asset-management-design.md](legacy-spec-v2/asset-management-design.md) |
| `.../usalingo_05_aigc_policy.md` | [legacy-spec-v2/aigc-policy.md](legacy-spec-v2/aigc-policy.md)（法務・AIGCはUSL-249・USL-255の判断前に確定情報として使用しない） |
| `docs/Fo｜02｜Terms of Use/` | [`docs/legal/source/`](../legal/source/) |
| `docs/usalingo-simple-product-plan.md` | [`docs/product/plan.md`](../product/plan.md) |
| `docs/decisions/usalingo-core-workflow-requirements.md` | [`docs/product/workflow.md`](../product/workflow.md) |
| `docs/usalingo-workflow-planning-execution-plan.md` | [workflow-records/00-execution-plan.md](workflow-records/00-execution-plan.md) |
| `docs/workflow-records/` | [workflow-records/](workflow-records/) |
| `docs/development/` | [`docs/operations/`](../operations/) |
| `docs/rules/` | [`docs/operations/`](../operations/) |
| `docs/runbooks/` | [`docs/operations/runbooks/`](../operations/runbooks/) |
| `docs/supabase/local-development.md` | [`docs/operations/supabase-local-development.md`](../operations/supabase-local-development.md) |
| `docs/supabase/Usalingo 英単語原本データベース V5 設計書.md` | [`docs/content/source-database-v5.md`](../content/source-database-v5.md) |
| `docs/research/usl-249-legal-privacy-license-inventory.md` | [`docs/legal/asset-and-privacy-inventory.md`](../legal/asset-and-privacy-inventory.md) |
| `docs/release-quality-gate.md` | [`docs/operations/release-quality-gate.md`](../operations/release-quality-gate.md) |
| `docs/plans/docs-restructure-plan.md` | [docs-restructure/plan.md](docs-restructure/plan.md) |
| `docs/plans/docs-restructure-execution.md` | [docs-restructure/execution.md](docs-restructure/execution.md) |
| `docs/plans/learning-tab-guest-first-plan.md` | [learning-tab-guest-first/plan.md](learning-tab-guest-first/plan.md) |
