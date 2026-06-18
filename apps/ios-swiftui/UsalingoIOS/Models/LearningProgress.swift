import Foundation

struct LearningProgress: Codable {
    let userId: String
    let wordId: Int
    let status: String
    let lastReviewedAt: String?
    let nextReviewDate: String
    let srsLevel: Int
    let easinessFactor: Double
    let repetitions: Int
    let intervalDays: Int
    let createdAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case wordId = "word_id"
        case status
        case lastReviewedAt = "last_reviewed_at"
        case nextReviewDate = "next_review_date"
        case srsLevel = "srs_level"
        case easinessFactor = "easiness_factor"
        case repetitions
        case intervalDays = "interval_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func initial(userId: String, wordId: Int, now: Date = Date()) -> LearningProgress {
        let formatter = ISO8601DateFormatter()
        return LearningProgress(
            userId: userId,
            wordId: wordId,
            status: "learning",
            lastReviewedAt: nil,
            nextReviewDate: formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now),
            srsLevel: 1,
            easinessFactor: 2.5,
            repetitions: 0,
            intervalDays: 0,
            createdAt: formatter.string(from: now),
            updatedAt: formatter.string(from: now)
        )
    }

    func marking(isCorrect: Bool, now: Date = Date()) -> LearningProgress {
        let formatter = ISO8601DateFormatter()
        if isCorrect {
            let nextRepetitions = repetitions + 1
            let nextInterval = Self.nextIntervalDays(repetitions: nextRepetitions, currentIntervalDays: intervalDays, easinessFactor: easinessFactor)
            let nextLevel = srsLevel + 1
            return LearningProgress(
                userId: userId,
                wordId: wordId,
                status: nextLevel >= 5 ? "mastered" : "learning",
                lastReviewedAt: formatter.string(from: now),
                nextReviewDate: formatter.string(from: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now),
                srsLevel: nextLevel,
                easinessFactor: easinessFactor,
                repetitions: nextRepetitions,
                intervalDays: nextInterval,
                createdAt: createdAt,
                updatedAt: formatter.string(from: now)
            )
        }

        return LearningProgress(
            userId: userId,
            wordId: wordId,
            status: "learning",
            lastReviewedAt: formatter.string(from: now),
            nextReviewDate: formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now),
            srsLevel: 1,
            easinessFactor: max(1.3, min(2.5, easinessFactor - 0.2)),
            repetitions: 0,
            intervalDays: 1,
            createdAt: createdAt,
            updatedAt: formatter.string(from: now)
        )
    }

    private static func nextIntervalDays(repetitions: Int, currentIntervalDays: Int, easinessFactor: Double) -> Int {
        if repetitions == 1 { return 1 }
        if repetitions == 2 { return 6 }
        return max(1, Int((Double(currentIntervalDays) * easinessFactor).rounded()))
    }
}

struct StudyStats {
    let studiedCount: Int
    let dueCount: Int
    let masteredCount: Int
    let currentStreak: Int
}
