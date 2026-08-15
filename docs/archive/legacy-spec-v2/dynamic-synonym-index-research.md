> [!WARNING]
> これは未採用のDB索引案をまとめた履歴・検討資料です。現行仕様として使用しません。現行資料の入口は [`docs/README.md`](../../README.md)、実行可能DB変更の正本は [`supabase/migrations/`](../../../supabase/migrations/) です。将来のresearchで比較材料として再利用できるよう本文を残しています。

# 類義語の動的DB索引方法 - 施策検討レポート

**作成日**: 2025年10月06日
**最終更新**: 2025年10月06日
**対象**: Usalingo アプリケーション
**目的**: 静的な事前定義に依存しない動的な類義語関連付けシステムの実装検討
**ステータス**: 設計完了、実装準備中

---

## 1. 概要

### 1.1 背景
現在の`word_meanings`テーブルには`synonyms`カラム（TEXT[]）が定義されているが、これは静的な事前定義に依存している。ユーザーの学習行動や文脈に基づいた動的な類義語関連付けシステムの実装が求められている。

### 1.2 目的
- 静的な事前定義以外の動的な類義語関連付け方法の検討
- 実装可能性とコストの分析
- 最適な実装戦略の提案
- アプリ側での実用的な利用を考慮した軽量なデータ設計

### 1.3 確定した設計方針
- **軽量ID形式**: `synonyms`カラムは`INT[]`形式でmeaning_idのみを保存
- **アプリ側統合**: 関連レコードの一括ダウンロードとカード遷移機能
- **実用性重視**: 情報コストを最小限に抑えた効率的な設計
- **拡張性**: 将来的な機能追加に対応できる柔軟な構造

---

## 2. 動的類義語関連付けの提案方法

### 2.1 【提案1】意味ベース類似度による動的関連付け

**コンセプト**: 単語の意味（`definition_jp`）の類似度を計算し、閾値を超えるものを類義語として動的に関連付け

**実装方法**:
```sql
-- 意味の類似度を計算する関数
CREATE OR REPLACE FUNCTION calculate_meaning_similarity(
    target_meaning_id INT,
    candidate_meaning_id INT
) RETURNS REAL AS $$
DECLARE
    target_definition TEXT;
    candidate_definition TEXT;
    similarity_score REAL;
BEGIN
    SELECT definition_jp INTO target_definition
    FROM word_meanings WHERE id = target_meaning_id;

    SELECT definition_jp INTO candidate_definition
    FROM word_meanings WHERE id = candidate_meaning_id;

    similarity_score := similarity(target_definition, candidate_definition);
    RETURN similarity_score;
END;
$$ LANGUAGE plpgsql;
```

**メリット**:
- 実装が比較的簡単
- PostgreSQLの`pg_trgm`拡張を活用
- 既存の`definition_jp`カラムを活用

**デメリット**:
- 日本語の意味文の類似度計算精度に限界
- 計算コストが高い（全単語との比較が必要）
- 文脈の違いを捉えにくい

### 2.2 【提案2】学習行動ベースの動的関連付け

**コンセプト**: ユーザーの学習行動（間違いやすい単語の組み合わせ）から類義語関係を動的に発見

**実装方法**:
```sql
-- 学習行動から類義語を発見するテーブル
CREATE TABLE IF NOT EXISTS learning_patterns (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    confused_word_pair JSONB,
    confusion_frequency INT DEFAULT 1,
    last_confused_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);
```

**メリット**:
- 実際のユーザー行動に基づく実用的な関連付け
- 個人化された類義語関係を構築可能
- 学習効果の向上に直結

**デメリット**:
- 十分な学習データが必要
- コールドスタート問題（初期データ不足）
- プライバシー配慮が必要

### 2.3 【提案3】文脈ベースの動的関連付け

**コンセプト**: 例文（`example_contents`）の文脈から、同じ文脈で使われる単語を類義語として関連付け

**メリット**:
- 実際の使用文脈を考慮
- テーマ別の類義語関係を発見
- 既存の`example_contents`テーブルを活用

**デメリット**:
- 例文データの品質に依存
- 計算コストが高い
- 文脈の解釈精度に限界

### 2.4 【提案4】階層的クラスタリングによる動的関連付け

**コンセプト**: 単語の特徴（意味、品詞、CEFRレベル等）を多次元ベクトルとして扱い、クラスタリングで類義語グループを動的に生成

**メリット**:
- 高精度な類似度計算
- 多次元の特徴を統合考慮
- スケーラブル

**デメリット**:
- 実装が複雑
- ベクトル生成の前処理が必要
- 計算リソースを大量消費

### 2.5 【提案5】ハイブリッド動的関連付けシステム

**コンセプト**: 上記の複数手法を組み合わせ、重み付けスコアで総合的な類義語関係を動的に決定

**メリット**:
- 複数手法の長所を組み合わせ
- 柔軟な重み付け調整
- 精度と実用性のバランス

**デメリット**:
- システムが複雑
- メンテナンスコストが高い
- パラメータ調整が必要

---

## 3. 実装可能性とコスト分析

### 3.1 M2チップ（16GB RAM）での実現可能性

**結論**: ✅ **完全に実装可能**

#### 3.1.1 計算コスト分析（10,000単語）
- **総比較回数**: 10,000 × 9,999 ÷ 2 = 約5,000万回
- **各比較の処理時間**: 約0.1-1ms（pg_trgm最適化後）
- **総計算時間**: 1.4-14時間（最適化の程度による）

#### 3.1.2 メモリ使用量
- **基本メモリ**: 約2-4GB（PostgreSQL + データ）
- **計算用メモリ**: 約4-8GB（類似度計算バッファ）
- **総使用量**: 6-12GB（16GB RAM内で十分）

### 3.2 コスト比較

#### 3.2.1 Supabase vs オープンソースPostgreSQL

| 項目 | Supabase | オープンソースPostgreSQL |
|------|----------|-------------------------|
| **データベース料金** | $25-500/月 | **$0** |
| **Edge Functions料金** | $2-20/月 | **$0** |
| **ストレージ料金** | $0.021/GB/月 | **$0** |
| **帯域幅料金** | $0.09/GB | **$0** |
| **計算リソース制限** | あり（メモリ512MB-1GB） | **制限なし** |
| **実行時間制限** | あり（Edge Functions: 60秒） | **制限なし** |
| **月額総コスト** | **$30-520** | **$0** |
| **年間コスト** | **$360-6,240** | **$0** |

#### 3.2.2 コスト削減効果
- **削減率**: 100%削減
- **年間削減額**: $360-6,240
- **追加メリット**: リソース制限なし、M2チップの全性能活用

---

## 4. 推奨実装戦略

### 4.1 段階的導入アプローチ

#### Phase 1: 軽量ID形式による動的関連付け（即座に実装可能）
```sql
-- 軽量ID形式でsynonymsカラムを動的に更新する関数
CREATE OR REPLACE FUNCTION update_dynamic_synonyms_lightweight(
    target_meaning_id INT,
    similarity_threshold REAL DEFAULT 0.3,
    max_synonyms INT DEFAULT 5
) RETURNS VOID AS $$
DECLARE
    synonym_meaning_ids INT[];
BEGIN
    -- 類似度が高い類義語のmeaning_idを取得
    SELECT ARRAY_AGG(ds.meaning_id ORDER BY ds.similarity_score DESC)
    INTO synonym_meaning_ids
    FROM find_dynamic_synonyms_by_meaning(target_meaning_id, similarity_threshold) ds
    LIMIT max_synonyms;

    -- 軽量な配列形式で更新
    UPDATE word_meanings
    SET synonyms = synonym_meaning_ids
    WHERE id = target_meaning_id;
END;
$$ LANGUAGE plpgsql;
```

#### Phase 2: 学習行動ベース（データ蓄積後）
学習データが蓄積された段階で、ユーザー行動パターンから類義語を発見

#### Phase 3: ハイブリッドシステム（最終形）
複数手法を組み合わせた高精度な動的類義語システム

### 4.2 最適化戦略

#### 4.2.1 バッチ処理による最適化
```sql
-- 1000単語ずつバッチ処理
CREATE OR REPLACE FUNCTION calculate_synonyms_batch(
    batch_size INT DEFAULT 1000,
    similarity_threshold REAL DEFAULT 0.3
) RETURNS VOID AS $$
DECLARE
    total_words INT;
    current_offset INT := 0;
    batch_count INT;
BEGIN
    SELECT COUNT(*) INTO total_words FROM words;
    batch_count := CEIL(total_words::REAL / batch_size);

    FOR i IN 1..batch_count LOOP
        PERFORM calculate_batch_similarity(current_offset, batch_size, similarity_threshold);
        current_offset := current_offset + batch_size;
        RAISE NOTICE 'Processed batch % of %', i, batch_count;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

#### 4.2.2 インデックス最適化
```sql
-- GINインデックスで類似度検索を高速化
CREATE INDEX CONCURRENTLY idx_word_meanings_definition_gin
ON word_meanings USING gin(definition_jp gin_trgm_ops);

-- カバリングインデックスでJOINを最適化
CREATE INDEX CONCURRENTLY idx_word_meanings_covering_synonyms
ON word_meanings (id) INCLUDE (word_id, definition_jp, synonyms);
```

#### 4.2.3 並列処理
```sql
-- PostgreSQL並列クエリを活用
SET max_parallel_workers_per_gather = 4;
SET parallel_tuple_cost = 0.1;
SET parallel_setup_cost = 0.1;
```

### 4.3 オープンソースPostgreSQL環境構築

#### 4.3.1 インストール手順
```bash
# HomebrewでPostgreSQLをインストール
brew install postgresql@15

# PostgreSQLサービス開始
brew services start postgresql@15

# pg_trgm拡張をインストール
brew install postgresql@15 --with-pg-trgm
```

#### 4.3.2 最適化設定
```sql
-- M2チップ（16GB RAM）向けの設定
shared_buffers = 4GB                    # RAMの25%
effective_cache_size = 12GB             # RAMの75%
work_mem = 256MB                        # 並列処理用
maintenance_work_mem = 1GB              # インデックス作成用
max_worker_processes = 8                # M2のコア数
max_parallel_workers_per_gather = 4      # 並列クエリ用
max_parallel_workers = 8                # 最大並列ワーカー数
random_page_cost = 1.1                  # SSD最適化
effective_io_concurrency = 200          # SSD並列I/O
```

---

## 5. 実装計画

### 5.1 Phase 1: 小規模テスト（100-500単語）
- テスト用の軽量版関数の実装
- パフォーマンス測定
- 最適化パラメータの調整

### 5.2 Phase 2: 本格実装（最適化版）
- バッチ処理 + 並列処理 + インデックス活用
- 進捗監視機能の実装
- エラーハンドリングの追加

### 5.3 Phase 3: 運用・監視
- 処理進捗の監視
- エラー処理の実装
- パフォーマンスチューニング

---

## 6. 結論と推奨事項

### 6.1 結論
1. **実現可能性**: M2チップ（16GB RAM）での実装は完全に可能
2. **コスト削減**: オープンソースPostgreSQLにより年間$360-6,240のコスト削減
3. **パフォーマンス**: 並列処理により大幅な処理時間短縮が期待できる

### 6.2 推奨事項
1. **段階的導入**: 意味ベース類似度から開始し、データ蓄積に応じて機能拡張
2. **オープンソース採用**: SupabaseではなくオープンソースPostgreSQLを推奨
3. **小規模テスト**: 100-500単語でのテストから開始
4. **最適化重視**: バッチ処理、並列処理、インデックス最適化を必須実装

### 6.3 次のステップ
1. ローカルPostgreSQL環境の構築
2. 小規模テストの実装と実行
3. パフォーマンス測定と最適化
4. 段階的なスケールアップ（1000→5000→10000単語）

---

## 7. 軽量ID形式の具体的実装例

### 7.1 データ構造例

#### **基本的な配列形式**
```sql
-- word_meaningsテーブルのsynonymsカラム例
-- word_id: 123 (単語: "happy")
-- meaning_id: 456 (意味: "幸せな")

synonyms: [789, 234, 567, 890]
```

**説明:**
- `789`: word_meanings.id = 789 (word_id: 124, 意味: "joyful", "喜びに満ちた")
- `234`: word_meanings.id = 234 (word_id: 125, 意味: "cheerful", "陽気な")
- `567`: word_meanings.id = 567 (word_id: 126, 意味: "glad", "嬉しい")
- `890`: word_meanings.id = 890 (word_id: 127, 意味: "pleased", "満足した")

#### **実際のテーブルデータ例**
```sql
-- wordsテーブル
| id  | word_text |
|-----|-----------|
| 123 | happy     |
| 124 | joyful    |
| 125 | cheerful  |
| 126 | glad      |
| 127 | pleased   |

-- word_meaningsテーブル
| id  | word_id | priority | definition_jp | synonyms      |
|-----|---------|----------|---------------|---------------|
| 456 | 123     | 1        | 幸せな        | [789,234,567,890] |
| 789 | 124     | 1        | 喜びに満ちた  | [456,234,567]     |
| 234 | 125     | 1        | 陽気な        | [456,789,567]     |
| 567 | 126     | 1        | 嬉しい        | [456,789,234,890] |
| 890 | 127     | 1        | 満足した      | [456,567]         |
```

### 7.2 アプリ側での統合設計

#### **関連レコード一括ダウンロード機能**
```sql
-- 特定の単語リストに関連する類義語も含めて一括取得
CREATE OR REPLACE FUNCTION get_words_with_synonyms(
    target_word_ids INT[],
    user_id UUID DEFAULT NULL
) RETURNS TABLE (
    word_id INT,
    word_text TEXT,
    meaning_id INT,
    definition_jp TEXT,
    part_of_speech_en TEXT,
    synonyms_data JSONB,
    example_contents JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        w.id as word_id,
        w.word_text,
        wm.id as meaning_id,
        wm.definition_jp,
        wm.part_of_speech_en,
        -- 関連する類義語の情報を取得
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'meaning_id', swm.id,
                    'word_id', sw.id,
                    'word_text', sw.word_text,
                    'definition_jp', swm.definition_jp,
                    'part_of_speech_en', swm.part_of_speech_en
                )
            )
            FROM unnest(wm.synonyms) as synonym_meaning_id
            JOIN word_meanings swm ON swm.id = synonym_meaning_id
            JOIN words sw ON sw.id = swm.word_id
        ) as synonyms_data,
        -- 例文情報も取得
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', ec.id,
                    'theme', ec.theme,
                    'sentence_en', ec.sentence_en,
                    'sentence_jp', ec.sentence_jp
                )
            )
            FROM example_contents ec
            WHERE ec.meaning_id = wm.id
        ) as example_contents
    FROM words w
    JOIN word_meanings wm ON wm.word_id = w.id
    WHERE w.id = ANY(target_word_ids);
END;
$$ LANGUAGE plpgsql;
```

### 7.3 メリット比較

| 項目 | 詳細JSONB形式 | 軽量ID形式（採用） |
|------|---------------|-------------------|
| **ストレージ効率** | ❌ 重い（冗長データ） | ✅ 軽量（IDのみ） |
| **ネットワーク転送** | ❌ 大量データ | ✅ 最小限データ |
| **アプリ側利用性** | ❌ 断片的表示のみ | ✅ 完全なカード遷移 |
| **データ整合性** | ⚠️ 重複リスク | ✅ DB参照で整合性保証 |
| **更新効率** | ❌ 複雑な更新 | ✅ シンプルな配列操作 |
| **拡張性** | ⚠️ スキーマ変更困難 | ✅ 柔軟な機能追加 |
| **実装複雑度** | ❌ 複雑 | ✅ シンプル |
| **メンテナンス性** | ❌ 困難 | ✅ 容易 |

---

**レポート作成者**: AI Assistant
**最終更新**: 2025年1月27日
**ステータス**: 設計完了、実装準備中
