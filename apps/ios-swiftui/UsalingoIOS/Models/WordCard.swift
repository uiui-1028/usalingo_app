import Foundation

struct WordCard: Identifiable, Hashable {
    let wordId: Int
    let cardId: Int?
    let text: String
    let meaning: String
    let partOfSpeech: String?
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?
    let audioAssetPath: String?
    let tags: [String]
    let learningStatus: String?
    let learning: WordLearningSnapshot?
    /// 類義語。まだ配信データが無いため、未指定なら表示側でサンプルを当てる。
    let synonyms: [WordSynonym]
    /// 語源。まだ配信データが無いため、未指定なら表示側でサンプルを当てる。
    let etymology: String?

    var id: Int {
        cardId ?? wordId
    }

    init(
        id wordId: Int,
        cardId: Int? = nil,
        text: String,
        meaning: String,
        partOfSpeech: String?,
        sentenceEnglish: String?,
        sentenceJapanese: String?,
        imageAssetPath: String?,
        audioAssetPath: String?,
        tags: [String],
        learningStatus: String?,
        learning: WordLearningSnapshot?,
        synonyms: [WordSynonym] = [],
        etymology: String? = nil
    ) {
        self.wordId = wordId
        self.cardId = cardId
        self.text = text
        self.meaning = meaning
        self.partOfSpeech = partOfSpeech
        self.sentenceEnglish = sentenceEnglish
        self.sentenceJapanese = sentenceJapanese
        self.imageAssetPath = imageAssetPath
        self.audioAssetPath = audioAssetPath
        self.tags = tags
        self.learningStatus = learningStatus
        self.learning = learning
        self.synonyms = synonyms
        self.etymology = etymology
    }

    var illustrationURL: URL? {
        guard let path = imageAssetPath, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        return SupabaseConfig.publicStorageURL(for: path)
    }

    var audioURL: URL? {
        guard let path = audioAssetPath, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        return SupabaseConfig.publicStorageURL(for: path)
    }

    func applying(_ override: UserWordOverride) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: override.wordText.requiredOverride(fallback: text),
            meaning: override.definitionJapanese.requiredOverride(fallback: meaning),
            partOfSpeech: partOfSpeech,
            sentenceEnglish: override.sentenceEnglish.optionalOverride(fallback: sentenceEnglish),
            sentenceJapanese: override.sentenceJapanese.optionalOverride(fallback: sentenceJapanese),
            imageAssetPath: override.imageAssetPath.optionalOverride(fallback: imageAssetPath),
            audioAssetPath: audioAssetPath,
            tags: tags,
            learningStatus: learningStatus,
            learning: learning,
            synonyms: synonyms,
            etymology: etymology
        )
    }

    func withTags(_ tags: [String]) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            audioAssetPath: audioAssetPath,
            tags: tags,
            learningStatus: learningStatus,
            learning: learning,
            synonyms: synonyms,
            etymology: etymology
        )
    }

    func withLearningStatus(_ status: String?) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            audioAssetPath: audioAssetPath,
            tags: tags,
            learningStatus: status,
            learning: learning,
            synonyms: synonyms,
            etymology: etymology
        )
    }

    func withLearningProgress(_ progress: LearningProgress?) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            audioAssetPath: audioAssetPath,
            tags: tags,
            learningStatus: progress?.status,
            learning: progress.map(WordLearningSnapshot.init(progress:)),
            synonyms: synonyms,
            etymology: etymology
        )
    }

    func withCardId(_ cardId: Int?) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: text,
            meaning: meaning,
            partOfSpeech: partOfSpeech,
            sentenceEnglish: sentenceEnglish,
            sentenceJapanese: sentenceJapanese,
            imageAssetPath: imageAssetPath,
            audioAssetPath: audioAssetPath,
            tags: tags,
            learningStatus: learningStatus,
            learning: learning,
            synonyms: synonyms,
            etymology: etymology
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

    func toCard(cardId: Int? = nil) -> WordCard? {
        let meaning = wordMeanings?
            .sorted { ($0.priority ?? 9999) < ($1.priority ?? 9999) }
            .first
        guard let meaning else { return nil }
        let example = meaning.exampleContents?.first
        return WordCard(
            id: id,
            cardId: cardId,
            text: wordText,
            meaning: meaning.definitionJapanese,
            partOfSpeech: meaning.partOfSpeechEnglish,
            sentenceEnglish: example?.sentenceEnglish,
            sentenceJapanese: example?.sentenceJapanese,
            imageAssetPath: example?.imageAssetPath,
            audioAssetPath: example?.audioAssetPath,
            tags: [],
            learningStatus: nil,
            learning: nil
        )
    }
}

struct StudyCardRecord: Decodable {
    let id: Int
    let wordId: Int
    let sortOrder: Int
    let word: WordRecord

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case sortOrder = "sort_order"
        case word
    }

    func toCard() -> WordCard? {
        guard word.id == wordId else { return nil }
        return word.toCard(cardId: id)
    }
}

struct CardIdentityRecord: Decodable {
    let id: Int
    let wordId: Int
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case sortOrder = "sort_order"
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
    let audioAssetPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sentenceEnglish = "sentence_en"
        case sentenceJapanese = "sentence_jp"
        case imageAssetPath = "image_asset_path"
        case audioAssetPath = "audio_asset_path"
    }
}

/// 類義語1件。Anki の `単語 :: 訳 :: 補足` を1件ずつ持ち直したもの。
struct WordSynonym: Decodable, Hashable, Identifiable {
    let word: String
    let meaning: String
    let note: String?

    var id: String { word }

    init(word: String, meaning: String, note: String? = nil) {
        self.word = word
        self.meaning = meaning
        self.note = note
    }

    /// Anki 09 フィールドの `A :: 訳 :: 補足 /&/ B :: ...` を解く。
    /// 3つ目以降の `::` は補足へまとめて、区切りが増えても崩れないようにする。
    static func parse(_ raw: String) -> [WordSynonym] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "none" else { return [] }
        return trimmed.components(separatedBy: "/&/").compactMap { entry in
            let parts = entry.components(separatedBy: "::").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let word = parts.first ?? ""
            guard !word.isEmpty else { return nil }
            let meaning = parts.count > 1 ? parts[1] : ""
            let note = parts.count > 2 ? parts[2...].joined(separator: " :: ") : ""
            return WordSynonym(
                word: word,
                meaning: meaning,
                note: note.isEmpty ? nil : note
            )
        }
    }
}
