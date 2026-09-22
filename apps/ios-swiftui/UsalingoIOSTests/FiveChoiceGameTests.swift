import SwiftUI
import XCTest
@testable import UsalingoIOS

final class FiveChoiceGameTests: XCTestCase {
    func testFiveUniqueChoicesIncludeCorrectCardAndAllItsMeanings() throws {
        let target = word(1, meanings: ["一致", "合意", "与える"])
        let game = FiveChoiceGame(cards: [target], candidates: [target] + words(2...8))
        let question = try XCTUnwrap(game.question)
        XCTAssertEqual(question.choices.count, 5)
        XCTAssertEqual(Set(question.choices.map(\.wordId)).count, 5)
        XCTAssertEqual(question.choices[question.correctIndex], target)
        XCTAssertEqual(question.choices[question.correctIndex].meaning, "一致／合意／与える")
    }

    func testSameWordMeaningOverlapAndSynonymsInEitherDirectionAreExcluded() throws {
        let target = word(1, text: "accord", meanings: ["一致", "与える"], synonyms: [
            WordSynonym(word: "agree", meaning: "同意する")
        ])
        let excluded = [
            word(2, text: " ＡＣＣＯＲＤ "),
            word(3, meanings: ["別の意味", "一 致"]),
            word(4, meanings: ["付与する、与える"]),
            word(5, text: "Agree"),
            word(6, meanings: ["同意する"]),
            word(7, synonyms: [WordSynonym(word: "accord", meaning: "")]),
            word(8, synonyms: [WordSynonym(word: "something", meaning: "一致")]),
            word(9, text: " \n"),
            word(10, meanings: [" ／ "])
        ]
        let safe = words(20...23)
        let game = FiveChoiceGame(cards: [target], candidates: excluded + safe, shufflesOrder: false)
        XCTAssertEqual(try XCTUnwrap(game.question).choices.map(\.id), [1, 20, 21, 22, 23])
    }

    func testDuplicateDistractorsAcrossDecksDoNotFillMultipleSlots() throws {
        let original = word(2)
        let anotherCardForSameWord = original.withCardId(200)
        let candidates = [original, anotherCardForSameWord, word(3, text: original.text),
                          word(4, meanings: [original.meaning])] + words(5...7)
        let game = FiveChoiceGame(cards: [word(1)], candidates: candidates, shufflesOrder: false)
        XCTAssertEqual(try XCTUnwrap(game.question).choices.map(\.id), [1, 2, 5, 6, 7])
    }

    func testInsufficientQuestionIsSkippedAndNextValidQuestionIsUsed() throws {
        let unavailable = word(1, meanings: ["意味20", "意味21"])
        let valid = word(2)
        let game = FiveChoiceGame(cards: [unavailable, valid], candidates: words(20...23), shufflesOrder: false)
        XCTAssertEqual(game.skippedCount, 1)
        XCTAssertEqual(try XCTUnwrap(game.question).card.id, valid.id)
    }

    func testEmptyAndInsufficientPoolsFinishWithoutRecordingAnswers() {
        for pool in [[], words(2...4)] {
            var game = FiveChoiceGame(cards: [word(1)], candidates: pool)
            XCTAssertTrue(game.isFinished)
            XCTAssertEqual(game.skippedCount, 1)
            XCTAssertNil(game.answer(at: 0))
            XCTAssertEqual(game.answeredCount, 0)
        }
        XCTAssertTrue(FiveChoiceGame(cards: [], candidates: words(1...5)).isFinished)
    }

    func testSelectionRevealsWithoutAdvancingOrReshufflingAndCannotBeChanged() throws {
        var game = FiveChoiceGame(cards: words(1...2), candidates: words(1...7))
        let question = try XCTUnwrap(game.question)
        game.advance()
        XCTAssertEqual(game.question?.card.id, question.card.id, "未回答では次へ進めない")
        XCTAssertNil(game.answer(at: -1))
        XCTAssertNil(game.answer(at: 5))
        XCTAssertEqual(game.answer(at: question.correctIndex), true)
        XCTAssertEqual(game.question?.choices, question.choices)
        XCTAssertEqual(game.question?.card.id, question.card.id)
        XCTAssertTrue(game.isRevealed)
        XCTAssertNil(game.answer(at: (question.correctIndex + 1) % 5))
        XCTAssertEqual(game.answeredCount, 1)
        game.advance()
        XCTAssertNotEqual(game.question?.card.id, question.card.id)
        XCTAssertFalse(game.isRevealed)
    }

    func testOnePassUsesOnlySelectedDeckAndDoesNotRepeatMisses() throws {
        let selected = words(1...8)
        var game = FiveChoiceGame(cards: selected + [selected[0]], candidates: words(1...20))
        var seen: [Int] = []
        while let question = game.question {
            seen.append(question.card.id)
            XCTAssertEqual(game.answer(at: (question.correctIndex + 1) % 5), false)
            game.advance()
            XCTAssertLessThanOrEqual(seen.count, selected.count)
        }
        XCTAssertEqual(Set(seen), Set(selected.map(\.id)))
        XCTAssertEqual(seen.count, selected.count)
        XCTAssertEqual(game.answeredCount, selected.count)
    }

    func testLoadingFetchesOnlyAddedDecksAndUsesTheirFullCards() async throws {
        let source = ChoiceTestSource()
        source.decks = [Deck(id: 1, deckName: "出題", description: nil), Deck(id: 2, deckName: "追加済み", description: nil)]
        source.cards = [1: [word(1)], 2: words(2...5), 99: words(90...100)]
        let game = try await FiveChoiceGame.load(deckId: 1, source: source)
        XCTAssertEqual(source.fetchedDeckIds, [1, 2])
        XCTAssertEqual(Set(try XCTUnwrap(game.question).choices.map(\.id)), Set(1...5))
        XCTAssertEqual(game.question?.card.id, 1)
        XCTAssertEqual(source.wordListFetches, 0)
        XCTAssertEqual(source.studyQueueFetches, 0, "復習期限やキューの件数制限で1周の対象を削らない")
    }

    func testMissingSelectedDeckAndFailedCandidateFetchDoNotSilentlyUsePartialPool() async {
        let source = ChoiceTestSource()
        do {
            _ = try await FiveChoiceGame.load(deckId: 1, source: source)
            XCTFail("未追加のデッキは開かない")
        } catch { XCTAssertTrue(source.fetchedDeckIds.isEmpty) }
        source.decks = [Deck(id: 1, deckName: "出題", description: nil), Deck(id: 2, deckName: "候補", description: nil)]
        source.cards = [1: words(1...5)]
        source.failingDeckId = 2
        do {
            _ = try await FiveChoiceGame.load(deckId: 1, source: source)
            XCTFail("取得失敗は候補不足と混同しない")
        } catch { XCTAssertEqual(source.fetchedDeckIds, [1, 2]) }
    }

    @MainActor
    func testSharedSaveQueueRetriesSameAttemptAndSavesOnlyQuestionCardsInOrder() async throws {
        let source = ChoiceTestSource()
        source.failFirstSave = true
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = AppState(restoresSession: false, localStudy: LocalStudyDataSource(directoryURL: directory))
        var queue = StudyAnswerQueue()
        var error: String?
        var game = FiveChoiceGame(cards: words(1...2), candidates: words(1...6), shufflesOrder: false)
        for isCorrect in [false, true] {
            let question = try XCTUnwrap(game.question)
            let answerIndex = isCorrect ? question.correctIndex : (question.correctIndex + 1) % 5
            let result = try XCTUnwrap(game.answer(at: answerIndex))
            queue.enqueue(cardIndex: game.answeredCount - 1, card: question.card, isCorrect: result)
            game.advance()
        }
        let queueBinding = Binding(get: { queue }, set: { queue = $0 })
        let errorBinding = Binding(get: { error }, set: { error = $0 })
        drainStudyAnswerQueue(queueBinding, appState: state, saveErrorMessage: errorBinding, source: source)
        for _ in 0..<100 where queue.isDraining { await Task.yield() }
        XCTAssertNotNil(error)
        XCTAssertEqual(queue.pending.count, 2)
        XCTAssertEqual(source.saved.map(\.0), [1])

        drainStudyAnswerQueue(queueBinding, appState: state, saveErrorMessage: errorBinding, source: source)
        // 連続した排出要求でも同じ回答を二重に送らない。
        drainStudyAnswerQueue(queueBinding, appState: state, saveErrorMessage: errorBinding, source: source)
        for _ in 0..<100 where queue.isDraining { await Task.yield() }
        XCTAssertNil(error)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(source.saved.map(\.0), [1, 1, 2])
        XCTAssertEqual(source.saved.map(\.1), [false, false, true])
        XCTAssertTrue(source.attempts[0] === source.attempts[1])
        XCTAssertFalse(source.attempts[1] === source.attempts[2])
    }

    private func words(_ range: ClosedRange<Int>) -> [WordCard] { range.map { word($0) } }

    private func word(_ id: Int, text: String? = nil, meanings: [String]? = nil, synonyms: [WordSynonym] = []) -> WordCard {
        WordCard(id: id, cardId: id, text: text ?? "word\(id)",
                 senses: (meanings ?? ["意味\(id)"]).map { WordSense(meaning: $0, partOfSpeech: "noun") },
                 sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil, audioAssetPath: nil,
                 tags: [], learningStatus: nil, learning: nil, synonyms: synonyms)
    }
}

private final class ChoiceTestSource: StudyDataSource {
    var decks: [Deck] = []
    var cards: [Int: [WordCard]] = [:]
    var fetchedDeckIds: [Int] = []
    var wordListFetches = 0
    var studyQueueFetches = 0
    var failingDeckId: Int?
    var failFirstSave = false
    var saved: [(Int, Bool)] = []
    var attempts: [AnswerSaveAttempt] = []

    func fetchDecks() async throws -> [Deck] { decks }
    func fetchCards(deckId: Int) async throws -> [WordCard] {
        fetchedDeckIds.append(deckId)
        if deckId == failingDeckId { throw URLError(.notConnectedToInternet) }
        return cards[deckId] ?? []
    }
    func fetchWordList() async throws -> [WordCard] { wordListFetches += 1; return [] }
    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] { studyQueueFetches += 1; return [] }
    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts { StudyDeckCounts(newCount: 0, dueCount: 0) }
    func fetchStudyStats() async throws -> StudyStats { .empty }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool, attempt: AnswerSaveAttempt) async throws -> SavedAnswer {
        saved.append((card.id, isCorrect))
        attempts.append(attempt)
        if failFirstSave { failFirstSave = false; throw URLError(.networkConnectionLost) }
        return SavedAnswer(progress: LearningProgress.initial(userId: "test", cardId: card.id).marking(isCorrect: isCorrect), previousProgress: nil)
    }
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress { throw LocalStudyError.missingCardId }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer { throw LocalStudyError.missingCardId }
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws { }
    func fetchTags(wordId: Int) async throws -> [String]? { nil }
    func saveTags(_ tags: Set<String>, wordId: Int) async throws { }
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard { throw LocalStudyError.deckNotFound }
    func canManage(_ deck: Deck) -> Bool { false }
    var supportsDeckReordering: Bool { false }
    var supportsDeckFileTransfer: Bool { false }
    func deleteDeck(id: Int) async throws { }
}
