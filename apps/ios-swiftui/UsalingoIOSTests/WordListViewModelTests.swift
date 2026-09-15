import XCTest
@testable import UsalingoIOS

final class WordListViewModelTests: XCTestCase {
    func testDetailPagingWrapsBothEndsInDisplayedOrder() {
        let words = [makeWord(id: 3, text: "carrot"), makeWord(id: 1, text: "apple"), makeWord(id: 2, text: "banana")]
        var selection = WordDetailSelection(word: words[0], words: words)
        selection.move(by: -1)
        XCTAssertEqual(selection.current.id, 2)
        selection.move(by: 1)
        XCTAssertEqual(selection.current.id, 3)
        selection.move(by: 1)
        XCTAssertEqual(selection.current.id, 1)
    }

    func testDetailPagingSingleWordAndMissingSelectionStayValid() {
        let apple = makeWord(id: 1, text: "apple")
        for words in [[], [apple], [makeWord(id: 2, text: "banana")]] {
            var selection = WordDetailSelection(word: apple, words: words)
            selection.move(by: -1)
            selection.move(by: 1)
            XCTAssertEqual(selection.current, apple)
            XCTAssertEqual(selection.words.count, 1)
        }
    }

    func testDetailPagingPreservesEditsWhenReturningToWord() {
        let apple = makeWord(id: 1, text: "apple")
        let banana = makeWord(id: 2, text: "banana")
        var selection = WordDetailSelection(word: apple, words: [apple, banana])
        selection.select(id: banana.id)
        let edited = makeWord(id: 2, text: "edited banana")
        selection.replace(edited)
        selection.move(by: 1)
        XCTAssertEqual(selection.current, apple)
        selection.move(by: 1)
        XCTAssertEqual(selection.current, edited)
        XCTAssertEqual(selection.words.map(\.id), [1, 2])
        selection.select(id: 99)
        XCTAssertEqual(selection.current, edited)
    }

    @MainActor
    func testLoadWithoutDeckFetchesWordList() async {
        let apple = makeWord(id: 1, text: "apple")
        let dataSource = FakeStudyDataSource(wordList: [apple])
        let viewModel = WordListViewModel()

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [apple.id])
        XCTAssertTrue(viewModel.message.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testLoadWithDeckFetchesDeckCards() async {
        let deck = Deck(id: 7, deckName: "Deck 7", description: nil)
        let card = makeWord(id: 2, text: "banana")
        let dataSource = FakeStudyDataSource(deckCards: [7: [card]])
        let viewModel = WordListViewModel(deck: deck)

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [card.id])
    }

    @MainActor
    func testLoadDoesNotOverwritePreviewWords() async {
        let preview = [makeWord(id: 1, text: "preview")]
        let dataSource = FakeStudyDataSource(wordList: [makeWord(id: 2, text: "remote")])
        let viewModel = WordListViewModel(previewWords: preview)

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [1])
    }

    @MainActor
    func testLoadFailureSetsUserFacingMessage() async {
        let dataSource = FakeStudyDataSource(error: LocalStudyError.deckNotFound)
        let viewModel = WordListViewModel()

        await viewModel.load(dataSource: dataSource)

        XCTAssertTrue(viewModel.words.isEmpty)
        XCTAssertFalse(viewModel.message.isEmpty)
    }

    @MainActor
    func testFilteredWordsAppliesTagStatusDueAndSearch() {
        let viewModel = WordListViewModel(previewWords: [
            makeWord(id: 1, text: "apple", tags: ["fruit"], learningStatus: "learning"),
            makeWord(id: 2, text: "banana", tags: ["fruit"], learningStatus: "mastered"),
            makeWord(id: 3, text: "carrot", tags: ["vegetable"], learningStatus: "learning")
        ])

        viewModel.selectedTagFilter = "fruit"
        viewModel.selectedStatusFilter = .learning
        XCTAssertEqual(viewModel.filteredWords.map(\.id), [1])

        viewModel.selectedStatusFilter = .all
        viewModel.searchText = "ban"
        XCTAssertEqual(viewModel.filteredWords.map(\.id), [2])
    }

    @MainActor
    func testReplaceWordUpdatesWordsAndClearsMissingTagFilter() {
        let original = makeWord(id: 1, text: "apple", tags: ["fruit"])
        let viewModel = WordListViewModel(previewWords: [original])
        viewModel.selectedTagFilter = "fruit"

        let updated = makeWord(id: 1, text: "apple", tags: [])
        let returned = viewModel.replaceWord(updated)

        XCTAssertEqual(returned.tags, [])
        XCTAssertEqual(viewModel.words.first?.tags, [])
        XCTAssertNil(viewModel.selectedTagFilter)
    }

    private func makeWord(
        id: Int,
        text: String,
        tags: [String] = [],
        learningStatus: String? = nil
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
            tags: tags,
            learningStatus: learningStatus,
            learning: nil
        )
    }
}

@MainActor
final class RedSheetCheckTests: XCTestCase {
    func testAnswerButtonRevealsFirstThenSubmitsItsJudgment() {
        let model = RedSheetCheckModel()
        model.start(words: words, source: FakeStudyDataSource()) { _ in }

        model.revealOrSubmit(isCorrect: false)
        XCTAssertTrue(model.isAnswerVisible)
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.answers.isEmpty)

        model.revealOrSubmit(isCorrect: true)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.isAnswerVisible)
    }

    func testRevealRequiredAndJudgmentAdvancesBeforeSaving() async {
        let source = FakeStudyDataSource()
        let model = RedSheetCheckModel()
        var resume: CheckedContinuation<SavedAnswer, Error>?
        source.saveHandler = { card, correct in
            try await withCheckedThrowingContinuation { resume = $0 }
        }
        model.start(words: words, source: source) { _ in }
        model.submit(isCorrect: true)
        XCTAssertEqual(model.index, 0)
        model.isAnswerVisible = true
        model.submit(isCorrect: true)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.isAnswerVisible)
        XCTAssertEqual(model.pendingCount, 1)
        XCTAssertFalse(model.canLeave)
        for _ in 0..<1000 where resume == nil { await Task.yield() }
        resume?.resume(returning: saved(card: words[0], correct: true))
        await settle(model)
        XCTAssertTrue(model.canLeave)
    }

    func testFailedSaveKeepsAdvancingAndRetriesInOrderWithoutRepeatingSavedCards() async {
        let source = FakeStudyDataSource()
        var calls: [Int] = []
        var fails = true
        source.saveHandler = { card, correct in
            calls.append(card.id)
            if card.id == 2 && fails { throw URLError(.notConnectedToInternet) }
            return self.saved(card: card, correct: correct)
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        answer(model, false)
        await settle(model)
        answer(model, true)
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.pendingCount, 2)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(calls, [1, 2])
        fails = false
        model.retry()
        await settle(model)
        XCTAssertEqual(calls, [1, 2, 2, 3])
        XCTAssertEqual(model.pendingCount, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testUndoSavedAnswerRestoresPreviousProgressAndIsOnlyOneStep() async {
        let source = FakeStudyDataSource()
        let previous = LearningProgress.initial(userId: "test", cardId: 2).marking(isCorrect: false)
        source.saveHandler = { card, correct in
            SavedAnswer(progress: previous.marking(isCorrect: correct), previousProgress: previous)
        }
        var restored: Int?
        source.restoreHandler = { cardId, progress in
            restored = cardId
            XCTAssertEqual(progress?.incorrectCount, 1)
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        answer(model, false)
        await settle(model)
        await model.undo()
        XCTAssertEqual(restored, 2)
        XCTAssertEqual(model.index, 1)
        XCTAssertNil(model.answers[2])
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.isAnswerVisible)
        await model.undo()
        XCTAssertEqual(model.index, 1)
    }

    func testUndoUnsentLastAnswerPreservesEarlierPendingAnswer() async {
        let source = FakeStudyDataSource()
        source.saveHandler = { _, _ in throw URLError(.notConnectedToInternet) }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        answer(model, false)
        await model.undo()
        await settle(model)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.pendingCount, 1)
        XCTAssertNil(model.answers[2])
        XCTAssertFalse(model.canLeave)
    }

    func testUndoDuringSaveWaitsAndRestoresOnce() async {
        let source = FakeStudyDataSource()
        var resume: CheckedContinuation<SavedAnswer, Error>?
        source.saveHandler = { _, _ in
            try await withCheckedThrowingContinuation { resume = $0 }
        }
        var restores = 0
        source.restoreHandler = { _, _ in restores += 1 }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, false)
        for _ in 0..<1000 where resume == nil { await Task.yield() }
        let undo = Task { await model.undo() }
        for _ in 0..<1000 where !model.isUndoing { await Task.yield() }
        resume?.resume(returning: saved(card: words[0], correct: false))
        await undo.value
        XCTAssertEqual(restores, 1)
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.answers.isEmpty)
        XCTAssertEqual(model.pendingCount, 0)
    }

    func testFailedUndoCanBeRetriedWithoutChangingDisplayedAnswer() async {
        let source = FakeStudyDataSource()
        source.saveHandler = { card, correct in self.saved(card: card, correct: correct) }
        source.restoreHandler = { _, _ in throw URLError(.notConnectedToInternet) }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        await model.undo()
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertTrue(model.canUndo)
        XCTAssertNotNil(model.errorMessage)
        source.restoreHandler = { _, _ in }
        await model.undo()
        XCTAssertEqual(model.index, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testUnsavablePreviewCannotStart() {
        let model = RedSheetCheckModel()
        let word = WordCard(id: 9, text: "preview", meaning: "見本", partOfSpeech: nil,
                            sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                            audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        model.start(words: [word], source: FakeStudyDataSource()) { _ in }
        XCTAssertFalse(model.isStarted)
    }

    private var words: [WordCard] {
        (1...3).map { id in
            WordCard(id: id, cardId: id, text: "word \(id)", meaning: "意味", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
    }

    private func saved(card: WordCard, correct: Bool) -> SavedAnswer {
        SavedAnswer(progress: LearningProgress.initial(userId: "test", cardId: card.id).marking(isCorrect: correct), previousProgress: nil)
    }

    private func answer(_ model: RedSheetCheckModel, _ correct: Bool) {
        model.isAnswerVisible = true
        model.submit(isCorrect: correct)
    }

    private func settle(_ model: RedSheetCheckModel) async {
        for _ in 0..<1000 where model.isSaving { await Task.yield() }
        XCTAssertFalse(model.isSaving)
    }
}

private final class FakeStudyDataSource: StudyDataSource {
    var saveHandler: ((WordCard, Bool) async throws -> SavedAnswer)?
    var restoreHandler: ((Int, LearningProgress?) async throws -> Void)?
    private let wordList: [WordCard]
    private let deckCards: [Int: [WordCard]]
    private let error: Error?

    init(wordList: [WordCard] = [], deckCards: [Int: [WordCard]] = [:], error: Error? = nil) {
        self.wordList = wordList
        self.deckCards = deckCards
        self.error = error
    }

    func fetchDecks() async throws -> [Deck] { [] }
    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts { StudyDeckCounts(newCount: 0, dueCount: 0) }

    func fetchCards(deckId: Int) async throws -> [WordCard] {
        if let error { throw error }
        return deckCards[deckId] ?? []
    }

    func fetchWordList() async throws -> [WordCard] {
        if let error { throw error }
        return wordList
    }

    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] { [] }
    func fetchStudyStats() async throws -> StudyStats { .empty }
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress { throw LocalStudyError.missingCardId }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer {
        guard let saveHandler else { throw LocalStudyError.missingCardId }
        return try await saveHandler(card, isCorrect)
    }
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {
        try await restoreHandler?(cardId, previousProgress)
    }
    func fetchTags(wordId: Int) async throws -> [String]? { nil }
    func saveTags(_ tags: Set<String>, wordId: Int) async throws {}
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard { throw LocalStudyError.deckNotFound }
    func canManage(_ deck: Deck) -> Bool { false }
    var supportsDeckReordering: Bool { false }
    var supportsDeckFileTransfer: Bool { false }
    func installBundledDeck(_ file: DeckFile) async throws -> DeckInstallOutcome { throw LocalStudyError.deckNotFound }
    func deleteDeck(id: Int) async throws { throw LocalStudyError.deckNotFound }
}
