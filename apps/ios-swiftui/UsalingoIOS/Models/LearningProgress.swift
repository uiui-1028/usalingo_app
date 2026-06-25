import Foundation

struct LearningProgress: Codable {
    static let weakIncorrectCountThreshold = 3

    private enum SRSRule {
        static let maxLevel = 5
        static let firstCorrectIntervalDays = 1
        static let secondCorrectIntervalDays = 6
        static let incorrectIntervalDays = 1
        static let incorrectLevel = 1
        static let incorrectRepetitions = 0
        static let easinessPenalty = 0.2
        static let minEasinessFactor = 1.3
        static let maxEasinessFactor = 2.5

        static var masteredRepetitions: Int {
            maxLevel - 1
        }
    }

    let userId: String
    let wordId: Int
    let status: String
    let lastReviewedAt: String?
    let nextReviewDate: String
    let srsLevel: Int
    let easinessFactor: Double
    let repetitions: Int
    let incorrectCount: Int
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
        case incorrectCount = "incorrect_count"
        case intervalDays = "interval_days"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isWeak: Bool {
        incorrectCount >= Self.weakIncorrectCountThreshold
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
            incorrectCount: 0,
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
            let nextLevel = min(SRSRule.maxLevel, srsLevel + 1)
            let nextStatus = nextLevel >= SRSRule.maxLevel && nextRepetitions >= SRSRule.masteredRepetitions
                ? "mastered"
                : "learning"
            return LearningProgress(
                userId: userId,
                wordId: wordId,
                status: nextStatus,
                lastReviewedAt: formatter.string(from: now),
                nextReviewDate: formatter.string(from: Calendar.current.date(byAdding: .day, value: nextInterval, to: now) ?? now),
                srsLevel: nextLevel,
                easinessFactor: easinessFactor,
                repetitions: nextRepetitions,
                incorrectCount: incorrectCount,
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
            nextReviewDate: formatter.string(from: Calendar.current.date(byAdding: .day, value: SRSRule.incorrectIntervalDays, to: now) ?? now),
            srsLevel: SRSRule.incorrectLevel,
            easinessFactor: max(SRSRule.minEasinessFactor, min(SRSRule.maxEasinessFactor, easinessFactor - SRSRule.easinessPenalty)),
            repetitions: SRSRule.incorrectRepetitions,
            incorrectCount: incorrectCount + 1,
            intervalDays: SRSRule.incorrectIntervalDays,
            createdAt: createdAt,
            updatedAt: formatter.string(from: now)
        )
    }

    private static func nextIntervalDays(repetitions: Int, currentIntervalDays: Int, easinessFactor: Double) -> Int {
        if repetitions == 1 { return SRSRule.firstCorrectIntervalDays }
        if repetitions == 2 { return SRSRule.secondCorrectIntervalDays }
        return max(1, Int((Double(currentIntervalDays) * easinessFactor).rounded()))
    }
}

struct StudyStats {
    let studiedCount: Int
    let dueCount: Int
    let masteredCount: Int
    let currentStreak: Int
    let totalReviews: Int
    let reviewedDays: [Date]

    static let empty = StudyStats(
        studiedCount: 0,
        dueCount: 0,
        masteredCount: 0,
        currentStreak: 0,
        totalReviews: 0,
        reviewedDays: []
    )
}
