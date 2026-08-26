import Foundation

enum LearningPurpose: String, CaseIterable, Codable, Identifiable {
    case toeic
    case entranceExam
    case dailyConversation

    var id: Self { self }

    var title: String {
        switch self {
        case .toeic: "TOEIC"
        case .entranceExam: "受験"
        case .dailyConversation: "日常英会話"
        }
    }
}

enum EnglishLevel: String, CaseIterable, Codable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: Self { self }

    var title: String {
        switch self {
        case .beginner: "初心者"
        case .intermediate: "中級者"
        case .advanced: "上級者"
        }
    }
}

enum DailyStudyDuration: String, CaseIterable, Codable, Identifiable {
    case threeMinutes
    case tenMinutes
    case thirtyMinutes
    case sixtyMinutesOrMore

    var id: Self { self }

    var minutes: Int {
        switch self {
        case .threeMinutes: 3
        case .tenMinutes: 10
        case .thirtyMinutes: 30
        case .sixtyMinutesOrMore: 60
        }
    }

    var title: String {
        switch self {
        case .sixtyMinutesOrMore: "60分以上"
        default: "\(minutes)分"
        }
    }
}

struct InitialLearningProfile: Codable, Equatable {
    static let currentRuleVersion = 1

    let purpose: LearningPurpose
    let level: EnglishLevel
    let dailyStudyDuration: DailyStudyDuration
    let initialDeckID: Int
    let initialDeckName: String
    let ruleVersion: Int
}

struct InitialDeckResolution: Equatable {
    let deck: Deck
    let usedFallback: Bool
}

protocol InitialDeckCatalogLoading {
    func load() throws -> [Deck]
}

struct BundledInitialDeckCatalogLoader: InitialDeckCatalogLoading {
    func load() throws -> [Deck] {
        InitialDeckResolver.onboardingCatalog
    }
}

struct InitialDeckResolver {
    static let standardDeck = Deck(
        id: -1,
        deckName: "すべての単語",
        description: "登録済みの単語から学習します"
    )

    static let onboardingCatalog = [
        Deck(id: 1, deckName: "日常英会話 NGSL基礎", description: "日常でよく使う基礎単語"),
        Deck(id: 3, deckName: "TOEIC TSL頻出単語", description: "TOEICでよく使う単語"),
        Deck(id: 4, deckName: "大学受験 学術基礎単語", description: "受験に必要な学術基礎単語")
    ]

    private struct RuleKey: Hashable {
        let purpose: LearningPurpose
        let level: EnglishLevel
    }

    private static let preferredNames: [RuleKey: [String]] = [
        RuleKey(purpose: .toeic, level: .beginner): ["TOEIC 初心者", "TOEIC 基礎", "TOEIC"],
        RuleKey(purpose: .toeic, level: .intermediate): ["TOEIC 中級", "TOEIC 標準", "TOEIC"],
        RuleKey(purpose: .toeic, level: .advanced): ["TOEIC 上級", "TOEIC 発展", "TOEIC"],
        RuleKey(purpose: .entranceExam, level: .beginner): ["受験 初心者", "受験 基礎", "大学受験"],
        RuleKey(purpose: .entranceExam, level: .intermediate): ["受験 中級", "受験 標準", "大学受験"],
        RuleKey(purpose: .entranceExam, level: .advanced): ["受験 上級", "受験 発展", "大学受験"],
        RuleKey(purpose: .dailyConversation, level: .beginner): ["日常英会話 初心者", "日常英会話 基礎", "日常英会話"],
        RuleKey(purpose: .dailyConversation, level: .intermediate): ["日常英会話 中級", "日常英会話 標準", "日常英会話"],
        RuleKey(purpose: .dailyConversation, level: .advanced): ["日常英会話 上級", "日常英会話 発展", "日常英会話"]
    ]

    func resolve(purpose: LearningPurpose, level: EnglishLevel, availableDecks: [Deck]) -> Deck {
        resolution(purpose: purpose, level: level, availableDecks: availableDecks).deck
    }

    func resolution(
        purpose: LearningPurpose,
        level: EnglishLevel,
        availableDecks: [Deck]
    ) -> InitialDeckResolution {
        let decks = availableDecks.sorted { $0.id < $1.id }
        let preferred = Self.preferredNames[RuleKey(purpose: purpose, level: level)] ?? []

        for preferredName in preferred {
            if let deck = decks.first(where: { normalized($0.deckName).contains(normalized(preferredName)) }) {
                return InitialDeckResolution(deck: deck, usedFallback: false)
            }
        }

        let fallback = decks.first(where: isStandardDeck) ?? decks.first ?? Self.standardDeck
        return InitialDeckResolution(deck: fallback, usedFallback: true)
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: " ", with: "")
    }

    private func isStandardDeck(_ deck: Deck) -> Bool {
        let name = normalized(deck.deckName)
        return name.contains("標準") || name.contains("基礎") || name.contains("すべて")
    }
}

enum InitialLearningProfileStoreError: LocalizedError {
    case couldNotPersist

    var errorDescription: String? {
        "初期設定を保存できませんでした。もう一度お試しください。"
    }
}

protocol InitialLearningProfileStoring {
    func load() -> InitialLearningProfile?
    func save(_ profile: InitialLearningProfile) throws
    func clear()
}

struct InitialLearningProfileStore: InitialLearningProfileStoring {
    private enum Keys {
        static let profile = "initialLearningProfile"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> InitialLearningProfile? {
        guard let data = defaults.data(forKey: Keys.profile) else { return nil }
        return try? JSONDecoder().decode(InitialLearningProfile.self, from: data)
    }

    func save(_ profile: InitialLearningProfile) throws {
        let data = try JSONEncoder().encode(profile)
        defaults.set(data, forKey: Keys.profile)
        guard load() == profile else { throw InitialLearningProfileStoreError.couldNotPersist }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.profile)
    }
}
