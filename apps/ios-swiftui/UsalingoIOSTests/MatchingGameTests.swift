import XCTest
@testable import UsalingoIOS

final class MatchingGameTests: XCTestCase {
    func testBoardStartsWithSixPairsInTwelveSlots() {
        let game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        let tiles = game.slots.compactMap { $0 }
        XCTAssertEqual(tiles.count, 12)
        XCTAssertEqual(Set(tiles.map(\.cardId)).count, 6)
        XCTAssertEqual(tiles.filter { $0.face == .english }.count, 6)
        XCTAssertEqual(tiles.filter { $0.face == .japanese }.count, 6)
    }

    func testSmallDeckFillsOnlyWhatItHas() {
        let game = MatchingGame(words: makeWords(count: 2), shufflesOrder: false)
        XCTAssertEqual(game.slots.compactMap { $0 }.count, 4)
        XCTAssertFalse(game.isFinished)
    }

    func testFirstTryMatchIsCorrectAndMissedWordIsNot() {
        var game = MatchingGame(words: makeWords(count: 6), shufflesOrder: false)
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 1, face: .english)), .revealed)
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 1, face: .japanese)), .matched(cardId: 1, isCorrect: true))

        // 2 と 3 を取り違える。どちらも「一度ミスした語」になる。
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 2, face: .english)), .revealed)
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 3, face: .japanese)), .mismatched)
        game.hideRevealed()

        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 2, face: .english)), .revealed)
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 2, face: .japanese)), .matched(cardId: 2, isCorrect: false))
    }

    func testTapsAreIgnoredWhileMismatchedTilesAreShown() {
        var game = MatchingGame(words: makeWords(count: 6), shufflesOrder: false)
        _ = game.flip(tileId: tileId(game, cardId: 1, face: .english))
        _ = game.flip(tileId: tileId(game, cardId: 2, face: .japanese))
        XCTAssertTrue(game.isAwaitingHide)
        XCTAssertEqual(game.flip(tileId: tileId(game, cardId: 3, face: .english)), .ignored)
    }

    func testFourClearedPairsRefillEmptySlotsWithoutMovingRemainingTiles() {
        var game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        // 消さずに残る 5 と 6 が、補充のあとも同じマスに居ることを確かめる。
        let keptBefore = game.slots.enumerated().compactMap { slot, tile -> (Int, Int)? in
            guard let tile, tile.cardId == 5 || tile.cardId == 6 else { return nil }
            return (slot, tile.id)
        }
        XCTAssertEqual(keptBefore.count, 4)

        clearPairs(1...4, in: &game)

        let filled = game.slots.compactMap { $0 }
        XCTAssertEqual(filled.count, 12, "4ペア消えたら空いた8マスがまとめて埋まる")
        XCTAssertEqual(Set(filled.map(\.cardId)).count, 6)
        for (slot, tileId) in keptBefore {
            XCTAssertEqual(game.slots[slot]?.id, tileId, "残っている札の位置は動かさない")
        }
    }

    func testBoardDoesNotRefillBeforeFourPairsAreCleared() {
        var game = MatchingGame(words: makeWords(count: 20), shufflesOrder: false)
        clearPairs(1...3, in: &game)
        XCTAssertEqual(game.slots.compactMap { $0 }.count, 6, "3ペアまでは空きマスのまま")
    }

    func testGameFinishesAfterEveryWordHasBeenCleared() {
        var game = MatchingGame(words: makeWords(count: 8), shufflesOrder: false)
        for cardId in 1...8 {
            _ = game.flip(tileId: tileId(game, cardId: cardId, face: .english))
            _ = game.flip(tileId: tileId(game, cardId: cardId, face: .japanese))
        }
        XCTAssertTrue(game.isFinished)
        XCTAssertEqual(game.flip(tileId: 0), .ignored)
    }

    // MARK: - ヘルパー

    private func clearPairs(_ cardIds: ClosedRange<Int>, in game: inout MatchingGame) {
        for cardId in cardIds {
            _ = game.flip(tileId: tileId(game, cardId: cardId, face: .english))
            _ = game.flip(tileId: tileId(game, cardId: cardId, face: .japanese))
        }
    }

    private func tileId(_ game: MatchingGame, cardId: Int, face: MatchingGame.Face) -> Int {
        let tile = game.slots.compactMap { $0 }.first { $0.cardId == cardId && $0.face == face }
        XCTAssertNotNil(tile, "盤に card \(cardId) の \(face) がない")
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
