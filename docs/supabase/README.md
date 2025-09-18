## Supabase ドキュメント

このディレクトリは、Usalingo プロジェクトにおける Supabase 関連のドキュメントを集約します。

### 構成

```
docs/
└── supabase/
    ├── README.md                     # このファイル
    ├── storage_trigger_guide.md      # Storage トリガー設定ガイド
    └── sql/                          # SQL 資材
        ├── supabase_schema.sql       # メインデータベーススキーマ
        ├── supabase_storage_setup.sql# ストレージバケット設定
        └── storage_trigger_setup.sql # ストレージトリガー設定
```

### 主要ドキュメント

- **storage_trigger_guide.md**: Storageに画像をアップロードした際に、自動的にデータベースの`example_contents`テーブルの`illustration_url`カラムを更新する機能の設定方法

### 参照

- プロジェクト全体のドキュメント構成は `../README.md` を参照
- Supabase ドキュメントの配置・命名規約は `../rules/supabase-docs-rules.md` を参照


