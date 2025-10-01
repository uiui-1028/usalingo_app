-- ===============================================
-- Usalingo データベーススキーマ インデックス作成
-- ===============================================
-- 目的: クエリのパフォーマンスを向上させるためのインデックスを作成する

-- word_meaningsテーブルのインデックス
CREATE INDEX IF NOT EXISTS idx_meanings_on_word_id 
ON public.word_meanings (word_id);

-- 例文コンテンツテーブルのインデックス
CREATE INDEX IF NOT EXISTS idx_examples_on_meaning_id 
ON public.example_contents (meaning_id);

-- デッキ単語中間テーブルのインデックス
CREATE INDEX IF NOT EXISTS idx_deck_words_on_deck_id 
ON public.deck_words (deck_id);

CREATE INDEX IF NOT EXISTS idx_deck_words_on_word_id 
ON public.deck_words (word_id);

-- インデックス作成完了の確認メッセージ
SELECT 'Indexes creation completed successfully. All performance indexes have been created.' as status;
