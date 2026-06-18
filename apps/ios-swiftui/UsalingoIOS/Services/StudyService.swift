import Foundation

struct DeckWordRow: Decodable {
    let wordId: Int

    enum CodingKeys: String, CodingKey {
        case wordId = "word_id"
    }
}

final class StudyService {
    private let client = SupabaseClient.shared

    func fetchStudyQueue(deckId: Int, session: AuthSession) async throws -> [WordCard] {
        let dueCards = try await fetchDueCards(deckId: deckId, session: session)
        if !dueCards.isEmpty {
            return dueCards
        }
        return try await fetchCards(deckId: deckId, accessToken: session.accessToken)
    }

    func fetchCards(deckId: Int, accessToken: String) async throws -> [WordCard] {
        if deckId == -1 {
            return try await fetchAllCards(accessToken: accessToken)
        }

        let rows: [DeckWordRow] = try await client.request(
            path: "deck_words",
            queryItems: [
                URLQueryItem(name: "select", value: "word_id"),
                URLQueryItem(name: "deck_id", value: "eq.\(deckId)")
            ],
            accessToken: accessToken
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
            accessToken: accessToken
        )

        return records.compactMap { $0.toCard() }
    }

    private func fetchAllCards(accessToken: String) async throws -> [WordCard] {
        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "order", value: "id.asc"),
                URLQueryItem(name: "limit", value: "50")
            ],
            accessToken: accessToken
        )

        return records.compactMap { $0.toCard() }
    }

    func saveAnswer(card: WordCard, isCorrect: Bool, session: AuthSession) async throws {
        let current = try await fetchLearningProgress(wordId: card.id, session: session)
            ?? LearningProgress.initial(userId: session.user.id, wordId: card.id)
        let progress = current.marking(isCorrect: isCorrect)

        let _: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,word_id")],
            accessToken: session.accessToken,
            body: progress,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    func fetchLearningProgress(wordId: Int, session: AuthSession) async throws -> LearningProgress? {
        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,interval_days,created_at,updated_at"),
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
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,interval_days,created_at,updated_at"),
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
        let streak = currentStreak(from: rows.compactMap { row -> Date? in
            guard let value = row.lastReviewedAt else { return nil }
            return Self.parseDate(value)
        })

        return StudyStats(
            studiedCount: rows.count,
            dueCount: dueCount,
            masteredCount: masteredCount,
            currentStreak: streak
        )
    }

    private func fetchDueCards(deckId: Int, session: AuthSession) async throws -> [WordCard] {
        let formatter = ISO8601DateFormatter()
        let rows: [LearningProgress] = try await client.request(
            path: "user_learning_progress",
            queryItems: [
                URLQueryItem(name: "select", value: "user_id,word_id,status,last_reviewed_at,next_review_date,srs_level,easiness_factor,repetitions,interval_days,created_at,updated_at"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "next_review_date", value: "lte.\(formatter.string(from: Date()))"),
                URLQueryItem(name: "order", value: "next_review_date.asc"),
                URLQueryItem(name: "limit", value: "50")
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
            return try await fetchCards(wordIds: deckRows.map(\.wordId), accessToken: session.accessToken)
        }

        return try await fetchCards(wordIds: dueIds, accessToken: session.accessToken)
    }

    private func fetchCards(wordIds: [Int], accessToken: String) async throws -> [WordCard] {
        guard !wordIds.isEmpty else { return [] }
        let records: [WordRecord] = try await client.request(
            path: "words",
            queryItems: [
                URLQueryItem(name: "select", value: "id,word_text,word_meanings(id,priority,part_of_speech_en,definition_jp,example_contents(id,sentence_en,sentence_jp,image_asset_path))"),
                URLQueryItem(name: "id", value: "in.(\(wordIds.map(String.init).joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: accessToken
        )
        return records.compactMap { $0.toCard() }
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
