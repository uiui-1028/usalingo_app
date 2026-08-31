import Foundation

/// 単語編集の保存内容。ユーザーIDを持たず、誰の変更として保存するかは実装側の関心事にする。
struct WordOverridePayload {
    let wordId: Int
    let wordText: String
    let definitionJapanese: String
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?
}

/// 学習画面が必要とする操作だけを並べたデータ層の入口。
/// 認証の有無は実装側の関心事とし、引数に AuthSession を渡さない。
protocol StudyDataSource {
    func fetchDecks() async throws -> [Deck]
    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts
    func fetchCards(deckId: Int) async throws -> [WordCard]
    func fetchWordList() async throws -> [WordCard]
    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard]
    func fetchStudyStats() async throws -> StudyStats
    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws
    /// 保存済みのユーザータグ。ユーザーがまだ一度も保存していない場合は nil を返す。
    func fetchTags(wordId: Int) async throws -> [String]?
    func saveTags(_ tags: Set<String>, wordId: Int) async throws
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard
}

struct StudyDeckCounts: Equatable {
    let newCount: Int
    let dueCount: Int
}

/// 認証済み利用者の全学習操作を、同じセッションの StudyService へ渡すラッパー。
final class RemoteStudyDataSource: StudyDataSource {
    private let service: StudyService
    private let session: AuthSession

    init(service: StudyService = StudyService(), session: AuthSession) {
        self.service = service
        self.session = session
    }

    func fetchDecks() async throws -> [Deck] {
        try await service.fetchDecks(session: session)
    }

    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts {
        let cards = try await service.fetchCards(deckId: deckId, session: session)
        let now = Date()
        return StudyDeckCounts(
            newCount: cards.filter { $0.learning == nil }.count,
            dueCount: cards.filter { card in
                guard let value = card.learning?.nextReviewDate else { return false }
                return Self.parseDate(value).map { $0 <= now } ?? false
            }.count
        )
    }

    func fetchCards(deckId: Int) async throws -> [WordCard] {
        try await service.fetchCards(deckId: deckId, session: session)
    }

    func fetchWordList() async throws -> [WordCard] {
        try await service.fetchWordList(session: session)
    }

    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] {
        try await service.fetchStudyQueue(deckId: deckId, mode: mode, session: session)
    }

    func fetchStudyStats() async throws -> StudyStats {
        try await service.fetchStudyStats(session: session)
    }

    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress {
        try await service.saveAnswer(card: card, isCorrect: isCorrect, session: session)
    }

    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer {
        try await service.saveAnswerWithUndo(card: card, isCorrect: isCorrect, session: session)
    }

    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {
        try await service.restoreLearningProgress(cardId: cardId, previousProgress: previousProgress, session: session)
    }

    func fetchTags(wordId: Int) async throws -> [String]? {
        try await service.fetchTags(wordId: wordId, session: session)
    }

    func saveTags(_ tags: Set<String>, wordId: Int) async throws {
        try await service.saveTags(tags, wordId: wordId, session: session)
    }

    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard {
        let override = UserWordOverride(
            userId: session.user.id,
            wordId: payload.wordId,
            wordText: payload.wordText,
            definitionJapanese: payload.definitionJapanese,
            sentenceEnglish: payload.sentenceEnglish,
            sentenceJapanese: payload.sentenceJapanese,
            imageAssetPath: payload.imageAssetPath
        )
        return try await service.saveWordOverride(override, session: session)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}
