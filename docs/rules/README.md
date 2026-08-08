# Usalingo プロジェクト - ルールブック

## 概要
このフォルダには、Usalingo英語学習アプリの開発に関するルールブックが格納されています。

## ファイル構成

### 📁 docs/rules/
- **README.md** - このファイル（ルールブックの概要）
- **cursor-rules.md** - Cursor AI Editor用のルール
- **claude-rules.md** - Claude用のルール
- **common-rules.md** - 共通ルール（重複部分）
- **SQL_Query_Rules.md** - SQLとSupabase関連ファイルの管理ルール

## 使用方法

### Cursor AI Editor
- `docs/rules/cursor-rules.md`をCursorの設定で参照
- プロジェクト固有の開発ルールが適用されます

### Claude
- `docs/rules/claude-rules.md`をClaudeの設定で参照
- プロジェクト固有の開発ルールが適用されます

## ルールの更新
- 共通ルールの変更は`common-rules.md`で行う
- ツール固有のルールは各ファイルで管理
- 更新後は両方のツールで動作確認を行う

## 注意事項
- ルールの変更は慎重に行い、既存の開発フローに影響がないか確認する
- 新しいルール追加時は、適切なファイルに配置する
- 定期的にルールの有効性を評価し、必要に応じて更新する
