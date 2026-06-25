import Foundation

struct DeckWordRow: Decodable {
    let wordId: Int

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
    }
}

struct UserWordTag: Codable {
    let userId: String
    let wordId: Int
    let tag: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case wordId = "word_id"
        case tag
    }
}

struct UserWordOverride: Codable {
    let userId: String
    let wordId: Int
    let wordText: String?
    let definitionJapanese: String?
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case wordId = "word_id"
        case wordText = "word_text"
        case definitionJapanese = "definition_jp"
        case sentenceEnglish = "sentence_en"
        case sentenceJapanese = "sentence_jp"
        case imageAssetPath = "image_asset_path"
    }
}

struct UserProfile: Codable {
    let userId: String
    let nickname: String?
    let plan: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
        case plan
    }
}

struct DeckProgressSummary {
    let totalCount: Int
    let studiedCount: Int
    let dueCount: Int
    let masteredCount: Int
    let weakCount: Int

    var newCount: Int {
        max(0, totalCount - studiedCount)
    }
}

enum StudyMode: String, CaseIterable, Identifiable, Hashable {
    case newOnly
    case reviewOnly
    case all
    case weakOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newOnly: return "新規のみ"
        case .reviewOnly: return "復習のみ"
        case .all: return "全単語"
        case .weakOnly: return "苦手のみ"
        }
    }

    var subtitle: String {
        switch self {
        case .newOnly: return "まだ学習していない単語を10枚まで"
        case .reviewOnly: return "期限が来たカードを20枚まで"
        case .all: return "復習、新規、その他を少しずつ"
        case .weakOnly: return "不正解が多い単語を20枚まで"
        }
    }
}

final class StudyService {
    private let client = SupabaseClient.shared

    private enum QueueLimit {
        static let review = 20
        static let new = 10
        static let futureReview = 20
        static let weak = 20
    }

    func fetchStudyQueue(deckId: Int, mode: StudyMode = .all, session: AuthSession) async throws -> [WordCard] {
        switch mode {
        case .newOnly:
            return try await fetchCards(deckId: deckId, session: session)
                .filter { $0.learning == nil }
                .sorted { $0.id < $1.id }
                .prefixArray(QueueLimit.new)
        case .reviewOnly:
            return try await fetchDueCards(deckId: deckId, limit: QueueLimit.review, session: session)
        case .all:
            let cards = try await fetchCards(deckId: deckId, session: session)
            return limitedStudyQueue(cards)
        case .weakOnly:
            return try await fetchCards(deckId: deckId, session: session)
                .filter { $0.learning?.isWeak == true }
                .sorted {
                    if $0.learning?.incorrectCount != $1.learning?.incorrectCount {
                        return ($0.learning?.incorrectCount ?? 0) > ($1.learning?.incorrectCount ?? 0)
                    }
                    return $0.id < $1.id
                }
                .prefixArray(QueueLimit.weak)
        }
    }

    func fetchWordList(session: AuthSession, limit: Int = 200) async throws -> [WordCard] {
        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "order", value: "id.asc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ],
            accessToken: session.accessToken
        )

        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    func fetchCards(deckId: Int, session: AuthSession) async throws -> [WordCard] {
        if deckId == -1 {
            return try await fetchAllCards(session: session)
        }

        let rows: [DeckWordRow] = try await client.request(
            path: "deck_words",
            queryItems: [
                URLQueryItem(name: "select", value: "word_id"),
                URLQueryItem(name: "deck_id", value: "eq.\(deckId)")
            ],
            accessToken: session.accessToken
        )

        let ids = rows.map(\.wordId)
        guard !ids.isEmpty else { return [] }

        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "id", value: "in.(\(ids.map(String.init).joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: session.accessToken
        )

        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    func fetchDeckProgress(deckId: Int, session: AuthSession) async throws -> DeckProgressSummary {
        let cards = try await fetchCards(deckId: deckId, session: session)
        let now = Date()
        return DeckProgressSummary(
            totalCount: cards.count,
            studiedCount: cards.filter { $0.learning != nil }.count,
            dueCount: cards.filter { card in
                guard let nextReviewDate = card.learning?.nextReviewDate,
                      let date = Self.parseDate(nextReviewDate) else { return false }
                return date <= now
            }.count,
            masteredCount: cards.filter { $0.learningStatus == "mastered" }.count,
            weakCount: cards.filter { $0.learning?.isWeak == true }.count
        )
    }

    private func fetchAllCards(session: AuthSession) async throws -> [WordCard] {
        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "order", value: "id.asc"),
                URLQueryItem(name: "limit", value: "50")
            ],
            accessToken: session.accessToken
        )

        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool, session: AuthSession) async throws -> LearningProgress {
        let current = try await fetchLearningProgress(wordId: card.id, session: session)
            ?? LearningProgress.initial(userId: session.user.id, wordId: card.id)
        let progress = current.marking(isCorrect: isCorrect)

        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,word_id")],
            accessToken: session.accessToken,
            body: progress,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        return rows.first ?? progress
    }

    func fetchLearningProgress(wordId: Int, session: AuthSession) async throws -> LearningProgress? {
        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,incorrect_count,interval_days,created_at,updated_at"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "eq.\(wordId)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: session.accessToken
        )
        return rows.first
    }

    func fetchStudyStats(session: AuthSession) async throws -> StudyStats {
        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,incorrect_count,interval_days,created_at,updated_at"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "order", value: "last_reviewed_at.desc")
            ],
            accessToken: session.accessToken
        )

        let now = Date()
        let dueCount = rows.filter { row in
            guard let dueDate = Self.parseDate(row.nextReviewDate) else { return false }
            return dueDate <= now
        }.count
        let masteredCount = rows.filter { $0.status == "mastered" }.count
        let reviewedDates = rows.compactMap { row -> Date? in
            guard let value = row.lastReviewedAt else { return nil }
            return Self.parseDate(value)
        }
        let reviewedDays = Array(Set(reviewedDates.map { Calendar.current.startOfDay(for: $0) })).sorted()
        let streak = currentStreak(from: reviewedDates)

        return StudyStats(
            studiedCount: rows.count,
            dueCount: dueCount,
            masteredCount: masteredCount,
            currentStreak: streak,
            totalReviews: rows.reduce(0) { $0 + $1.repetitions },
            reviewedDays: reviewedDays
        )
    }

    func fetchUserProfile(session: AuthSession) async throws -> UserProfile {
        let rows: [UserProfile] = try await client.request(
            path: "user_profiles",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,nickname,plan"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: session.accessToken
        )

        return rows.first ?? UserProfile(userId: session.user.id, nickname: nil, plan: "free")
    }

    func saveUserProfile(nickname: String, session: AuthSession) async throws -> UserProfile {
        let profile = UserProfile(userId: session.user.id, nickname: nickname, plan: "free")
        let rows: [UserProfile] = try await client.request(
            path: "user_profiles",
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id")],
            accessToken: session.accessToken,
            body: profile,
            prefer: "resolution=merge-duplicates,return=representation"
        )

        guard let savedProfile = rows.first else {
            throw SupabaseError.badResponse("Profile save failed")
        }
        return savedProfile
    }

    func fetchTags(wordId: Int, session: AuthSession) async throws -> [String] {
        let rows: [UserWordTag] = try await client.request(
            path: "user_word_tags",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,tag"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "eq.\(wordId)"),
                URLQueryItem(name: "order", value: "tag.asc")
            ],
            accessToken: session.accessToken
        )
        return rows.map(\.tag)
    }

    func saveTags(_ tags: Set<String>, wordId: Int, session: AuthSession) async throws {
        try await client.execute(
            path: "user_word_tags",
            method: .delete,
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "eq.\(wordId)")
            ],
            accessToken: session.accessToken,
            body: nil
        )

        let rows = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .map { UserWordTag(userId: session.user.id, wordId: wordId, tag: $0) }

        guard !rows.isEmpty else { return }

        try await client.execute(
            path: "user_word_tags",
            method: .post,
            accessToken: session.accessToken,
            body: rows,
            prefer: "return=minimal"
        )
    }

    func saveWordOverride(_ override: UserWordOverride, session: AuthSession) async throws -> WordCard {
        let rows: [UserWordOverride] = try await client.request(
            path: "user_word_overrides",
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,word_id")],
            accessToken: session.accessToken,
            body: override,
            prefer: "resolution=merge-duplicates,return=representation"
        )

        guard let savedOverride = rows.first else {
            throw SupabaseError.badResponse("Word override save failed")
        }

        let cards = try await fetchCards(wordIds: [override.wordId], session: session)
        guard let card = cards.first else {
            throw SupabaseError.badResponse("Saved word could not be reloaded")
        }
        return try await applyUserData(to: [card.applying(savedOverride)], session: session).first ?? card.applying(savedOverride)
    }

    private func fetchDueCards(deckId: Int, limit: Int, session: AuthSession) async throws -> [WordCard] {
        let formatter = ISO8601DateFormatter()
        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,incorrect_count,interval_days,created_at,updated_at"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "next_review_date", value: "lte.\(formatter.string(from: Date()))"),
                URLQueryItem(name: "order", value: "next_review_date.asc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ],
            accessToken: session.accessToken
        )

        let dueIds = rows.map(\.wordId)
        guard !dueIds.isEmpty else { return [] }

        if deckId != -1 {
            let deckRows: [DeckWordRow] = try await client.request(
                path: "deck_words",
                queryItems: [
                    URLQueryItem(name: "select", value: "word_id"),
                    URLQueryItem(name: "deck_id", value: "eq.\(deckId)"),
                    URLQueryItem(name: "word_id", value: "in.(\(dueIds.map(String.init).joined(separator: ",")))")
                ],
                accessToken: session.accessToken
            )
            return try await fetchCards(wordIds: deckRows.map(\.wordId), session: session)
                .ordered(by: dueIds)
        }

        return try await fetchCards(wordIds: dueIds, session: session)
            .ordered(by: dueIds)
    }

    private func fetchCards(wordIds: [Int], session: AuthSession) async throws -> [WordCard] {
        guard !wordIds.isEmpty else { return [] }
        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "id", value: "in.(\(wordIds.map(String.init).joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: session.accessToken
        )
        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    private func limitedStudyQueue(_ cards: [WordCard]) -> [WordCard] {
        let now = Date()
        let dueCards = cards
            .filter { isDue($0, now: now) }
            .sorted(by: sortByNextReviewDateThenId)
            .prefixArray(QueueLimit.review)
        let newCards = cards
            .filter { $0.learning == nil }
            .sorted { $0.id < $1.id }
            .prefixArray(QueueLimit.new)
        let futureReviewCards = cards
            .filter { card in
                guard card.learning != nil else { return false }
                return !isDue(card, now: now)
            }
            .sorted(by: sortByNextReviewDateThenId)
            .prefixArray(QueueLimit.futureReview)

        return dueCards + newCards + futureReviewCards
    }

    private func nextReviewDate(for card: WordCard) -> Date? {
        guard let value = card.learning?.nextReviewDate else { return nil }
        return Self.parseDate(value)
    }

    private func isDue(_ card: WordCard, now: Date) -> Bool {
        guard let dueDate = nextReviewDate(for: card) else { return false }
        return dueDate <= now
    }

    private func sortByNextReviewDateThenId(_ left: WordCard, _ right: WordCard) -> Bool {
        let leftDate = nextReviewDate(for: left)
        let rightDate = nextReviewDate(for: right)
        switch (leftDate, rightDate) {
        case let (leftDate?, rightDate?):
            if leftDate != rightDate { return leftDate < rightDate }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return left.id < right.id
    }

    private func applyUserData(to cards: [WordCard], session: AuthSession) async throws -> [WordCard] {
        let ids = cards.map(\.id)
        guard !ids.isEmpty else { return cards }

        let overrideRows: [UserWordOverride] = try await client.request(
            path: "user_word_overrides",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,word_text,definition_jp,sentence_en,sentence_jp,image_asset_path"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "in.(\(ids.map(String.init).joined(separator: ",")))")
            ],
            accessToken: session.accessToken
        )

        let tagRows: [UserWordTag] = try await client.request(
            path: "user_word_tags",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,tag"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "in.(\(ids.map(String.init).joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "tag.asc")
            ],
            accessToken: session.accessToken
        )

        let progressRows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,incorrect_count,interval_days,created_at,updated_at"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "word_id", value: "in.(\(ids.map(String.init).joined(separator: ",")))")
            ],
            accessToken: session.accessToken
        )

        let overrides = Dictionary(uniqueKeysWithValues: overrideRows.map { ($0.wordId, $0) })
        let tagsByWordId = Dictionary(grouping: tagRows, by: \.wordId)
        let progressByWordId = Dictionary(uniqueKeysWithValues: progressRows.map { ($0.wordId, $0) })
        return cards.map { card in
            let editedCard = overrides[card.id].map { card.applying($0) } ?? card
            let tags = tagsByWordId[card.id]?.map(\.tag) ?? []
            return editedCard
                .withTags(tags)
                .withLearningProgress(progressByWordId[card.id])
        }
    }

    private func currentStreak(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let reviewedDays = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: Date())
        var streak = 0

        while reviewedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return streak
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private extension Array where Element == WordCard {
    func prefixArray(_ maxLength: Int) -> [WordCard] {
        Array(prefix(maxLength))
    }

    func ordered(by wordIds: [Int]) -> [WordCard] {
        let orderByWordId = Dictionary(uniqueKeysWithValues: wordIds.enumerated().map { ($0.element, $0.offset) })
        return sorted {
            (orderByWordId[$0.id] ?? Int.max) < (orderByWordId[$1.id] ?? Int.max)
        }
    }
}
