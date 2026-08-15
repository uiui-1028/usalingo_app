# Usalingo documentation

現行アプリは `apps/ios-swiftui/` のSwiftUI版です。実装や判断では、次の順に参照します。

## 現行の正本

1. [Anki型学習コア仕様](architecture/anki-aligned-spec.md)
2. [Anki型データモデルと移行設計](architecture/anki-data-model.md)
3. [公式コンテンツのDB・Storage契約](architecture/official-content-contract.md)
4. [Supabase運用](supabase/README.md)
5. [`supabase/migrations/`](../supabase/migrations/) — 実行可能SQLの正本

実装は `apps/ios-swiftui/UsalingoIOS/`、テストは `apps/ios-swiftui/UsalingoIOSTests/` を確認します。

## 旧仕様資料

`Usalingo｜Specification Ver.2.0/` は、事業・コンテンツ・デザイン検討の履歴を含む資料です。Flutter、SQLite、旧DB構造、旧MVP範囲の記述も残っているため、現行の技術仕様としては使用しません。

## 開発ルール

- [ルール一覧](rules/README.md)
- [Codexクレジット消費 最適化ルール](rules/codex-credit-optimization.md)
- [Supabase SQL・migration運用](rules/SQL_Query_Rules.md)
