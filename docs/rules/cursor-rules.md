---
alwaysApply: true
---

# Cursor AI Editor ルール - Usalingoプロジェクト

## 概要

Cursorが自動で読むルールは `.cursor/rules/usalingo-baseline.mdc` に置く。この文書は人間向けの説明として使う。

## 共通ルールの参照
以下を必ず適用する。

- `AGENTS.md`
- `docs/rules/codex-credit-optimization.md`
- `.agents/skills/usalingo-project-manager/SKILL.md`
- `.agents/skills/usalingo-next-ticket/SKILL.md`

## Cursor固有のルール

### コード生成時の注意事項
- 既存のコードスタイルと一貫性を保つ
- 適切なインデントとフォーマットを維持
- 必要に応じてコメントを追加
- エラーハンドリングを適切に実装

### ファイル操作時の注意事項
- 既存ファイルの変更前に内容を確認
- バックアップを作成してから重要な変更を行う
- ファイルパスは正確に指定する
- 権限エラーが発生した場合は適切に対処

### プロジェクト固有の制約

- 現行アプリは `apps/ios-swiftui/` のSwiftUI版を基準にする
- 古いFlutter版は、ユーザーが明示した場合だけ対象にする
- 既存の未コミット変更をユーザーの作業として保護する
- Notionのチケット取得では `worker_id`、`lease_until`、`work_branch` を使い、他AIとの重複作業を避ける
- 秘密鍵やアクセストークンを設定ファイルへ直書きしない

## 出力形式
- Always do the output in 日本語
- 技術的な説明は分かりやすく
- エラーや警告は適切に報告
- 進捗状況を定期的に更新

## 品質基準
- 生成されたコードはlintエラーがないこと
- 既存のアーキテクチャパターンに従う
- パフォーマンスを考慮した実装
- セキュリティベストプラクティスを遵守
