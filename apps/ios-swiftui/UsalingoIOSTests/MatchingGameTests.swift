import XCTest
@testable import UsalingoIOS

final class MatchingGameTests: XCTestCase {
    func testBoardStartsWithFivePairsSplitIntoTwoColumns() {
        let game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        XCTAssertEqual(game.tiles.count, 10)
        XCTAssertEqual(game.tiles(in: .japanese).compactMap { $0 }.count, 5)
        XCTAssertEqual(game.tiles(in: .english).compactMap { $0 }.count, 5)
        XCTAssertEqual(Set(game.tiles.map(\.cardId)).count, 5)
        XCTAssertTrue(game.tiles.allSatisfy { !$0.isCleared }, "札は最初から全部読める")
    }

    func testEachColumnShowsTheMatchingSideOfTheWord() {
        let game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        XCTAssertEqual(Set(game.tiles(in: .english).compactMap { $0?.text }), Set((1...5).map { "word\($0)" }))
        XCTAssertEqual(Set(game.tiles(in: .japanese).compactMap { $0?.text }), Set((1...5).map { "意味\($0)" }))
    }

    func testSmallDeckFillsOnlyWhatItHas() {
        let game = MatchingGame(words: makeWords(count: 2), shufflesOrder: false)
        XCTAssertEqual(game.tiles.count, 4)
        XCTAssertFalse(game.isFinished)
    }

    func testFirstTryMatchIsCorrectAndMissedWordIsNot() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        XCTAssertEqual(game.tap(tileId: tileId(game, cardId: 1, column: .japanese)), .selected)
        XCTAssertEqual(
            game.tap(tileId: tileId(game, cardId: 1, column: .english)),
            .matched(
                cardId: 1,
                isCorrect: true,
                tileIds: [tileId(game, cardId: 1, column: .japanese), tileId(game, cardId: 1, column: .english)]
            )
        )

        // 2 と 3 を取り違える。どちらも「一度ミスした語」になる。
        _ = game.tap(tileId: tileId(game, cardId: 2, column: .japanese))
        guard case .mismatched = game.tap(tileId: tileId(game, cardId: 3, column: .english)) else {
            return XCTFail("違う組は mismatched になる")
        }

        _ = game.tap(tileId: tileId(game, cardId: 2, column: .japanese))
        guard case .matched(_, let isCorrect, _) = game.tap(tileId: tileId(game, cardId: 2, column: .english)) else {
            return XCTFail("同じ組は matched になる")
        }
        XCTAssertFalse(isCorrect, "一度ミスした語は不正解として記録する")
    }

    func testTappingTheSameColumnTwiceMovesTheSelection() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        let first = tileId(game, cardId: 1, column: .japanese)
        let second = tileId(game, cardId: 2, column: .japanese)
        _ = game.tap(tileId: first)
        XCTAssertEqual(game.tap(tileId: second), .selected)
        XCTAssertEqual(game.selectedTileId, second, "同じ列をもう一度押したら選び直しになる")
    }

    func testTappingTheSelectedTileClearsTheSelection() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        let first = tileId(game, cardId: 1, column: .japanese)
        _ = game.tap(tileId: first)
        _ = game.tap(tileId: first)
        XCTAssertNil(game.selectedTileId)
    }

    func testMatchedTilesStayOnTheBoardFadedAndCannotBeTappedAgain() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        let japanese = tileId(game, cardId: 1, column: .japanese)
        matchPairs(1...1, in: &game)

        XCTAssertEqual(game.tiles.count, 10, "消した札も場所に残す")
        XCTAssertEqual(game.tiles.filter(\.isCleared).count, 2)
        XCTAssertEqual(game.tap(tileId: japanese), .ignored)
    }

    func testThreeClearedPairsRefillTheFadedSlotsWithoutMovingTheRest() {
        var game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        // 消さずに残る 4 と 5 が、補充のあとも同じ場所に居ることを確かめる。
        let keptBefore = keptPositions(in: game, cardIds: [4, 5])
        XCTAssertEqual(keptBefore.count, 4)

        matchPairs(1...3, in: &game)
        XCTAssertTrue(game.needsRefill)
        game.refill()

        XCTAssertFalse(game.needsRefill)
        XCTAssertEqual(game.tiles.filter { !$0.isCleared }.count, 10, "消えた場所へ新しい3組が入る")
        XCTAssertEqual(Set(game.tiles.map(\.cardId)).count, 5)
        for (column, slot, tileId) in keptBefore {
            XCTAssertEqual(game.tiles(in: column)[slot]?.id, tileId, "消えていない札は動かさない")
        }
    }

    func testBoardDoesNotRefillBeforeThreePairsAreCleared() {
        var game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        matchPairs(1...2, in: &game)
        XCTAssertFalse(game.needsRefill)
        game.refill()
        XCTAssertEqual(game.tiles.filter(\.isCleared).count, 4, "2組までは薄いまま残る")
    }

    func testGameFinishesAfterEveryWordHasBeenCleared() {
        var game = MatchingGame(words: makeWords(count: 8), shufflesOrder: false)
        matchPairs(1...3, in: &game)
        game.refill()
        matchPairs(4...8, in: &game)
        XCTAssertTrue(game.isFinished)
    }

    // MARK: - ヘルパー

    private func matchPairs(_ cardIds: ClosedRange<Int>, in game: inout MatchingGame) {
        for cardId in cardIds {
            _ = game.tap(tileId: tileId(game, cardId: cardId, column: .japanese))
            _ = game.tap(tileId: tileId(game, cardId: cardId, column: .english))
        }
    }

    private func keptPositions(
        in game: MatchingGame,
        cardIds: Set<Int>
    ) -> [(MatchingGame.Column, Int, Int)] {
        [MatchingGame.Column.japanese, .english].flatMap { column in
            game.tiles(in: column).enumerated().compactMap { slot, tile -> (MatchingGame.Column, Int, Int)? in
                guard let tile, cardIds.contains(tile.cardId) else { return nil }
                return (column, slot, tile.id)
            }
        }
    }

    func testShuffleMovesTilesWithoutChangingProgress() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        _ = game.tap(tileId: tileId(game, cardId: 1, column: .japanese))
        _ = game.tap(tileId: tileId(game, cardId: 1, column: .english))
        let beforeIds = game.tiles(in: .english).map { $0?.id }

        game.shuffleBoard()

        XCTAssertNil(game.selectedTileId, "選びかけは解除する")
        XCTAssertNotEqual(game.tiles(in: .english).map { $0?.id }, beforeIds, "置き場所は変わる")
        XCTAssertEqual(Set(game.tiles.map(\.cardId)), Set(1...5), "出ている語は変わらない")
        XCTAssertEqual(game.tiles.filter(\.isCleared).map(\.cardId), [1, 1], "消した札はそのまま")
    }

    func testShuffleKeepsClearedTilesInPlace() {
        var game = MatchingGame(words: makeWords(count: 5), shufflesOrder: false)
        _ = game.tap(tileId: tileId(game, cardId: 1, column: .japanese))
        _ = game.tap(tileId: tileId(game, cardId: 1, column: .english))
        let clearedSlots = game.tiles(in: .japanese).indices.filter { game.tiles(in: .japanese)[$0]?.isCleared == true }

        game.shuffleBoard()

        for slot in clearedSlots {
            XCTAssertEqual(game.tiles(in: .japanese)[slot]?.cardId, 1, "薄く残した札は動かさない")
        }
    }

    private func tileId(_ game: MatchingGame, cardId: Int, column: MatchingGame.Column) -> Int {
        let tile = game.tiles.first { $0.cardId == cardId && $0.column == column }
        XCTAssertNotNil(tile, "盤に card \(cardId) の \(column) がない")
        return tile?.id ?? -1
    }

    private func makeWords(count: Int) -> [WordCard] {
        (1...count).map { index in
            WordCard(
                id: index,
                text: "word\(index)",
                meaning: "意味\(index)",
                partOfSpeech: nil,
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil,
                audioAssetPath: nil,
                tags: [],
                learningStatus: nil,
                learning: nil
            )
        }
    }
}
