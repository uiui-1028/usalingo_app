import Foundation

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
        case .newOnly: return "まだ学習していないカードを10枚まで"
        case .reviewOnly: return "期限が来たカードを20枚まで"
        case .all: return "復習、新規、その他を少しずつ"
        case .weakOnly: return "不正解が多いカードを20枚まで"
        }
    }
}

final class StudyService {
    private let client: any SupabaseRequesting

    init(client: any SupabaseRequesting = SupabaseClient.shared) {
        self.client = client
    }

    private func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = nil,
        prefer: String? = nil
    ) async throws -> T {
        try await client.request(
            path: path,
            method: method,
            queryItems: queryItems,
            accessToken: accessToken,
            body: body,
            prefer: prefer
        )
    }

    private func execute(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = EmptyPayload(),
        prefer: String? = nil
    ) async throws {
        try await client.execute(
            path: path,
            method: method,
            queryItems: queryItems,
            accessToken: accessToken,
            body: body,
            prefer: prefer
        )
    }

    private enum QueueLimit {
        static let review = 20
        static let new = 10
        static let futureReview = 20
        static let weak = 20
    }

    private enum FetchLimit {
        // Keep REST URLs short and stay below the Data API's default response cap.
        static let pageSize = 200
        static let identifierBatchSize = 100
    }

    private enum SelectColumns {
        static let progress = "user_id,card_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,incorrect_count,interval_days,created_at,updated_at"
        static let word = "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path,audio_asset_path))"
        static let studyCard = "id,word_id,sort_order,word:words!inner(\(word))"
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

    func fetchWordList(session: AuthSession, limit: Int? = nil) async throws -> [WordCard] {
        let records: [WordRecord] = try await fetchAllPages(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.word),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: session.accessToken,
            maximumRecordCount: limit
        )

        let words = records.compactMap { $0.toCard() }
        let cards = try await attachPrimaryCardIds(to: words, session: session)
        return try await applyUserData(to: cards, session: session)
    }

    func fetchCards(deckId: Int, session: AuthSession) async throws -> [WordCard] {
        if deckId == -1 {
            return try await fetchAllCards(session: session)
        }

        let records: [StudyCardRecord] = try await fetchAllPages(
            path: "cards",
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.studyCard),
                URLQueryItem(name: "deck_id", value: "eq.\(deckId)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "sort_order.asc,id.asc")
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
        let records: [StudyCardRecord] = try await fetchAllPages(
            path: "cards",
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.studyCard),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "deck_id.asc,sort_order.asc,id.asc")
            ],
            accessToken: session.accessToken
        )

        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool, session: AuthSession) async throws -> LearningProgress {
        guard let cardId = card.cardId else {
            throw SupabaseError.badResponse("Learning progress requires a card_id")
        }
        let current = try await fetchLearningProgress(cardId: cardId, session: session)
            ?? LearningProgress.initial(userId: session.user.id, cardId: cardId)
        let progress = current.marking(isCorrect: isCorrect)

        let rows: [LearningProgress] = try await request(
            path: "user_card_progress",
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,card_id")],
            accessToken: session.accessToken,
            body: progress,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        return rows.first ?? progress
    }

    func fetchLearningProgress(cardId: Int, session: AuthSession) async throws -> LearningProgress? {
        let rows: [LearningProgress] = try await request(
            path: "user_card_progress",
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.progress),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "card_id", value: "eq.\(cardId)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: session.accessToken
        )
        return rows.first
    }

    func fetchStudyStats(session: AuthSession) async throws -> StudyStats {
        let rows: [LearningProgress] = try await request(
            path: "user_card_progress",
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.progress),
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
        let rows: [UserProfile] = try await request(
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
        let rows: [UserProfile] = try await request(
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
        let rows: [UserWordTag] = try await request(
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
        try await execute(
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

        try await execute(
            path: "user_word_tags",
            method: .post,
            accessToken: session.accessToken,
            body: rows,
            prefer: "return=minimal"
        )
    }

    func saveWordOverride(_ override: UserWordOverride, session: AuthSession) async throws -> WordCard {
        let rows: [UserWordOverride] = try await request(
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

        let cards = try await fetchWordCards(wordIds: [override.wordId], session: session)
        guard let card = cards.first else {
            throw SupabaseError.badResponse("Saved word could not be reloaded")
        }
        return try await applyUserData(to: [card.applying(savedOverride)], session: session).first ?? card.applying(savedOverride)
    }

    private func fetchDueCards(deckId: Int, limit: Int, session: AuthSession) async throws -> [WordCard] {
        let formatter = ISO8601DateFormatter()
        var queryItems = [
            URLQueryItem(
                name: "select",
                value: deckId == -1 ? SelectColumns.progress : "\(SelectColumns.progress),cards!inner(deck_id)"
            ),
            URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
            URLQueryItem(name: "next_review_date", value: "lte.\(formatter.string(from: Date()))"),
            URLQueryItem(name: "order", value: "next_review_date.asc"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if deckId != -1 {
            queryItems.append(URLQueryItem(name: "cards.deck_id", value: "eq.\(deckId)"))
        }

        let rows: [LearningProgress] = try await request(
            path: "user_card_progress",
            queryItems: queryItems,
            accessToken: session.accessToken
        )

        let dueIds = rows.map(\.cardId)
        guard !dueIds.isEmpty else { return [] }

        return try await fetchStudyCards(cardIds: dueIds, deckId: deckId, session: session)
            .ordered(byCardIds: dueIds)
    }

    private func fetchWordCards(wordIds: [Int], session: AuthSession) async throws -> [WordCard] {
        guard !wordIds.isEmpty else { return [] }
        let records: [WordRecord] = try await fetchRecords(
            path: "words",
            identifierName: "id",
            identifiers: wordIds,
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.word),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: session.accessToken
        )
        let words = records.compactMap { $0.toCard() }
        let cards = try await attachPrimaryCardIds(to: words, session: session)
        return try await applyUserData(to: cards, session: session)
    }

    private func fetchStudyCards(cardIds: [Int], deckId: Int, session: AuthSession) async throws -> [WordCard] {
        guard !cardIds.isEmpty else { return [] }
        let records: [StudyCardRecord] = try await fetchRecords(
            path: "cards",
            identifierName: "id",
            identifiers: cardIds,
            queryItems: [
                URLQueryItem(name: "select", value: SelectColumns.studyCard),
                URLQueryItem(name: "is_active", value: "eq.true")
            ] + (deckId == -1 ? [] : [URLQueryItem(name: "deck_id", value: "eq.\(deckId)")]),
            accessToken: session.accessToken
        )
        return try await applyUserData(to: records.compactMap { $0.toCard() }, session: session)
    }

    private func fetchAllPages<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        accessToken: String,
        maximumRecordCount: Int? = nil
    ) async throws -> [T] {
        var records: [T] = []
        var offset = 0

        while maximumRecordCount.map({ records.count < $0 }) ?? true {
            let remaining = maximumRecordCount.map { $0 - records.count }
            let pageSize = min(FetchLimit.pageSize, remaining ?? FetchLimit.pageSize)
            guard pageSize > 0 else { break }
            let page: [T] = try await request(
                path: path,
                queryItems: queryItems + [
                    URLQueryItem(name: "limit", value: "\(pageSize)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ],
                accessToken: accessToken
            )
            records += page
            guard page.count == pageSize else { break }
            offset += pageSize
        }

        return records
    }

    private func fetchRecords<T: Decodable>(
        path: String,
        identifierName: String,
        identifiers: [Int],
        queryItems: [URLQueryItem],
        accessToken: String
    ) async throws -> [T] {
        var records: [T] = []
        for start in stride(from: 0, to: identifiers.count, by: FetchLimit.identifierBatchSize) {
            let end = min(start + FetchLimit.identifierBatchSize, identifiers.count)
            let batch = identifiers[start..<end]
            let page: [T] = try await request(
                path: path,
                queryItems: queryItems + [
                    URLQueryItem(name: identifierName, value: "in.(\(batch.map(String.init).joined(separator: ",")))")
                ],
                accessToken: accessToken
            )
            records += page
        }
        return records
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
        let wordIds = Array(Set(cards.map(\.wordId))).sorted()
        let cardIds = Array(Set(cards.compactMap(\.cardId))).sorted()
        guard !wordIds.isEmpty else { return cards }

        let overrideRows: [UserWordOverride] = try await fetchRecords(
            path: "user_word_overrides",
            identifierName: "word_id",
            identifiers: wordIds,
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,word_text,definition_jp,sentence_en,sentence_jp,image_asset_path"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)")
            ],
            accessToken: session.accessToken
        )

        let tagRows: [UserWordTag] = try await fetchRecords(
            path: "user_word_tags",
            identifierName: "word_id",
            identifiers: wordIds,
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,tag"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "order", value: "tag.asc")
            ],
            accessToken: session.accessToken
        )

        let progressRows: [LearningProgress]
        if cardIds.isEmpty {
            progressRows = []
        } else {
            progressRows = try await fetchRecords(
                path: "user_card_progress",
                identifierName: "card_id",
                identifiers: cardIds,
                queryItems: [
                    URLQueryItem(name: "select", value: SelectColumns.progress),
                    URLQueryItem(name: "user_id", value: "eq.\(session.user.id)")
                ],
                accessToken: session.accessToken
            )
        }

        let overrides = Dictionary(uniqueKeysWithValues: overrideRows.map { ($0.wordId, $0) })
        let tagsByWordId = Dictionary(grouping: tagRows, by: \.wordId)
        let progressByCardId = Dictionary(uniqueKeysWithValues: progressRows.map { ($0.cardId, $0) })
        return cards.map { card in
            let editedCard = overrides[card.wordId].map { card.applying($0) } ?? card
            let tags = tagsByWordId[card.wordId]?.map(\.tag) ?? []
            return editedCard
                .withTags(tags)
                .withLearningProgress(card.cardId.flatMap { progressByCardId[$0] })
        }
    }

    private func attachPrimaryCardIds(to words: [WordCard], session: AuthSession) async throws -> [WordCard] {
        let wordIds = Array(Set(words.map(\.wordId))).sorted()
        guard !wordIds.isEmpty else { return words }

        let rows: [CardIdentityRecord] = try await fetchRecords(
            path: "cards",
            identifierName: "word_id",
            identifiers: wordIds,
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_id,sort_order"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "word_id.asc,sort_order.asc,id.asc")
            ],
            accessToken: session.accessToken
        )

        var primaryCardIdByWordId: [Int: Int] = [:]
        for row in rows where primaryCardIdByWordId[row.wordId] == nil {
            primaryCardIdByWordId[row.wordId] = row.id
        }
        return words.map { $0.withCardId(primaryCardIdByWordId[$0.wordId]) }
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

    func ordered(byCardIds cardIds: [Int]) -> [WordCard] {
        let orderByCardId = Dictionary(uniqueKeysWithValues: cardIds.enumerated().map { ($0.element, $0.offset) })
        return sorted {
            (orderByCardId[$0.cardId ?? -1] ?? Int.max) < (orderByCardId[$1.cardId ?? -1] ?? Int.max)
        }
    }
}
