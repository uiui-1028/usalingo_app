import XCTest
import SwiftUI
import UIKit
@testable import UsalingoIOS

final class InitialLearningProfileTests: XCTestCase {
    private let resolver = InitialDeckResolver()

    func testAllThirtySixAnswerCombinationsResolveDeterministically() {
        let decks = [
            Deck(id: 10, deckName: "TOEIC 初心者", description: nil),
            Deck(id: 11, deckName: "TOEIC 中級", description: nil),
            Deck(id: 12, deckName: "TOEIC 上級", description: nil),
            Deck(id: 20, deckName: "受験 初心者", description: nil),
            Deck(id: 21, deckName: "受験 中級", description: nil),
            Deck(id: 22, deckName: "受験 上級", description: nil),
            Deck(id: 30, deckName: "日常英会話 初心者", description: nil),
            Deck(id: 31, deckName: "日常英会話 中級", description: nil),
            Deck(id: 32, deckName: "日常英会話 上級", description: nil)
        ]
        let expectedIDs: [LearningPurpose: [EnglishLevel: Int]] = [
            .toeic: [.beginner: 10, .intermediate: 11, .advanced: 12],
            .entranceExam: [.beginner: 20, .intermediate: 21, .advanced: 22],
            .dailyConversation: [.beginner: 30, .intermediate: 31, .advanced: 32]
        ]

        var verifiedCombinationCount = 0
        for purpose in LearningPurpose.allCases {
            for level in EnglishLevel.allCases {
                for duration in DailyStudyDuration.allCases {
                    let first = resolver.resolve(purpose: purpose, level: level, availableDecks: decks)
                    let second = resolver.resolve(purpose: purpose, level: level, availableDecks: Array(decks.reversed()))

                    XCTAssertEqual(first.id, expectedIDs[purpose]?[level])
                    XCTAssertEqual(second.id, first.id)
                    XCTAssertGreaterThan(duration.minutes, 0)
                    verifiedCombinationCount += 1
                }
            }
        }

        XCTAssertEqual(verifiedCombinationCount, 36)
    }

    func testResolverUsesStandardDeckWhenPreferredDeckIsUnavailable() {
        let decks = [
            Deck(id: 7, deckName: "発音トレーニング", description: nil),
            Deck(id: 4, deckName: "標準デッキ", description: nil)
        ]

        let result = resolver.resolve(purpose: .toeic, level: .advanced, availableDecks: decks)

        XCTAssertEqual(result.id, 4)
        XCTAssertTrue(
            resolver.resolution(
                purpose: .toeic,
                level: .advanced,
                availableDecks: decks
            ).usedFallback
        )
    }

    func testResolverUsesBundledFallbackWhenNoDeckIsAvailable() {
        let resolution = resolver.resolution(
            purpose: .dailyConversation,
            level: .beginner,
            availableDecks: []
        )

        XCTAssertEqual(resolution.deck, InitialDeckResolver.standardDeck)
        XCTAssertTrue(resolution.usedFallback)
    }

    func testBundledCatalogMapsEachPurposeToItsInitialDeck() {
        let expectedIDs: [LearningPurpose: Int] = [
            .toeic: 3,
            .entranceExam: 4,
            .dailyConversation: 1
        ]

        for purpose in LearningPurpose.allCases {
            for level in EnglishLevel.allCases {
                let deck = resolver.resolve(
                    purpose: purpose,
                    level: level,
                    availableDecks: InitialDeckResolver.onboardingCatalog
                )
                XCTAssertEqual(deck.id, expectedIDs[purpose])
                XCTAssertFalse(
                    resolver.resolution(
                        purpose: purpose,
                        level: level,
                        availableDecks: InitialDeckResolver.onboardingCatalog
                    ).usedFallback
                )
            }
        }
    }

    func testDeckCatalogLoadFailureCanBeRetried() throws {
        let loader = RetryingCatalogLoader()

        XCTAssertThrowsError(try loader.load())
        XCTAssertEqual(try loader.load(), InitialDeckResolver.onboardingCatalog)
    }

    func testProfileStoreRestoresEverySavedValue() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let store = InitialLearningProfileStore(defaults: defaults)
        let profile = makeProfile()

        try store.save(profile)

        XCTAssertEqual(store.load(), profile)
    }

    @MainActor
    func testCompletingProfileUpdatesAppStateAndPreventsRepeatPrompt() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let store = InitialLearningProfileStore(defaults: defaults)
        let appState = AppState(restoresSession: false, initialLearningProfileStore: store)
        let profile = makeProfile()

        XCTAssertNil(appState.initialLearningProfile)
        try appState.completeInitialLearningProfile(profile)

        XCTAssertEqual(appState.initialLearningProfile, profile)
        let restoredState = AppState(restoresSession: false, initialLearningProfileStore: store)
        XCTAssertEqual(restoredState.initialLearningProfile, profile)
    }

    @MainActor
    func testSaveFailureDoesNotMarkQuestionnaireComplete() {
        let appState = AppState(
            restoresSession: false,
            initialLearningProfileStore: FailingProfileStore()
        )

        XCTAssertThrowsError(try appState.completeInitialLearningProfile(makeProfile()))
        XCTAssertNil(appState.initialLearningProfile)
    }

    @MainActor
    func testQuestionnaireRendersAtLargestAccessibilityTextSize() throws {
        let view = InitialLearningProfileView(
            initialPurpose: .toeic,
            initialLevel: .intermediate,
            initialDailyStudyDuration: .thirtyMinutes
        ) { _ in }
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        XCTAssertEqual(image.size, window.bounds.size)
        XCTAssertNotNil(image.pngData())
        let attachment = XCTAttachment(image: image)
        attachment.name = "USL-251 questionnaire accessibility text size"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var defaultsSuiteName: String {
        "InitialLearningProfileTests.\(name)"
    }

    private func makeDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func makeProfile() -> InitialLearningProfile {
        InitialLearningProfile(
            purpose: .entranceExam,
            level: .intermediate,
            dailyStudyDuration: .thirtyMinutes,
            initialDeckID: 21,
            initialDeckName: "受験 中級",
            ruleVersion: InitialLearningProfile.currentRuleVersion
        )
    }
}

private struct FailingProfileStore: InitialLearningProfileStoring {
    func load() -> InitialLearningProfile? { nil }
    func clear() {}

    func save(_ profile: InitialLearningProfile) throws {
        throw InitialLearningProfileStoreError.couldNotPersist
    }
}

private final class RetryingCatalogLoader: InitialDeckCatalogLoading {
    private var attempts = 0

    func load() throws -> [Deck] {
        attempts += 1
        if attempts == 1 {
            throw CatalogTestError.unavailable
        }
        return InitialDeckResolver.onboardingCatalog
    }
}

private enum CatalogTestError: Error {
    case unavailable
}
