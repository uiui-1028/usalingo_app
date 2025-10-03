# 🗄️ Supabase ドキュメント

Usalingo プロジェクトにおける Supabase 関連のドキュメントを集約したディレクトリです。

## 📂 ディレクトリ構成

```
docs/supabase/
├── README.md                     # このファイル
├── archive/                      # アーカイブ
│   ├── completed-tasks/          # 完了済みタスク（01-07）
│   ├── migration-history/        # 移行履歴
│   └── やりたいこと/             # タスク管理（アーカイブ済み）
└── reference/                    # リファレンス
    ├── sql/                      # SQLファイル（統合済み）
    │   └── consolidated/         # 統合SQLファイル
    ├── execution-guides/         # 実行手順書
    ├── functions/                # Edge Functions
    └── types/                    # TypeScript型定義
```

## 🚀 クイックスタート

### 新規環境でのセットアップ
1. `reference/sql/consolidated/00_setup.sql` - データベース初期化
2. `reference/sql/consolidated/01_core_schema.sql` - コアスキーマ
3. `reference/sql/consolidated/02_features.sql` - 基本機能
4. `reference/sql/consolidated/03_performance.sql` - パフォーマンス最適化
5. `reference/sql/consolidated/04_storage.sql` - ストレージ機能
6. `reference/sql/consolidated/05_documentation.sql` - ドキュメント

### 既存環境での機能追加
1. `reference/execution-guides/` - 実行手順書を確認
2. 対象機能のSQLファイルを実行
3. 動作確認

## 📋 主要ドキュメント

### 🗄️ SQL リファレンス
- **統合SQLファイル**: `reference/sql/consolidated/`
  - 実行順序に従って統合されたSQLファイル
  - 6つのファイルで全機能をカバー

### 📚 実行手順書
- `reference/execution-guides/` - 各機能のデプロイ手順
- トラブルシューティングガイド

### 🔄 Edge Functions
- `reference/functions/` - アセットリンカー、移行スクリプト

### 📝 TypeScript型定義
- `reference/types/` - JSONB構造、データベーススキーマの型定義

## 📊 タスク管理

### 完了済みタスク（アーカイブ済み）
- ✅ 01: トリガー関数の実装修正
- ✅ 02: タイムスタンプカラムの追加
- ✅ 03: JSONBカラムの構造定義
- ✅ 04: 複合インデックスの追加
- ✅ 06: 全文検索インデックスの追加
- ✅ 07: ストレージ階層化の実装

### 現在の状況
- 📁 全タスク完了（2025年10月3日）
- 🗂️ ファイル整理完了（2025年10月3日）
- 📚 ドキュメント構造化完了
- 🔄 シンプル化完了（2025年10月3日）

## ⚠️ 重要な注意事項

### バックアップ
- **全てのSQL実行前に必ずデータベースのバックアップを取得**
- Supabaseダッシュボードから手動バックアップを作成

### テスト環境
- 可能な限り開発環境で先にテスト
- 本番環境への適用は慎重に

### ロールバック計画
- 各機能のロールバック手順を事前に準備
- 段階的な実装と動作確認

## 🔗 関連ドキュメント

- [プロジェクト全体のドキュメント構成](../README.md)
- [Supabase ドキュメント規則](../rules/supabase-docs-rules.md)
- [データベース設計書](../Usalingo｜Specification Ver.1.0/usalingo_04_technical_requirements/usalingo_04_03｜データベース設計.md)

---

**最終更新**: 2025年10月3日（シンプル化完了）  
**作成者**: Usalingo開発チーム