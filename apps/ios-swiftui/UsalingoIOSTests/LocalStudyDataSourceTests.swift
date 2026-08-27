import XCTest
@testable import UsalingoIOS

final class LocalStudyDataSourceTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalStudyDataSourceTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testImportedDeckProvidesNewCardQueue() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))

        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)

        XCTAssertEqual(queue.count, 3)
        XCTAssertTrue(queue.allSatisfy { $0.learning == nil })
        XCTAssertEqual(queue.map(\.text), ["word-1", "word-2", "word-3"])
        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts, LocalDeckCounts(newCount: 3, dueCount: 0))
    }

    func testAnswerPersistsAcrossInstances() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        let saved = try await dataSource.saveAnswerWithUndo(card: card, isCorrect: true)
        XCTAssertNil(saved.previousProgress)
        XCTAssertEqual(saved.progress.repetitions, 1)
        XCTAssertEqual(saved.progress.userId, LocalStudyDataSource.guestUserId)

        // 再起動相当: 同じディレクトリから新しいインスタンスを作る。
        let reopened = makeDataSource()
        let counts = try reopened.counts(deckId: deck.id)
        XCTAssertEqual(counts.newCount, 2)
        let reloaded = try await reopened.fetchStudyQueue(deckId: deck.id, mode: .all)
        let studied = try XCTUnwrap(reloaded.first { $0.id == card.id })
        XCTAssertEqual(studied.learning?.repetitions, 1)
        XCTAssertEqual(studied.learning?.nextReviewDate, saved.progress.nextReviewDate)
    }

    func testUndoRemovesFirstAnswer() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        let saved = try await dataSource.saveAnswerWithUndo(card: card, isCorrect: false)
        try await dataSource.restoreLearningProgress(
            cardId: try XCTUnwrap(card.cardId),
            previousProgress: saved.previousProgress
        )

        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts.newCount, 2)
    }

    func testDueCardComesFirstInQueue() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let lastCard = try XCTUnwrap(queue.last)
        let cardId = try XCTUnwrap(lastCard.cardId)

        // 期限切れの進捗を注入する。restoreLearningProgress は任意の進捗を書き戻せる。
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let overdue = LearningProgress
            .initial(userId: LocalStudyDataSource.guestUserId, cardId: cardId, now: threeDaysAgo)
            .marking(isCorrect: true, now: threeDaysAgo)
        try await dataSource.restoreLearningProgress(cardId: cardId, previousProgress: overdue)

        let reloaded = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        XCTAssertEqual(reloaded.first?.id, lastCard.id)
        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts, LocalDeckCounts(newCount: 2, dueCount: 1))

        let reviewOnly = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .reviewOnly)
        XCTAssertEqual(reviewOnly.map(\.id), [lastCard.id])
    }

    func testTagsAndWordOverridePersist() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 1))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        try await dataSource.saveTags(["重要", "苦手"], wordId: card.wordId)
        let edited = try await dataSource.saveWordOverride(
            WordOverridePayload(
                wordId: card.wordId,
                wordText: "edited",
                definitionJapanese: "編集済み",
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil
            )
        )
        XCTAssertEqual(edited.text, "edited")

        let reopened = makeDataSource()
        let tags = try await reopened.fetchTags(wordId: card.wordId)
        XCTAssertEqual(tags, ["苦手", "重要"])
        let reloaded = try await reopened.fetchStudyQueue(deckId: deck.id, mode: .all)
        XCTAssertEqual(reloaded.first?.text, "edited")
        XCTAssertEqual(reloaded.first?.meaning, "編集済み")
    }

    func testCardIdsStayStableWhenDeckShrinks() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let originalIds = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all).map(\.id)

        // 語数を減らしたJSONへ差し替えても、残った単語のIDは変わらない。
        try dataSource.removeDecks(atOffsets: IndexSet(integer: 0))
        let replaced = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))
        let replacedIds = try await dataSource.fetchStudyQueue(deckId: replaced.id, mode: .all).map(\.id)

        XCTAssertEqual(replacedIds, Array(originalIds.prefix(2)))
    }

    func testImportRejectsInvalidDeckFiles() throws {
        let dataSource = makeDataSource()

        XCTAssertThrowsError(try dataSource.importDeck(from: Data("not json".utf8))) { error in
            XCTAssertEqual(error as? DeckFileError, .unreadable)
        }
        XCTAssertThrowsError(try dataSource.importDeck(from: sampleDeckData(formatVersion: 2))) { error in
            XCTAssertEqual(error as? DeckFileError, .unsupportedFormatVersion(2))
        }
        XCTAssertThrowsError(try dataSource.importDeck(from: duplicateCardIdDeckData())) { error in
            XCTAssertEqual(error as? DeckFileError, .duplicateCardIds([1]))
        }

        _ = try dataSource.importDeck(from: sampleDeckData())
        XCTAssertThrowsError(try dataSource.importDeck(from: sampleDeckData())) { error in
            XCTAssertEqual(error as? LocalStudyError, .duplicateDeckKey("sample"))
        }
    }

    func testExportedDeckRoundTrips() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))

        let exported = try dataSource.exportData(deckId: deck.id)
        let decoded = try DeckFile.decode(from: exported)

        XCTAssertEqual(decoded, try DeckFile.decode(from: sampleDeckData(cardCount: 2)))
    }

    // MARK: - Helpers

    private func makeDataSource() -> LocalStudyDataSource {
        LocalStudyDataSource(directoryURL: directoryURL, bundle: Bundle(for: Self.self))
    }

    private func sampleDeckData(cardCount: Int = 3, deckId: String = "sample", formatVersion: Int = 1) -> Data {
        let cards = (1...max(1, cardCount)).map { index in
            """
            {
                "id": \(index),
                "text": "word-\(index)",
                "meaning": "意味\(index)",
                "partOfSpeech": null,
                "sentenceEnglish": null,
                "sentenceJapanese": null,
                "imageAssetPath": null,
                "audioAssetPath": null,
                "tags": null
            }
            """
        }
        let json = """
        {
            "formatVersion": \(formatVersion),
            "deckId": "\(deckId)",
            "deckName": "テストデッキ",
            "description": "テスト用",
            "cards": [\(cards.joined(separator: ","))]
        }
        """
        return Data(json.utf8)
    }

    private func duplicateCardIdDeckData() -> Data {
        Data("""
        {
            "formatVersion": 1,
            "deckId": "duplicated",
            "deckName": "重複",
            "description": null,
            "cards": [
                {"id": 1, "text": "a", "meaning": "あ"},
                {"id": 1, "text": "b", "meaning": "い"}
            ]
        }
        """.utf8)
    }
}
