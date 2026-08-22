import XCTest
@testable import UsalingoIOS

final class LearningProgressTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_735_732_800)

    func testInitialProgressStartsAsUnlearnedLevelOne() throws {
        let progress = LearningProgress.initial(userId: "user-1", cardId: 420, now: now)

        XCTAssertEqual(progress.userId, "user-1")
        XCTAssertEqual(progress.cardId, 420)
        XCTAssertEqual(progress.status, "learning")
        XCTAssertNil(progress.lastReviewedAt)
        XCTAssertEqual(progress.srsLevel, 1)
        XCTAssertEqual(progress.easinessFactor, 2.5)
        XCTAssertEqual(progress.repetitions, 0)
        XCTAssertEqual(progress.incorrectCount, 0)
        XCTAssertEqual(progress.intervalDays, 0)
        XCTAssertFalse(progress.isWeak)
        try assertNextReviewDate(progress.nextReviewDate, isDays: 1, after: now)
    }

    func testFirstAndSecondCorrectAnswersUseSpecifiedIntervals() throws {
        let initial = LearningProgress.initial(userId: "user-1", cardId: 420, now: now)

        let first = initial.marking(isCorrect: true, now: now)
        XCTAssertEqual(first.srsLevel, 2)
        XCTAssertEqual(first.repetitions, 1)
        XCTAssertEqual(first.intervalDays, 1)
        XCTAssertEqual(first.status, "learning")
        try assertNextReviewDate(first.nextReviewDate, isDays: 1, after: now)

        let secondNow = try date(from: first.nextReviewDate)
        let second = first.marking(isCorrect: true, now: secondNow)
        XCTAssertEqual(second.srsLevel, 3)
        XCTAssertEqual(second.repetitions, 2)
        XCTAssertEqual(second.intervalDays, 6)
        XCTAssertEqual(second.status, "learning")
        try assertNextReviewDate(second.nextReviewDate, isDays: 6, after: secondNow)
    }

    func testRepeatedCorrectAnswersExtendIntervalAndReachMastered() throws {
        var progress = LearningProgress.initial(userId: "user-1", cardId: 420, now: now)
        var reviewDate = now

        for _ in 0..<4 {
            progress = progress.marking(isCorrect: true, now: reviewDate)
            reviewDate = try date(from: progress.nextReviewDate)
        }

        XCTAssertEqual(progress.srsLevel, 5)
        XCTAssertEqual(progress.repetitions, 4)
        XCTAssertEqual(progress.intervalDays, 38)
        XCTAssertEqual(progress.status, "mastered")
    }

    func testIncorrectAnswerResetsLearningAndAppliesPenalty() throws {
        let initial = LearningProgress.initial(userId: "user-1", cardId: 420, now: now)
        let learned = initial.marking(isCorrect: true, now: now)
        let incorrectNow = try date(from: learned.nextReviewDate)

        let result = learned.marking(isCorrect: false, now: incorrectNow)

        XCTAssertEqual(result.status, "learning")
        XCTAssertEqual(result.srsLevel, 1)
        XCTAssertEqual(result.repetitions, 0)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.easinessFactor, 2.3, accuracy: 0.000_001)
        XCTAssertEqual(result.incorrectCount, 1)
        XCTAssertFalse(result.isWeak)
        try assertNextReviewDate(result.nextReviewDate, isDays: 1, after: incorrectNow)
    }

    func testThreeIncorrectAnswersMarkCardAsWeak() {
        var progress = LearningProgress.initial(userId: "user-1", cardId: 420, now: now)

        for _ in 0..<LearningProgress.weakIncorrectCountThreshold {
            progress = progress.marking(isCorrect: false, now: now)
        }

        XCTAssertEqual(progress.incorrectCount, 3)
        XCTAssertTrue(progress.isWeak)
    }

    func testAnsweringLegacyProgressClampsEasinessFactorToCurrentMaximum() throws {
        let json = """
        {
          "user_id": "user-1",
          "card_id": 420,
          "status": "learning",
          "last_reviewed_at": null,
          "next_review_date": "2025-01-02T12:00:00Z",
          "srs_level": 3,
          "easiness_factor": 2.65,
          "repetitions": 2,
          "incorrect_count": 0,
          "interval_days": 6,
          "created_at": "2025-01-01T12:00:00Z",
          "updated_at": "2025-01-01T12:00:00Z"
        }
        """
        let legacy = try JSONDecoder().decode(LearningProgress.self, from: Data(json.utf8))

        let result = legacy.marking(isCorrect: true, now: now)

        XCTAssertEqual(result.cardId, 420)
        XCTAssertEqual(result.easinessFactor, 2.5)
        XCTAssertEqual(result.intervalDays, 15)
    }

    private func assertNextReviewDate(
        _ actualValue: String,
        isDays days: Int,
        after baseDate: Date,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try date(from: actualValue)
        let expected = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: days, to: baseDate))
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func date(from value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}

final class StudyFlowTests: XCTestCase {
    func testLargeDeckIsFetchedInPagesWithoutLosingCards() async throws {
        let client = FakeStudySupabaseClient(deckCardCount: 1_000)
        let service = StudyService(client: client)
        let session = AuthSession(
            accessToken: "test-token",
            refreshToken: nil,
            expiresAt: nil,
            user: AuthUser(id: "user-1", email: "test@example.com")
        )

        let cards = try await service.fetchCards(deckId: 1, session: session)

        XCTAssertEqual(cards.count, 1_000)
        XCTAssertEqual(cards.first?.cardId, 100)
        XCTAssertEqual(cards.last?.cardId, 1_099)
        XCTAssertEqual(client.cardPageRequestCount, 6)
    }

    func testDeckQueueAnswerSaveAndReloadUseCardIdentity() async throws {
        let client = FakeStudySupabaseClient()
        let service = StudyService(client: client)
        let session = AuthSession(
            accessToken: "test-token",
            refreshToken: nil,
            expiresAt: nil,
            user: AuthUser(id: "user-1", email: "test@example.com")
        )

        let queue = try await service.fetchStudyQueue(deckId: 1, mode: .all, session: session)

        XCTAssertEqual(queue.compactMap(\.cardId), [100, 101])
        XCTAssertFalse(queue.contains { $0.cardId == 200 })
        XCTAssertEqual(queue.first?.learning?.status, "review")
        XCTAssertNil(queue.last?.learning)

        let newCard = try XCTUnwrap(queue.last)
        let saved = try await service.saveAnswer(card: newCard, isCorrect: true, session: session)
        let reloaded = try await service.fetchLearningProgress(cardId: 101, session: session)

        XCTAssertEqual(client.savedCardIds, [101])
        XCTAssertEqual(saved.cardId, 101)
        XCTAssertEqual(reloaded?.cardId, saved.cardId)
        XCTAssertEqual(reloaded?.status, saved.status)
        XCTAssertEqual(reloaded?.nextReviewDate, saved.nextReviewDate)
        XCTAssertEqual(reloaded?.repetitions, saved.repetitions)
    }
}

private final class FakeStudySupabaseClient: SupabaseRequesting {
    private struct FixtureCard {
        let id: Int
        let wordId: Int
        let deckId: Int
        let sortOrder: Int
        let wordText: String
        let definitionJapanese: String

        var compactJSON: [String: Any] {
            [
                "id": id,
                "word_id": wordId,
                "sort_order": sortOrder
            ]
        }

        var studyJSON: [String: Any] {
            [
                "id": id,
                "word_id": wordId,
                "sort_order": sortOrder,
                "word": [
                    "id": wordId,
                    "word_text": wordText,
                    "word_meanings": [[
                        "id": wordId * 10,
                        "priority": 1,
                        "part_of_speech_en": "noun",
                        "definition_jp": definitionJapanese,
                        "example_contents": [["id": wordId * 100]]
                    ]]
                ]
            ]
        }
    }

    private let cards: [FixtureCard]
    private var progressByCardId: [Int: LearningProgress]
    private(set) var savedCardIds: [Int] = []
    private(set) var cardPageRequestCount = 0

    init(deckCardCount: Int = 2) {
        cards = (0..<deckCardCount).map { index in
            FixtureCard(
                id: 100 + index,
                wordId: 10 + index,
                deckId: 1,
                sortOrder: index,
                wordText: "word-\(index)",
                definitionJapanese: "意味\(index)"
            )
        } + [FixtureCard(id: 200, wordId: 20, deckId: 2, sortOrder: 0, wordText: "cat", definitionJapanese: "猫")]
        progressByCardId = [
            100: Self.progress(cardId: 100, nextReviewDate: "2020-01-02T00:00:00Z"),
            200: Self.progress(cardId: 200, nextReviewDate: "2020-01-01T00:00:00Z")
        ]
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws -> T {
        switch (path, method) {
        case ("cards", .get):
            return try decodeCardResponse(queryItems: queryItems)
        case ("user_card_progress", .get):
            return try decodeProgressResponse(queryItems: queryItems)
        case ("user_card_progress", .post):
            guard let body else { throw SupabaseError.badResponse("Missing test progress body") }
            let data = try JSONEncoder().encode(AnyEncodable(body))
            let progress = try JSONDecoder().decode(LearningProgress.self, from: data)
            progressByCardId[progress.cardId] = progress
            savedCardIds.append(progress.cardId)
            return try decode([progress])
        case ("user_word_overrides", .get), ("user_word_tags", .get):
            return try decodeJSONObject([])
        default:
            throw SupabaseError.badResponse("Unexpected test request: \(method.rawValue) \(path)")
        }
    }

    func execute(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws {
        throw SupabaseError.badResponse("Unexpected test execute: \(method.rawValue) \(path)")
    }

    private func decodeCardResponse<T: Decodable>(queryItems: [URLQueryItem]) throws -> T {
        let selectedColumns = queryValue("select", in: queryItems) ?? ""
        let deckId = equalIntValue("deck_id", in: queryItems)
        let cardIds = inIntValues("id", in: queryItems)
        let wordIds = inIntValues("word_id", in: queryItems)

        var filtered = cards
            .filter { deckId == nil || $0.deckId == deckId }
            .filter { cardIds == nil || cardIds?.contains($0.id) == true }
            .filter { wordIds == nil || wordIds?.contains($0.wordId) == true }
            .sorted {
                if $0.deckId != $1.deckId { return $0.deckId < $1.deckId }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.id < $1.id
            }

        if queryValue("offset", in: queryItems) != nil {
            cardPageRequestCount += 1
        }
        if let offset = Int(queryValue("offset", in: queryItems) ?? "0") {
            filtered = Array(filtered.dropFirst(offset))
        }
        if let limit = Int(queryValue("limit", in: queryItems) ?? "") {
            filtered = Array(filtered.prefix(limit))
        }

        let json = selectedColumns.contains("word:words")
            ? filtered.map(\.studyJSON)
            : filtered.map(\.compactJSON)
        return try decodeJSONObject(json)
    }

    private func decodeProgressResponse<T: Decodable>(queryItems: [URLQueryItem]) throws -> T {
        let cardId = equalIntValue("card_id", in: queryItems)
        let cardIds = inIntValues("card_id", in: queryItems)
        let deckId = equalIntValue("cards.deck_id", in: queryItems)
        let limit = Int(queryValue("limit", in: queryItems) ?? "")

        var rows = progressByCardId.values
            .filter { cardId == nil || $0.cardId == cardId }
            .filter { cardIds == nil || cardIds?.contains($0.cardId) == true }
            .filter { progress in
                guard let deckId else { return true }
                return cards.first(where: { $0.id == progress.cardId })?.deckId == deckId
            }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
        if let limit {
            rows = Array(rows.prefix(limit))
        }
        return try decode(rows)
    }

    private func queryValue(_ name: String, in queryItems: [URLQueryItem]) -> String? {
        queryItems.first(where: { $0.name == name })?.value
    }

    private func equalIntValue(_ name: String, in queryItems: [URLQueryItem]) -> Int? {
        guard let value = queryValue(name, in: queryItems), value.hasPrefix("eq.") else { return nil }
        return Int(value.dropFirst(3))
    }

    private func inIntValues(_ name: String, in queryItems: [URLQueryItem]) -> Set<Int>? {
        guard let value = queryValue(name, in: queryItems),
              value.hasPrefix("in.("), value.hasSuffix(")") else { return nil }
        let start = value.index(value.startIndex, offsetBy: 4)
        let end = value.index(before: value.endIndex)
        return Set(value[start..<end].split(separator: ",").compactMap { Int($0) })
    }

    private func decode<T: Decodable, Value: Encodable>(_ value: Value) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    private func decodeJSONObject<T: Decodable>(_ value: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func progress(cardId: Int, nextReviewDate: String) -> LearningProgress {
        LearningProgress(
            userId: "user-1",
            cardId: cardId,
            status: "review",
            lastReviewedAt: "2020-01-01T00:00:00Z",
            nextReviewDate: nextReviewDate,
            srsLevel: 2,
            easinessFactor: 2.5,
            repetitions: 1,
            incorrectCount: 0,
            intervalDays: 1,
            createdAt: "2020-01-01T00:00:00Z",
            updatedAt: "2020-01-01T00:00:00Z"
        )
    }
}
