-- ===============================================
-- Usalingo データベーススキーマ RLSポリシー設定
-- ===============================================
-- 目的: テーブルへのアクセスを制御するRow Level Security (RLS) を設定する

-- ===============================================
-- RLS有効化
-- ===============================================
ALTER TABLE public.words ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.word_meanings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.example_contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deck_words ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_templates ENABLE ROW LEVEL SECURITY;

-- ===============================================
-- 公開データポリシー（誰でも読み取り可能）
-- ===============================================

-- wordsテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "words_select_policy" ON public.words
    FOR SELECT USING (true);

-- word_meaningsテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "word_meanings_select_policy" ON public.word_meanings
    FOR SELECT USING (true);

-- example_contentsテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "example_contents_select_policy" ON public.example_contents
    FOR SELECT USING (true);

-- decksテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "decks_select_policy" ON public.decks
    FOR SELECT USING (true);

-- deck_wordsテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "deck_words_select_policy" ON public.deck_words
    FOR SELECT USING (true);

-- card_templatesテーブル: 全てのユーザーが読み取り可能
CREATE POLICY "card_templates_select_policy" ON public.card_templates
    FOR SELECT USING (true);

-- ===============================================
-- 書き込み制限ポリシー（管理者のみ）
-- ===============================================

-- wordsテーブル: 書き込みは管理者のみ（現在は制限）
CREATE POLICY "words_insert_policy" ON public.words
    FOR INSERT WITH CHECK (false);

CREATE POLICY "words_update_policy" ON public.words
    FOR UPDATE USING (false);

CREATE POLICY "words_delete_policy" ON public.words
    FOR DELETE USING (false);

-- word_meaningsテーブル: 書き込みは管理者のみ
CREATE POLICY "word_meanings_insert_policy" ON public.word_meanings
    FOR INSERT WITH CHECK (false);

CREATE POLICY "word_meanings_update_policy" ON public.word_meanings
    FOR UPDATE USING (false);

CREATE POLICY "word_meanings_delete_policy" ON public.word_meanings
    FOR DELETE USING (false);

-- example_contentsテーブル: 書き込みは管理者のみ
CREATE POLICY "example_contents_insert_policy" ON public.example_contents
    FOR INSERT WITH CHECK (false);

CREATE POLICY "example_contents_update_policy" ON public.example_contents
    FOR UPDATE USING (false);

CREATE POLICY "example_contents_delete_policy" ON public.example_contents
    FOR DELETE USING (false);

-- decksテーブル: 書き込みは管理者のみ
CREATE POLICY "decks_insert_policy" ON public.decks
    FOR INSERT WITH CHECK (false);

CREATE POLICY "decks_update_policy" ON public.decks
    FOR UPDATE USING (false);

CREATE POLICY "decks_delete_policy" ON public.decks
    FOR DELETE USING (false);

-- deck_wordsテーブル: 書き込みは管理者のみ
CREATE POLICY "deck_words_insert_policy" ON public.deck_words
    FOR INSERT WITH CHECK (false);

CREATE POLICY "deck_words_update_policy" ON public.deck_words
    FOR UPDATE USING (false);

CREATE POLICY "deck_words_delete_policy" ON public.deck_words
    FOR DELETE USING (false);

-- card_templatesテーブル: 書き込みは管理者のみ
CREATE POLICY "card_templates_insert_policy" ON public.card_templates
    FOR INSERT WITH CHECK (false);

CREATE POLICY "card_templates_update_policy" ON public.card_templates
    FOR UPDATE USING (false);

CREATE POLICY "card_templates_delete_policy" ON public.card_templates
    FOR DELETE USING (false);

-- RLSポリシー設定完了の確認メッセージ
SELECT 'RLS policies setup completed successfully. All security policies have been configured.' as status;
