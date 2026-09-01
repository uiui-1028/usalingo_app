import XCTest
@testable import UsalingoIOS

final class WordListViewModelTests: XCTestCase {
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

private final class FakeStudyDataSource: StudyDataSource {
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
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer { throw LocalStudyError.missingCardId }
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {}
    func fetchTags(wordId: Int) async throws -> [String]? { nil }
    func saveTags(_ tags: Set<String>, wordId: Int) async throws {}
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard { throw LocalStudyError.deckNotFound }
}
