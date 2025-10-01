-- =============================================
-- JSONBカラムの構造定義とドキュメント化
-- =============================================
-- 作成日: 2025-01-30
-- 目的: JSONBカラムの構造を明確化し、型安全性とデータ整合性を向上
-- 参考: usalingo_02_02｜コアコンテンツ定義.md

-- =============================================
-- 1. inflections (活用形) カラムの構造定義
-- =============================================

-- word_meanings.inflections カラム
COMMENT ON COLUMN word_meanings.inflections IS 
'動詞の活用形を格納するJSONBカラム。
構造: {
  "past": "過去形 (例: "did")",
  "past_participle": "過去分詞 (例: "done")", 
  "present_participle": "現在分詞 (例: "doing")",
  "third_person": "三人称単数現在 (例: "does")",
  "plural": "複数形 (名詞の場合, 例: "boxes")",
  "comparative": "比較級 (形容詞の場合, 例: "bigger")",
  "superlative": "最上級 (形容詞の場合, 例: "biggest")"
}
各キーは品詞に応じて適切なものを設定する。';

-- =============================================
-- 2. derivatives (派生語) カラムの構造定義
-- =============================================

-- word_meanings.derivatives カラム
COMMENT ON COLUMN word_meanings.derivatives IS 
'関連する派生語を格納するJSONBカラム。
構造: [
  {
    "word": "派生語の文字列 (例: "responsible")",
    "part_of_speech_jp": "品詞（日本語） (例: "形容詞")",
    "part_of_speech_en": "品詞（英語） (例: "adjective")",
    "definition": "簡単な意味 (例: "責任のある")"
  }
]
配列形式で複数の派生語を格納可能。';

-- =============================================
-- 3. collocations (コロケーション) カラムの構造定義
-- =============================================

-- word_meanings.collocations カラム
COMMENT ON COLUMN word_meanings.collocations IS 
'自然な単語の組み合わせ（コロケーション）を格納するJSONBカラム。
構造: [
  {
    "category_jp": "日本語のカテゴリ名 (例: "動詞 + 名詞")",
    "category_en": "英語のカテゴリ名 (例: "verb + noun")",
    "items": [
      {
        "phrase": "コロケーションのフレーズ (例: "take responsibility")",
        "translation": "フレーズの日本語訳 (例: "責任を負う")"
      }
    ]
  }
]
カテゴリ別に整理され、各カテゴリ内に複数のコロケーションを格納。';

-- =============================================
-- 4. related_phrases (フレーズ/慣用句) カラムの構造定義
-- =============================================

-- word_meanings.related_phrases カラム
COMMENT ON COLUMN word_meanings.related_phrases IS 
'定型句や慣用句（イディオム）を格納するJSONBカラム。
構造: [
  {
    "phrase": "フレーズ/慣用句そのもの (例: "take advantage of ~")",
    "translation": "フレーズの日本語訳 (例: "〜をうまく利用する")"
  }
]
配列形式で複数のフレーズを格納可能。コロケーションとは異なり、
それ自体で意味をなす決まった言い回しを扱う。';

-- =============================================
-- 5. tts_config (TTS設定) カラムの構造定義
-- =============================================

-- user_settings.tts_config カラム
COMMENT ON COLUMN user_settings.tts_config IS 
'テキスト読み上げ（TTS）の設定を格納するJSONBカラム。
構造: {
  "enabled": "TTS機能の有効/無効 (boolean)",
  "voice_speed": "読み上げ速度 (number, 0.5-2.0)",
  "voice_pitch": "声の高さ (number, 0.5-2.0)",
  "auto_play": "自動再生の有無 (boolean)",
  "language": "読み上げ言語 (string, "en" | "ja")",
  "voice_id": "使用する音声ID (string)"
}
デフォルト値: {"enabled": true, "voice_speed": 1.0, "voice_pitch": 1.0, "auto_play": false, "language": "en"}';

-- =============================================
-- 6. settings (ウィジェット設定) カラムの構造定義
-- =============================================

-- user_widget_layouts.settings カラム
COMMENT ON COLUMN user_widget_layouts.settings IS 
'ウィジェット固有の設定を格納するJSONBカラム。
構造: {
  "widget_type": "ウィジェットタイプ固有の設定",
  "display_options": {
    "show_title": "タイトル表示の有無 (boolean)",
    "show_description": "説明表示の有無 (boolean)",
    "card_count": "表示するカード数 (number)",
    "auto_refresh": "自動更新の有無 (boolean)"
  },
  "interaction_settings": {
    "click_action": "クリック時の動作 (string)",
    "hover_effect": "ホバーエフェクトの有無 (boolean)"
  }
}
ウィジェットタイプに応じて柔軟な設定を格納可能。';

-- =============================================
-- 7. JSONBバリデーション関数の作成
-- =============================================

-- inflections構造のバリデーション関数
CREATE OR REPLACE FUNCTION validate_inflections_structure(inflections_data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- NULLチェック
    IF inflections_data IS NULL THEN
        RETURN TRUE; -- NULLは許可
    END IF;
    
    -- オブジェクト型チェック
    IF jsonb_typeof(inflections_data) != 'object' THEN
        RETURN FALSE;
    END IF;
    
    -- 有効なキーのチェック
    DECLARE
        valid_keys TEXT[] := ARRAY['past', 'past_participle', 'present_participle', 'third_person', 'plural', 'comparative', 'superlative'];
        key TEXT;
    BEGIN
        FOR key IN SELECT jsonb_object_keys(inflections_data)
        LOOP
            IF NOT (key = ANY(valid_keys)) THEN
                RETURN FALSE;
            END IF;
            
            -- 値が文字列かチェック
            IF jsonb_typeof(inflections_data->key) != 'string' THEN
                RETURN FALSE;
            END IF;
        END LOOP;
    END;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- derivatives構造のバリデーション関数
CREATE OR REPLACE FUNCTION validate_derivatives_structure(derivatives_data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- NULLチェック
    IF derivatives_data IS NULL THEN
        RETURN TRUE; -- NULLは許可
    END IF;
    
    -- 配列型チェック
    IF jsonb_typeof(derivatives_data) != 'array' THEN
        RETURN FALSE;
    END IF;
    
    -- 各要素の構造チェック
    DECLARE
        element JSONB;
        required_keys TEXT[] := ARRAY['word', 'part_of_speech_jp', 'part_of_speech_en', 'definition'];
        key TEXT;
    BEGIN
        FOR element IN SELECT jsonb_array_elements(derivatives_data)
        LOOP
            -- オブジェクト型チェック
            IF jsonb_typeof(element) != 'object' THEN
                RETURN FALSE;
            END IF;
            
            -- 必須キーのチェック
            FOREACH key IN ARRAY required_keys
            LOOP
                IF NOT (element ? key) THEN
                    RETURN FALSE;
                END IF;
                
                -- 値が文字列かチェック
                IF jsonb_typeof(element->key) != 'string' THEN
                    RETURN FALSE;
                END IF;
            END LOOP;
        END LOOP;
    END;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- collocations構造のバリデーション関数
CREATE OR REPLACE FUNCTION validate_collocations_structure(collocations_data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- NULLチェック
    IF collocations_data IS NULL THEN
        RETURN TRUE; -- NULLは許可
    END IF;
    
    -- 配列型チェック
    IF jsonb_typeof(collocations_data) != 'array' THEN
        RETURN FALSE;
    END IF;
    
    -- 各要素の構造チェック
    DECLARE
        element JSONB;
        required_keys TEXT[] := ARRAY['category_jp', 'category_en', 'items'];
        key TEXT;
    BEGIN
        FOR element IN SELECT jsonb_array_elements(collocations_data)
        LOOP
            -- オブジェクト型チェック
            IF jsonb_typeof(element) != 'object' THEN
                RETURN FALSE;
            END IF;
            
            -- 必須キーのチェック
            FOREACH key IN ARRAY required_keys
            LOOP
                IF NOT (element ? key) THEN
                    RETURN FALSE;
                END IF;
                
                -- category_jp, category_enは文字列
                IF key IN ('category_jp', 'category_en') THEN
                    IF jsonb_typeof(element->key) != 'string' THEN
                        RETURN FALSE;
                    END IF;
                -- itemsは配列
                ELSIF key = 'items' THEN
                    IF jsonb_typeof(element->key) != 'array' THEN
                        RETURN FALSE;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
    END;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- related_phrases構造のバリデーション関数
CREATE OR REPLACE FUNCTION validate_related_phrases_structure(phrases_data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- NULLチェック
    IF phrases_data IS NULL THEN
        RETURN TRUE; -- NULLは許可
    END IF;
    
    -- 配列型チェック
    IF jsonb_typeof(phrases_data) != 'array' THEN
        RETURN FALSE;
    END IF;
    
    -- 各要素の構造チェック
    DECLARE
        element JSONB;
        required_keys TEXT[] := ARRAY['phrase', 'translation'];
        key TEXT;
    BEGIN
        FOR element IN SELECT jsonb_array_elements(phrases_data)
        LOOP
            -- オブジェクト型チェック
            IF jsonb_typeof(element) != 'object' THEN
                RETURN FALSE;
            END IF;
            
            -- 必須キーのチェック
            FOREACH key IN ARRAY required_keys
            LOOP
                IF NOT (element ? key) THEN
                    RETURN FALSE;
                END IF;
                
                -- 値が文字列かチェック
                IF jsonb_typeof(element->key) != 'string' THEN
                    RETURN FALSE;
                END IF;
            END LOOP;
        END LOOP;
    END;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 8. バリデーション関数のコメント
-- =============================================

COMMENT ON FUNCTION validate_inflections_structure(JSONB) IS 
'inflections JSONBカラムの構造を検証する関数。有効な活用形キーと文字列値のみを許可する。';

COMMENT ON FUNCTION validate_derivatives_structure(JSONB) IS 
'derivatives JSONBカラムの構造を検証する関数。派生語配列の各要素が必須キーを持つことを確認する。';

COMMENT ON FUNCTION validate_collocations_structure(JSONB) IS 
'collocations JSONBカラムの構造を検証する関数。カテゴリとアイテムの階層構造を確認する。';

COMMENT ON FUNCTION validate_related_phrases_structure(JSONB) IS 
'related_phrases JSONBカラムの構造を検証する関数。フレーズと翻訳のペア構造を確認する。';

-- =============================================
-- 9. サンプルデータの挿入（テスト用）
-- =============================================

-- サンプルデータの挿入（実際のデータがある場合はスキップ）
-- 注意: 実際の運用では、このセクションは削除またはコメントアウトしてください

/*
-- inflections のサンプル
UPDATE word_meanings 
SET inflections = '{"past": "ran", "past_participle": "run", "present_participle": "running", "third_person": "runs"}'
WHERE id = 1 AND inflections IS NULL;

-- derivatives のサンプル  
UPDATE word_meanings
SET derivatives = '[{"word": "runner", "part_of_speech_jp": "名詞", "part_of_speech_en": "noun", "definition": "走る人"}]'
WHERE id = 1 AND derivatives IS NULL;

-- collocations のサンプル
UPDATE word_meanings
SET collocations = '[{"category_jp": "動詞 + 名詞", "category_en": "verb + noun", "items": [{"phrase": "run a business", "translation": "ビジネスを経営する"}]}]'
WHERE id = 1 AND collocations IS NULL;

-- related_phrases のサンプル
UPDATE word_meanings
SET related_phrases = '[{"phrase": "run out of", "translation": "〜を使い果たす"}]'
WHERE id = 1 AND related_phrases IS NULL;
*/

-- =============================================
-- 完了メッセージ
-- =============================================
SELECT 'JSONBカラムの構造定義とバリデーション関数の設定が完了しました。' as status;
