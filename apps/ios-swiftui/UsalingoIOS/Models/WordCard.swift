import Foundation

struct WordCard: Identifiable, Decodable, Hashable {
    let id: Int
    let text: String
    let meaning: String
    let partOfSpeech: String?
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?
    let tags: [String]
    let learningStatus: String?
    let learning: WordLearningSnapshot?

    var illustrationURL: URL? {
        guard let path = imageAssetPath, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        return SupabaseConfig.publicStorageURL(for: path)
    }

    func applying(_ override: UserWordOverride) -> WordCard {
        WordCard(
            id: id,
            text: override.wordText.requiredOverride(fallback: text),
            meaning: override.definitionJapanese.requiredOverride(fallback: meaning),
            partOfSpeech: partOfSpeech,
            sentenceEnglish: override.sentenceEnglish.optionalOverride(fallback: sentenceEnglish),
            sentenceJapanese: override.sentenceJapanese.optionalOverride(fallback: sentenceJapanese),
            imageAssetPath: override.imageAssetPath.optionalOverride(fallback: imageAssetPath),
            tags: tags,
            learningStatus: learningStatus,
            learning: learning
        )
    }

    func withTags(_ tags: [String]) -> WordCard {
        WordCard(
            id: id,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            tags: tags,
            learningStatus: learningStatus,
            learning: learning
        )
    }

    func withLearningStatus(_ status: String?) -> WordCard {
        WordCard(
            id: id,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            tags: tags,
            learningStatus: status,
            learning: learning
        )
    }

    func withLearningProgress(_ progress: LearningProgress?) -> WordCard {
        WordCard(
            id: id,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            tags: tags,
            learningStatus: progress?.status,
            learning: progress.map(WordLearningSnapshot.init(progress:))
        )
    }
}

struct WordLearningSnapshot: Decodable, Hashable {
    let status: String
    let nextReviewDate: String
    let srsLevel: Int
    let repetitions: Int
    let incorrectCount: Int
    let intervalDays: Int

    var isWeak: Bool {
        incorrectCount >= LearningProgress.weakIncorrectCountThreshold
    }

    init(progress: LearningProgress) {
        status = progress.status
        nextReviewDate = progress.nextReviewDate
        srsLevel = progress.srsLevel
        repetitions = progress.repetitions
        incorrectCount = progress.incorrectCount
        intervalDays = progress.intervalDays
    }
}

private extension Optional where Wrapped == String {
    func requiredOverride(fallback: String) -> String {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    func optionalOverride(fallback: String?) -> String? {
        guard let value = self else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
            imageAssetPath: example?.imageAssetPath,
            tags: [],
            learningStatus: nil,
            learning: nil
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
