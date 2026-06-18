import Foundation

struct WordCard: Identifiable, Decodable, Hashable {
    let id: Int
    let text: String
    let meaning: String
    let partOfSpeech: String?
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?

    var illustrationURL: URL? {
        guard let path = imageAssetPath, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        return SupabaseConfig.publicStorageURL(for: path)
    }
}

struct WordRecord: Decodable {
    let id: Int
    let wordText: String
    let wordMeanings: [WordMeaning]?

    enum CodingKeys: String, CodingKey {
        case id
        case wordText = "word_text"
        case wordMeanings = "word_meanings"
    }

    func toCard() -> WordCard? {
        let meaning = wordMeanings?
            .sorted { ($0.priority ?? 9999) < ($1.priority ?? 9999) }
            .first
        guard let meaning else { return nil }
        let example = meaning.exampleContents?.first
        return WordCard(
            id: id,
            text: wordText,
            meaning: meaning.definitionJapanese,
            partOfSpeech: meaning.partOfSpeechEnglish,
            sentenceEnglish: example?.sentenceEnglish,
            sentenceJapanese: example?.sentenceJapanese,
            imageAssetPath: example?.imageAssetPath
        )
    }
}

struct WordMeaning: Decodable {
    let id: Int
    let priority: Int?
    let partOfSpeechEnglish: String?
    let definitionJapanese: String
    let exampleContents: [ExampleContent]?

    enum CodingKeys: String, CodingKey {
        case id
        case priority
        case partOfSpeechEnglish = "part_of_speech_en"
        case definitionJapanese = "definition_jp"
        case exampleContents = "example_contents"
    }
}

struct ExampleContent: Decodable {
    let id: Int
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sentenceEnglish = "sentence_en"
        case sentenceJapanese = "sentence_jp"
        case imageAssetPath = "image_asset_path"
    }
}
