import XCTest
@testable import UsalingoIOS

final class WordListFiltersTests: XCTestCase {
    func testWordStatusFilterMatchesLearningStatus() {
        let learning = makeWord(id: 1, learningStatus: "learning")
        let mastered = makeWord(id: 2, learningStatus: "mastered")
        let new = makeWord(id: 3, learningStatus: nil)

        XCTAssertTrue(WordStatusFilter.all.matches(learning))
        XCTAssertTrue(WordStatusFilter.learning.matches(learning))
        XCTAssertFalse(WordStatusFilter.learning.matches(mastered))
        XCTAssertTrue(WordStatusFilter.mastered.matches(mastered))
        XCTAssertTrue(WordStatusFilter.new.matches(new))
        XCTAssertFalse(WordStatusFilter.new.matches(learning))
    }

    func testWordDueFilterSeparatesUnsetDueAndFuture() {
        let unset = makeWord(id: 1, learning: nil)
        let due = makeWord(id: 2, learning: snapshot(nextReviewDate: pastISO8601()))
        let future = makeWord(id: 3, learning: snapshot(nextReviewDate: futureISO8601()))

        XCTAssertTrue(WordDueFilter.all.matches(unset))
        XCTAssertTrue(WordDueFilter.unset.matches(unset))
        XCTAssertFalse(WordDueFilter.unset.matches(due))

        XCTAssertTrue(WordDueFilter.due.matches(due))
        XCTAssertFalse(WordDueFilter.due.matches(future))

        XCTAssertTrue(WordDueFilter.future.matches(future))
        XCTAssertFalse(WordDueFilter.future.matches(due))
    }

    func testWordSortOptionAlphabeticalIgnoresCase() {
        let banana = makeWord(id: 1, text: "banana")
        let apple = makeWord(id: 2, text: "Apple")

        let sorted = WordSortOption.alphabetical.sort([banana, apple])

        XCTAssertEqual(sorted.map(\.text), ["Apple", "banana"])
    }

    func testWordSortOptionStatusOrdersNewThenLearningThenMastered() {
        let mastered = makeWord(id: 1, learningStatus: "mastered")
        let new = makeWord(id: 2, learningStatus: nil)
        let learning = makeWord(id: 3, learningStatus: "learning")

        let sorted = WordSortOption.status.sort([mastered, new, learning])

        XCTAssertEqual(sorted.map(\.id), [new.id, learning.id, mastered.id])
    }

    func testWordSortOptionDueDatePlacesEarliestFirstAndUnsetLast() {
        let earlier = makeWord(id: 1, learning: snapshot(nextReviewDate: pastISO8601()))
        let later = makeWord(id: 2, learning: snapshot(nextReviewDate: futureISO8601()))
        let unset = makeWord(id: 3, learning: nil)

        let sorted = WordSortOption.dueDate.sort([later, unset, earlier])

        XCTAssertEqual(sorted.map(\.id), [earlier.id, later.id, unset.id])
    }

    private func makeWord(
        id: Int,
        text: String = "word",
        learningStatus: String? = nil,
        learning: WordLearningSnapshot? = nil
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
            learningStatus: learningStatus ?? learning?.status,
            learning: learning
        )
    }

    private func snapshot(nextReviewDate: String) -> WordLearningSnapshot {
        WordLearningSnapshot(
            progress: LearningProgress(
                userId: "user",
                cardId: 1,
                status: "learning",
                lastReviewedAt: nil,
                nextReviewDate: nextReviewDate,
                srsLevel: 1,
                easinessFactor: 2.5,
                repetitions: 1,
                incorrectCount: 0,
                intervalDays: 1,
                createdAt: nil,
                updatedAt: nextReviewDate
            )
        )
    }

    private func pastISO8601() -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400))
    }

    private func futureISO8601() -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(86_400))
    }
}
