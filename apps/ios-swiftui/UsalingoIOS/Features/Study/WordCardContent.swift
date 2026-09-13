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

/// カードに表示する内容。配信データが無い項目は表示しない。
struct WordCardContent {
    /// 意味ごとの品詞。重複は取り除いてある。
    let partsOfSpeech: [WordPartOfSpeech]
    let synonyms: [WordSynonym]
    let etymology: String?

    /// 裏面に載せるものが1つでもあるか。無ければ裏面はプレースホルダ1行になる。
    var hasSupplements: Bool {
        !synonyms.isEmpty || (etymology?.isEmpty == false)
    }

    init(card: WordCard) {
        var seen: Set<WordPartOfSpeech> = []
        partsOfSpeech = card.partsOfSpeech
            .compactMap { WordPartOfSpeech(englishOrJapanese: $0) }
            .filter { seen.insert($0).inserted }

        synonyms = card.synonyms
        etymology = card.etymology
    }
}
