import XCTest
@testable import UsalingoIOS

final class RadioQueueTests: XCTestCase {
    func testCardsMissingEitherAudioAreLeftOut() {
        let queue = RadioQueue(
            cards: [
                makeCard(id: 1),
                makeCard(id: 2, wordAudio: nil),
                makeCard(id: 3, sentenceAudio: nil),
                makeCard(id: 4)
            ],
            shufflesEachLap: false
        )
        XCTAssertEqual(queue.cards.map(\.id), [1, 4])
    }

    func testQueueIsEmptyWhenNoCardHasBothAudioFiles() {
        let queue = RadioQueue(cards: [makeCard(id: 1, wordAudio: nil)], shufflesEachLap: false)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.current)
        XCTAssertTrue(queue.currentSteps.isEmpty)
    }

    func testStepsRunFromWordThroughMeaningToSentence() {
        let queue = RadioQueue(cards: [makeCard(id: 1)], shufflesEachLap: false)
        XCTAssertEqual(
            queue.currentSteps,
            [
                .word(URL(string: "https://example.com/word1.mp3")!),
                .meaning("意味1"),
                .sentence(URL(string: "https://example.com/sentence1.mp3")!)
            ]
        )
    }

    func testPreviousAndNextWrapAroundTheLap() {
        var queue = RadioQueue(cards: [makeCard(id: 1), makeCard(id: 2), makeCard(id: 3)], shufflesEachLap: false)
        XCTAssertEqual(queue.previous?.id, 3)
        XCTAssertEqual(queue.next?.id, 2)

        queue.advance()
        XCTAssertEqual(queue.previous?.id, 1)
        XCTAssertEqual(queue.next?.id, 3)
    }

    func testPreviousAndNextAreNilWhenNothingIsPlayable() {
        let queue = RadioQueue(cards: [makeCard(id: 1, wordAudio: nil)], shufflesEachLap: false)
        XCTAssertNil(queue.previous)
        XCTAssertNil(queue.next)
    }

    func testMeaningIsSkippedWhenTheCardHasNoJapanese() {
        let queue = RadioQueue(cards: [makeCard(id: 1, meaning: "  ")], shufflesEachLap: false)
        XCTAssertEqual(queue.currentSteps.count, 2)
        XCTAssertEqual(queue.currentSteps.first, .word(URL(string: "https://example.com/word1.mp3")!))
    }

    func testAdvanceWrapsBackToTheStartAndKeepsPlaying() {
        var queue = RadioQueue(cards: [makeCard(id: 1), makeCard(id: 2)], shufflesEachLap: false)
        queue.advance()
        XCTAssertEqual(queue.current?.id, 2)
        queue.advance()
        XCTAssertEqual(queue.current?.id, 1, "一周したら止めずに先頭へ戻る")
    }

    func testRewindWrapsToTheLastCard() {
        var queue = RadioQueue(cards: [makeCard(id: 1), makeCard(id: 2)], shufflesEachLap: false)
        queue.rewind()
        XCTAssertEqual(queue.current?.id, 2)
    }

    func testAdvanceOnEmptyQueueDoesNothing() {
        var queue = RadioQueue(cards: [], shufflesEachLap: false)
        queue.advance()
        queue.rewind()
        XCTAssertNil(queue.current)
    }

    func testRelativeCardsContinueOutsideTheVisibleThree() {
        let queue = RadioQueue(
            cards: [makeCard(id: 1), makeCard(id: 2), makeCard(id: 3), makeCard(id: 4)],
            shufflesEachLap: false
        )

        XCTAssertEqual(queue.card(relativeOffset: -1)?.id, 4)
        XCTAssertEqual(queue.card(relativeOffset: 0)?.id, 1)
        XCTAssertEqual(queue.card(relativeOffset: 1)?.id, 2)
        XCTAssertEqual(queue.card(relativeOffset: 2)?.id, 3)
    }

    func testCardShownAfterLastMatchesCardActuallyPlayedNext() {
        var queue = RadioQueue(
            cards: [makeCard(id: 1), makeCard(id: 2), makeCard(id: 3), makeCard(id: 4)],
            shufflesEachLap: true
        )
        for _ in 1..<queue.cards.count { queue.advance() }
        let shownNextID = queue.next?.id

        queue.advance()

        XCTAssertEqual(queue.current?.id, shownNextID)
    }

    func testRewindAcrossLapReturnsToTheCardThatWasActuallyShown() {
        var queue = RadioQueue(
            cards: [makeCard(id: 1), makeCard(id: 2), makeCard(id: 3)],
            shufflesEachLap: true
        )
        for _ in 1..<queue.cards.count { queue.advance() }
        let previousLapLastID = queue.current?.id
        queue.advance()

        queue.rewind()

        XCTAssertEqual(queue.current?.id, previousLapLastID)
    }

    private func makeCard(
        id: Int,
        meaning: String? = nil,
        wordAudio: String? = "default",
        sentenceAudio: String? = "default"
    ) -> WordCard {
        WordCard(
            id: id,
            text: "word\(id)",
            meaning: meaning ?? "意味\(id)",
            partOfSpeech: nil,
            sentenceEnglish: "sentence\(id)",
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: sentenceAudio.map { _ in "https://example.com/sentence\(id).mp3" },
            wordAudioAssetPath: wordAudio.map { _ in "https://example.com/word\(id).mp3" },
            tags: [],
            learningStatus: nil,
            learning: nil
        )
    }
}
