import Foundation

enum WordDueFilter: String, CaseIterable, Identifiable {
    case all
    case unset
    case due
    case future

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "予定すべて"
        case .unset:
            "未設定"
        case .due:
            "今日まで"
        case .future:
            "今後"
        }
    }

    func matches(_ word: WordCard) -> Bool {
        switch self {
        case .all:
            return true
        case .unset:
            return word.learning == nil
        case .due:
            guard let nextReviewDate = word.learning?.nextReviewDate,
                  let date = Self.parseDate(nextReviewDate) else { return false }
            return date <= Date()
        case .future:
            guard let nextReviewDate = word.learning?.nextReviewDate,
                  let date = Self.parseDate(nextReviewDate) else { return false }
            return date > Date()
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)
    }
}

enum WordSortOption: String, CaseIterable, Identifiable {
    case registered
    case alphabetical
    case status
    case dueDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .registered:
            "登録順"
        case .alphabetical:
            "A-Z"
        case .status:
            "学習状態"
        case .dueDate:
            "復習予定"
        }
    }

    var symbol: String {
        switch self {
        case .registered:
            "number"
        case .alphabetical:
            "textformat.abc"
        case .status:
            "chart.bar"
        case .dueDate:
            "calendar"
        }
    }

    func sort(_ words: [WordCard]) -> [WordCard] {
        switch self {
        case .registered:
            words.sorted { $0.id < $1.id }
        case .alphabetical:
            words.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        case .status:
            words.sorted {
                let leftRank = statusRank($0.learningStatus)
                let rightRank = statusRank($1.learningStatus)
                if leftRank == rightRank { return $0.id < $1.id }
                return leftRank < rightRank
            }
        case .dueDate:
            words.sorted {
                let leftDate = parseDate($0.learning?.nextReviewDate)
                let rightDate = parseDate($1.learning?.nextReviewDate)
                switch (leftDate, rightDate) {
                case let (left?, right?):
                    if left == right { return $0.id < $1.id }
                    return left < right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return $0.id < $1.id
                }
            }
        }
    }

    private func statusRank(_ status: String?) -> Int {
        switch status {
        case nil:
            0
        case "learning":
            1
        case "mastered":
            2
        default:
            3
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)
    }
}

enum WordStatusFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case learning
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "すべて"
        case .new:
            "未学習"
        case .learning:
            "復習中"
        case .mastered:
            "習得済み"
        }
    }

    func matches(_ word: WordCard) -> Bool {
        switch self {
        case .all:
            true
        case .new:
            word.learningStatus == nil
        case .learning:
            word.learningStatus == "learning"
        case .mastered:
            word.learningStatus == "mastered"
        }
    }
}

enum WordListDisplayMode: String, CaseIterable, Identifiable {
    case list
    case cards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:
            "リスト"
        case .cards:
            "カード"
        }
    }

    var symbol: String {
        switch self {
        case .list:
            "list.bullet"
        case .cards:
            "rectangle.grid.2x2"
        }
    }
}
