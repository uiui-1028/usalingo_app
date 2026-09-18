import XCTest
@testable import UsalingoIOS

final class DeckProgressSummaryTests: XCTestCase {
    func testTenCardDeckWithThreeMasteredShowsThreeAndThirtyPercent() {
        let cards = (1...10).map { id in
            makeCard(id: id, status: id <= 3 ? "mastered" : nil)
        }

        let summary = DeckProgressSummary(cards: cards)

        XCTAssertEqual(summary.totalCount, 10)
        XCTAssertEqual(summary.masteredCount, 3)
        XCTAssertEqual(summary.masteryRatio, 0.3, accuracy: 0.0001)
        XCTAssertEqual(summary.masteryPercentText, "30%")
    }

    func testEachCardIsCountedOnceSoChipsAddUpToTotal() {
        let cards = [
            makeCard(id: 1, status: "mastered"),
            makeCard(id: 2, status: "learning"),
            makeCard(id: 3, status: "learning", incorrectCount: LearningProgress.weakIncorrectCountThreshold),
            makeCard(id: 4, status: nil)
        ]

        let summary = DeckProgressSummary(cards: cards)

        XCTAssertEqual(summary.masteredCount, 1)
        XCTAssertEqual(summary.learningCount, 1)
        XCTAssertEqual(summary.weakCount, 1)
        XCTAssertEqual(summary.untouchedCount, 1)
        XCTAssertEqual(
            summary.masteredCount + summary.learningCount + summary.weakCount + summary.untouchedCount,
            summary.totalCount
        )
    }

    /// 苦手を何度も間違えたまま習得まで進めた札は、習得として1回だけ数える。
    func testMasteredCardIsNotCountedAsWeak() {
        let cards = [
            makeCard(id: 1, status: "mastered", incorrectCount: LearningProgress.weakIncorrectCountThreshold)
        ]

        let summary = DeckProgressSummary(cards: cards)

        XCTAssertEqual(summary.masteredCount, 1)
        XCTAssertEqual(summary.weakCount, 0)
        XCTAssertEqual(summary.untouchedCount, 0)
    }

    func testPreviewWordsComeFromTheDecksOwnCards() {
        let cards = (1...7).map { makeCard(id: $0, text: "word\($0)") }

        let summary = DeckProgressSummary(cards: cards)

        XCTAssertEqual(summary.previewWords, ["word1", "word2", "word3", "word4", "word5"])
    }

    func testEmptyDeckHasNoProgress() {
        let summary = DeckProgressSummary.empty

        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.masteryRatio, 0)
        XCTAssertEqual(summary.masteryPercentText, "0%")
        XCTAssertEqual(summary.untouchedCount, 0)
        XCTAssertTrue(summary.previewWords.isEmpty)
    }

    private func makeCard(
        id: Int,
        text: String = "word",
        status: String? = nil,
        incorrectCount: Int = 0
    ) -> WordCard {
        WordCard(
            id: id,
            text: text,
            meaning: "meaning",
            partOfSpeech: nil,
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: [],
            learningStatus: status,
            learning: status.map { status in
                WordLearningSnapshot(
                    progress: LearningProgress(
                        userId: "user",
                        cardId: id,
                        status: status,
                        lastReviewedAt: nil,
                        nextReviewDate: "2026-09-18T00:00:00Z",
                        srsLevel: 1,
                        easinessFactor: 2.5,
                        repetitions: 1,
                        incorrectCount: incorrectCount,
                        intervalDays: 1,
                        createdAt: nil,
                        updatedAt: "2026-09-18T00:00:00Z"
                    )
                )
            }
        )
    }
}
