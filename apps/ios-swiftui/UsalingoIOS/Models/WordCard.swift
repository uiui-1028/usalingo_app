import Foundation

/// 1つの意味と、その意味に付く品詞。
///
/// 品詞は意味ごとに変わる（`light` ＝ 明かり／名詞、軽い／形容詞）ため、
/// 意味と品詞は必ず組にして持つ。
struct WordSense: Hashable {
    let meaning: String
    let partOfSpeech: String?

    init(meaning: String, partOfSpeech: String? = nil) {
        self.meaning = meaning
        self.partOfSpeech = partOfSpeech
    }
}

struct WordCard: Identifiable, Hashable {
    /// 意味を横に並べるときの区切り。
    static let meaningSeparator = "／"

    let wordId: Int
    let cardId: Int?
    let text: String
    /// その単語の意味。`priority` の昇順で並んでいる。
    let senses: [WordSense]
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

    /// 並んだ意味を1本の文字列にしたもの。表示と検索はこれを使う。
    var meaning: String {
        senses.map(\.meaning).joined(separator: Self.meaningSeparator)
    }

    /// 代表の品詞。1つしか置けない場所（詳細画面の見出しなど）で使う。
    var partOfSpeech: String? {
        senses.compactMap(\.partOfSpeech).first
    }

    /// 意味ごとの品詞。重複は取り除き、出てきた順を保つ。
    var partsOfSpeech: [String] {
        var seen: Set<String> = []
        return senses.compactMap(\.partOfSpeech).filter { seen.insert($0).inserted }
    }

    init(
        id wordId: Int,
        cardId: Int? = nil,
        text: String,
        senses: [WordSense],
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
        self.senses = senses
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

    /// 意味が1つだけのカードを作る。同梱デッキや利用者の上書きはこちらを使う。
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
        self.init(
            id: wordId,
            cardId: cardId,
            text: text,
            senses: [WordSense(meaning: meaning, partOfSpeech: partOfSpeech)],
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
            senses: overriddenSenses(with: override.definitionJapanese),
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

    /// 利用者の上書きは `user_word_overrides.definition_jp` の1本の文字列なので、
    /// 並んだ意味の全体を置き換える1つの意味として扱う。意味ごとの上書きは持たない。
    private func overriddenSenses(with definitionJapanese: String?) -> [WordSense] {
        guard
            let value = definitionJapanese?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return senses
        }
        return [WordSense(meaning: value, partOfSpeech: partOfSpeech)]
    }

    func withTags(_ tags: [String]) -> WordCard {
        WordCard(
            id: wordId,
            cardId: cardId,
            text: text,
            senses: senses,
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
            senses: senses,
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
            senses: senses,
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
            senses: senses,
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
        let meanings = (wordMeanings ?? [])
            .sorted { ($0.priority ?? 9999) < ($1.priority ?? 9999) }
        guard !meanings.isEmpty else { return nil }
        // 例文は優先度順にすべての意味から探す。優先度1の意味に例文が無いだけで
        // 例文・訳・イラスト・音声が4つとも消えることを防ぐ。
        let example = meanings.lazy.compactMap { $0.exampleContents?.first }.first
        return WordCard(
            id: id,
            cardId: cardId,
            text: wordText,
            senses: meanings.map {
                WordSense(meaning: $0.definitionJapanese, partOfSpeech: $0.partOfSpeechEnglish)
            },
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
