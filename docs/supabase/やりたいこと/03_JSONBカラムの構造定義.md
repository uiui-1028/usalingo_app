# タスク03: JSONBカラムの構造定義

## 📋 概要
**優先度:** 🔴 高優先度（すぐに対応すべき）

JSONBカラム（inflections, derivatives, collocations, related_phrases）の構造を明確に定義し、ドキュメント化する。

## 🎯 目的
- データ構造を明確にする
- バリデーションを可能にする
- クライアント側での型安全性を向上させる
- TypeScript型定義との整合性を確保する

## ❌ 現在の問題

```sql
-- 現在の設計（構造が不明確）
inflections JSONB,
derivatives JSONB,
collocations JSONB,
related_phrases JSONB
```

**影響:**
- データ構造が明確でない
- バリデーションが困難
- クライアント側での型安全性が低い

## ✅ 改善案

### 1. COMMENTによる構造定義

```sql
-- inflections（活用形）の構造定義
COMMENT ON COLUMN public.word_meanings.inflections IS 
'活用形情報。
形式: {
  "past": "went",
  "past_participle": "gone", 
  "present_participle": "going",
  "third_person": "goes"
}';

-- derivatives（派生語）の構造定義
COMMENT ON COLUMN public.word_meanings.derivatives IS 
'派生語情報。
形式: [
  {"word": "happiness", "pos": "noun", "definition": "幸福"},
  {"word": "happily", "pos": "adverb", "definition": "幸せに"}
]';

-- collocations（コロケーション）の構造定義
COMMENT ON COLUMN public.word_meanings.collocations IS 
'コロケーション（連語）情報。
形式: {
  "verb": ["make happy", "feel happy"],
  "adjective": ["very happy", "extremely happy"],
  "preposition": ["happy with", "happy about"]
}';

-- related_phrases（関連フレーズ）の構造定義
COMMENT ON COLUMN public.word_meanings.related_phrases IS 
'関連フレーズ・慣用句情報。
形式: [
  {"phrase": "happy as a clam", "meaning": "とても幸せ"},
  {"phrase": "happy ending", "meaning": "ハッピーエンド"}
]';
```

### 2. TypeScript型定義の作成

```typescript
// types/database.ts

// 活用形
export interface Inflections {
  past?: string;
  past_participle?: string;
  present_participle?: string;
  third_person?: string;
  plural?: string;
}

// 派生語
export interface Derivative {
  word: string;
  pos: string;
  definition: string;
}

// コロケーション
export interface Collocations {
  verb?: string[];
  adjective?: string[];
  preposition?: string[];
  noun?: string[];
}

// 関連フレーズ
export interface RelatedPhrase {
  phrase: string;
  meaning: string;
}

// word_meaningsテーブルの型
export interface WordMeaning {
  id: number;
  word_id: number;
  priority: number;
  part_of_speech_en: string;
  part_of_speech_jp?: string;
  definition_jp: string;
  cefr_level?: string;
  etymology?: string;
  synonyms?: string[];
  antonyms?: string[];
  pronunciation_ipa?: string;
  pronunciation_kana?: string;
  pronunciation_cmu?: string;
  audio_url?: string;
  audio_asset_path?: string;
  inflections?: Inflections;
  derivatives?: Derivative[];
  collocations?: Collocations;
  related_phrases?: RelatedPhrase[];
  created_at: string;
  updated_at: string;
}
```

### 3. バリデーション関数の作成（オプション）

```sql
-- inflectionsのバリデーション関数
CREATE OR REPLACE FUNCTION validate_inflections(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    IF data IS NULL THEN
        RETURN TRUE;
    END IF;
    
    RETURN (
        jsonb_typeof(data) = 'object' AND
        (data ? 'past' OR data ? 'past_participle' OR 
         data ? 'present_participle' OR data ? 'third_person' OR 
         data ? 'plural')
    );
END;
$$ LANGUAGE plpgsql;

-- derivativesのバリデーション関数
CREATE OR REPLACE FUNCTION validate_derivatives(data JSONB)
RETURNS BOOLEAN AS $$
DECLARE
    item JSONB;
BEGIN
    IF data IS NULL THEN
        RETURN TRUE;
    END IF;
    
    IF jsonb_typeof(data) != 'array' THEN
        RETURN FALSE;
    END IF;
    
    FOR item IN SELECT * FROM jsonb_array_elements(data)
    LOOP
        IF NOT (item ? 'word' AND item ? 'pos') THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- CHECK制約の追加（オプション）
ALTER TABLE word_meanings 
ADD CONSTRAINT check_inflections_structure 
CHECK (validate_inflections(inflections));

ALTER TABLE word_meanings 
ADD CONSTRAINT check_derivatives_structure 
CHECK (validate_derivatives(derivatives));
```

## 📝 実装手順

### 1. SQL COMMENTの追加
- [ ] `07_jsonb_documentation.sql`を作成
- [ ] 各JSONBカラムにCOMMENTを追加
- [ ] 構造の詳細な説明を記載

### 2. TypeScript型定義の作成
- [ ] `lib/types/database.ts`を作成または更新
- [ ] JSONBカラムの型定義を追加
- [ ] Supabase型生成ツールとの整合性を確認

### 3. バリデーション関数の実装（オプション）
- [ ] バリデーション関数を作成
- [ ] CHECK制約を追加
- [ ] テストデータで動作確認

### 4. ドキュメントの更新
- [ ] 要件定義書にJSONB構造を記載
- [ ] サンプルデータを追加

## ✅ 完了条件
- [ ] 全てのJSONBカラムにCOMMENTが追加されている
- [ ] TypeScript型定義が作成されている
- [ ] バリデーション関数が実装されている（オプション）
- [ ] ドキュメントが更新されている

## 📊 期待される効果
- ✅ データ構造の明確化
- ✅ 型安全性の向上
- ✅ バリデーションの自動化
- ✅ 開発効率の向上
- ✅ バグの早期発見

## 📚 JSONBデータ構造の詳細

### inflections（活用形）
```json
{
  "past": "went",
  "past_participle": "gone",
  "present_participle": "going",
  "third_person": "goes",
  "plural": "goes"
}
```

### derivatives（派生語）
```json
[
  {"word": "happiness", "pos": "noun", "definition": "幸福"},
  {"word": "happily", "pos": "adverb", "definition": "幸せに"},
  {"word": "unhappy", "pos": "adjective", "definition": "不幸な"}
]
```

### collocations（コロケーション）
```json
{
  "verb": ["make happy", "feel happy", "look happy"],
  "adjective": ["very happy", "extremely happy"],
  "preposition": ["happy with", "happy about"],
  "noun": ["happy moment", "happy face"]
}
```

### related_phrases（関連フレーズ）
```json
[
  {"phrase": "happy as a clam", "meaning": "とても幸せ"},
  {"phrase": "happy ending", "meaning": "ハッピーエンド"},
  {"phrase": "happy hour", "meaning": "ハッピーアワー（割引時間）"}
]
```

## 🔗 関連ファイル
- `/docs/supabase/sql/07_jsonb_documentation.sql`（新規作成）
- `/lib/types/database.ts`（新規作成または更新）
- `/docs/Usalingo｜Specification Ver.1.0/usalingo_04_technical_requirements/usalingo_04_03｜データベース設計.md`
