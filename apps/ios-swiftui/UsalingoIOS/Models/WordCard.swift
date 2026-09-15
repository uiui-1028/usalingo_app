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
    /// その単語の意味。先頭がデッキの主の意味で、残りは `priority` の昇順で並んでいる。
    let senses: [WordSense]
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?
    /// 例文の音声。
    let audioAssetPath: String?
    /// 単語の音声。`word_pronunciations` の標準の声（`is_primary`）を使う。
    let wordAudioAssetPath: String?
    let tags: [String]
    let learningStatus: String?
    let learning: WordLearningSnapshot?
    /// 類義語。配信データに無ければ空のままにし、表示側で隠す。
    let synonyms: [WordSynonym]
    /// 語源。配信データに無ければ nil のままにし、表示側で隠す。
    let etymology: String?

    var id: Int {
        cardId ?? wordId
    }

    /// 並んだ意味を1本の文字列にしたもの。表示と検索はこれを使う。
    var meaning: String {
        senses.map(\.meaning).joined(separator: Self.meaningSeparator)
    }

    /// 主の意味。カードで大きく出す。
    var primaryMeaning: String {
        senses.first?.meaning ?? ""
    }

    /// 副の意味をつないだもの。副が無ければ nil。
    var secondaryMeaning: String? {
        let rest = senses.dropFirst().map(\.meaning)
        return rest.isEmpty ? nil : rest.joined(separator: Self.meaningSeparator)
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
        wordAudioAssetPath: String? = nil,
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
        self.wordAudioAssetPath = wordAudioAssetPath
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
        wordAudioAssetPath: String? = nil,
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
            wordAudioAssetPath: wordAudioAssetPath,
            tags: tags,
            learningStatus: learningStatus,
            learning: learning,
            synonyms: synonyms,
            etymology: etymology
        )
    }

    var illustrationURL: URL? {
        Self.assetURL(for: imageAssetPath)
    }

    var audioURL: URL? {
        Self.assetURL(for: audioAssetPath)
    }

    var wordAudioURL: URL? {
        Self.assetURL(for: wordAudioAssetPath)
    }

    private static func assetURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
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
            wordAudioAssetPath: wordAudioAssetPath,
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
            wordAudioAssetPath: wordAudioAssetPath,
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
            wordAudioAssetPath: wordAudioAssetPath,
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
            wordAudioAssetPath: wordAudioAssetPath,
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
            wordAudioAssetPath: wordAudioAssetPath,
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
    let wordPronunciations: [WordPronunciation]?

    enum CodingKeys: String, CodingKey {
        case id
        case wordText = "word_text"
        case wordMeanings = "word_meanings"
        case wordPronunciations = "word_pronunciations"
    }

    /// `primaryMeaningId` はデッキが決めた主の意味（`cards.primary_meaning_id`）。
    /// その意味を先頭に置き、残りを `priority` 順に並べる。見つからなければ `priority` 順のまま。
    func toCard(cardId: Int? = nil, primaryMeaningId: Int? = nil) -> WordCard? {
        var meanings = (wordMeanings ?? [])
            .sorted { ($0.priority ?? 9999) < ($1.priority ?? 9999) }
        guard !meanings.isEmpty else { return nil }
        if let primaryIndex = meanings.firstIndex(where: { $0.id == primaryMeaningId }) {
            meanings.insert(meanings.remove(at: primaryIndex), at: 0)
        }
        // 例文は主の意味から探し、無ければ残りを優先度順に探す。主の意味に例文が無いだけで
        // 例文・訳・イラスト・音声が4つとも消えることを防ぐ。
        let example = meanings.lazy.compactMap { $0.exampleContents?.first }.first
        // 類義語と語源も例文と同じ順（主の意味、残りは優先度順）に探す。主の意味に無いだけで
        // 補足が丸ごと消えることを防ぐ。
        let etymology = meanings.lazy
            .compactMap { $0.etymology?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let synonyms = meanings.lazy
            .map { ($0.synonyms ?? []).flatMap(WordSynonym.parse) }
            .first { !$0.isEmpty } ?? []
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
            wordAudioAssetPath: wordPronunciations?.first(where: \.isPrimary)?.audioAssetPath,
            tags: [],
            learningStatus: nil,
            learning: nil,
            synonyms: synonyms,
            etymology: etymology
        )
    }
}

struct StudyCardRecord: Decodable {
    let id: Int
    let wordId: Int
    let sortOrder: Int
    /// デッキが決めた主の意味。NULL なら `priority` が最も小さい意味を主にする。
    let primaryMeaningId: Int?
    let word: WordRecord

    enum CodingKeys: String, CodingKey {
        case id
        case wordId = "word_id"
        case sortOrder = "sort_order"
        case primaryMeaningId = "primary_meaning_id"
        case word
    }

    func toCard() -> WordCard? {
        guard word.id == wordId else { return nil }
        return word.toCard(cardId: id, primaryMeaningId: primaryMeaningId)
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
    let etymology: String?
    /// `word_meanings.synonyms`（text[]）。1要素が `単語 :: 訳 :: 補足` の1件にあたる。
    let synonyms: [String]?
    let exampleContents: [ExampleContent]?

    enum CodingKeys: String, CodingKey {
        case id
        case priority
        case partOfSpeechEnglish = "part_of_speech_en"
        case definitionJapanese = "definition_jp"
        case etymology
        case synonyms
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

/// 単語の発音1件。音声が無い発音は `audio_asset_path` が NULL になる。
struct WordPronunciation: Decodable {
    let audioAssetPath: String?
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case audioAssetPath = "audio_asset_path"
        case isPrimary = "is_primary"
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
