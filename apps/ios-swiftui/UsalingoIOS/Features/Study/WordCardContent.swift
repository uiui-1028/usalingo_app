import Foundation

/// 品詞。カードの品詞行に並べる選択肢と、英語表記からの対応づけを持つ。
enum WordPartOfSpeech: String, CaseIterable, Identifiable {
    case noun = "名詞"
    case verb = "動詞"
    case adjective = "形容詞"
    case adverb = "副詞"
    case preposition = "前置詞"
    case conjunction = "接続詞"

    var id: String { rawValue }

    /// 品詞行に並べる並び順。Anki の並び（動詞・名詞・形容詞・副詞・前置詞）を踏襲する。
    /// 接続詞は前置詞の枠を置き換えて出すため、この一覧には含めない。
    static let displayOrder: [WordPartOfSpeech] = [.verb, .noun, .adjective, .adverb, .preposition]

    /// `part_of_speech_en` の表記ゆれを吸収して1つに寄せる。
    init?(englishOrJapanese raw: String?) {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let match = WordPartOfSpeech(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self = match
            return
        }
        switch key {
        case "noun", "n", "pronoun": self = .noun
        case "verb", "v", "auxiliary verb": self = .verb
        case "adjective", "adj": self = .adjective
        case "adverb", "adv": self = .adverb
        case "preposition", "prep": self = .preposition
        case "conjunction", "conj": self = .conjunction
        default: return nil
        }
    }
}

/// カードに表示する内容。配信データが無い項目はサンプルで埋める。
///
/// 類義語と語源はまだ `words` テーブルに列が無い。実データが入ったら
/// `WordCard.synonyms` / `WordCard.etymology` に値が乗り、サンプルは自動で使われなくなる。
struct WordCardContent {
    let partOfSpeech: WordPartOfSpeech?
    let synonyms: [WordSynonym]
    let etymology: String?
    /// サンプルで埋めた項目があるか。画面に「サンプル」と明示するために使う。
    let usesSampleData: Bool

    /// 裏面に載せるものが1つでもあるか。無ければ裏面はプレースホルダ1行になる。
    var hasSupplements: Bool {
        !synonyms.isEmpty || (etymology?.isEmpty == false)
    }

    init(card: WordCard) {
        partOfSpeech = WordPartOfSpeech(englishOrJapanese: card.partOfSpeech)

        let hasRealSynonyms = !card.synonyms.isEmpty
        let hasRealEtymology = (card.etymology?.isEmpty == false)
        let sampleSynonyms = hasRealSynonyms ? [] : Self.sampleSynonyms(for: card)
        let sampleEtymology = hasRealEtymology ? nil : Self.sampleEtymology(for: card)

        synonyms = hasRealSynonyms ? card.synonyms : sampleSynonyms
        etymology = hasRealEtymology ? card.etymology : sampleEtymology
        usesSampleData = !sampleSynonyms.isEmpty || sampleEtymology != nil
    }

    // MARK: - サンプル

    /// 単語ごとに同じものが出るよう、id から決め打ちで選ぶ。
    /// 4つに1つは空にしてあり、補足がまだ1件も無いカードの見え方も確認できる。
    private static func sampleSynonyms(for card: WordCard) -> [WordSynonym] {
        let variants: [[WordSynonym]] = [
            [
                WordSynonym(word: "identical", meaning: "まったく同じ", note: "細部まで一致するときに使う。差が無いことを強調する。"),
                WordSynonym(word: "similar", meaning: "似ている", note: "同じではないが近い。日常会話で最もよく使う。")
            ],
            [
                WordSynonym(word: "obtain", meaning: "手に入れる", note: "かたい語。手続きを踏んで得る場面で使う。"),
                WordSynonym(word: "acquire", meaning: "獲得する", note: "時間をかけて身につける意味を含む。"),
                WordSynonym(word: "gain", meaning: "得る", note: "利益や経験など、増えるものに使う。")
            ],
            [
                WordSynonym(word: "quick", meaning: "すばやい", note: "反応や動作の速さ。短い時間で終わることを指す。"),
                WordSynonym(word: "rapid", meaning: "急速な", note: "変化の速さ。書き言葉でよく使う。")
            ],
            []
        ]
        return variants[abs(card.wordId) % variants.count]
    }

    private static func sampleEtymology(for card: WordCard) -> String? {
        let variants: [String?] = [
            "ラテン語 *pōnere*（置く）に由来する。接頭辞が付いて「前に置く」→「差し出す」と意味が広がった。",
            "古英語 *strang*（強い）から。ゲルマン語系の語で、現代語でも「力」の意味を保っている。",
            "フランス語経由でラテン語 *capere*（つかむ）へさかのぼる。「手に取る」から「理解する」へ広がった。",
            nil
        ]
        return variants[abs(card.wordId) % variants.count]
    }
}
