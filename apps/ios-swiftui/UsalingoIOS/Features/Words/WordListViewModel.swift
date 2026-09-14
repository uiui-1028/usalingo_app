import Foundation

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var words: [WordCard]
    @Published var searchText = ""
    @Published var selectedTagFilter: String?
    @Published var selectedStatusFilter: WordStatusFilter = .all
    @Published var selectedDueFilter: WordDueFilter = .all
    @Published var selectedSort: WordSortOption = .registered
    @Published var selectedDisplayMode: WordListDisplayMode
    @Published var message = ""
    @Published var isLoading = false

    let deck: Deck?
    private let previewWords: [WordCard]?

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list
    ) {
        self.deck = deck
        self.previewWords = previewWords
        words = previewWords ?? []
        selectedDisplayMode = displayMode
    }

    var availableTags: [String] {
        Array(Set(words.flatMap(\.tags))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var filteredWords: [WordCard] {
        let tagFilteredWords: [WordCard]
        if let selectedTagFilter {
            tagFilteredWords = words.filter { $0.tags.contains(selectedTagFilter) }
        } else {
            tagFilteredWords = words
        }

        let statusFilteredWords = tagFilteredWords.filter { selectedStatusFilter.matches($0) }
        let dueFilteredWords = statusFilteredWords.filter { selectedDueFilter.matches($0) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return selectedSort.sort(dueFilteredWords) }

        let searchedWords = dueFilteredWords.filter { word in
            word.text.lowercased().contains(query)
                || word.meaning.lowercased().contains(query)
                || (word.sentenceEnglish?.lowercased().contains(query) ?? false)
                || (word.sentenceJapanese?.lowercased().contains(query) ?? false)
                || word.tags.contains { $0.lowercased().contains(query) }
        }
        return selectedSort.sort(searchedWords)
    }

    func load(dataSource: any StudyDataSource) async {
        guard previewWords == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let deck {
                words = try await dataSource.fetchCards(deckId: deck.id)
            } else {
                words = try await dataSource.fetchWordList()
            }
            clearMissingTagFilter()
            message = ""
        } catch {
            message = UserFacingError.message(for: error)
        }
    }

    @discardableResult
    func replaceWord(_ savedWord: WordCard) -> WordCard {
        if let index = words.firstIndex(where: { $0.id == savedWord.id }) {
            words[index] = savedWord
        }
        clearMissingTagFilter()
        return savedWord
    }

    func clearMissingTagFilter() {
        if let selectedTagFilter, !availableTags.contains(selectedTagFilter) {
            self.selectedTagFilter = nil
        }
    }
}

/// チェック開始時の順序を保ち、表示上の判定と保存の完了を分ける。
@MainActor
final class RedSheetCheckModel: ObservableObject {
    @Published private(set) var words: [WordCard] = []
    @Published private(set) var index = 0
    @Published var isAnswerVisible = false
    @Published private(set) var answers: [Int: Bool] = [:]
    @Published private(set) var pendingCount = 0
    @Published private(set) var isSaving = false
    @Published private(set) var isUndoing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canUndo = false

    private var queue = StudyAnswerQueue()
    private var savedAnswers: [Int: SavedAnswer] = [:]
    private var source: (any StudyDataSource)?
    private var didSave: ((WordCard) -> Void)?
    private var saveTask: Task<Void, Never>?

    var current: WordCard? { words.indices.contains(index) ? words[index] : nil }
    var isStarted: Bool { !words.isEmpty }
    var isComplete: Bool { isStarted && current == nil }
    var canLeave: Bool { pendingCount == 0 && !isUndoing }

    func start(words: [WordCard], source: any StudyDataSource, didSave: @escaping (WordCard) -> Void) {
        guard canLeave, !words.isEmpty, words.allSatisfy({ $0.cardId != nil }) else { return }
        self.words = words
        self.source = source
        self.didSave = didSave
        index = 0
        answers = [:]
        savedAnswers = [:]
        queue.reset()
        isAnswerVisible = false
        canUndo = false
        errorMessage = nil
    }

    func submit(isCorrect: Bool) {
        guard let current, isAnswerVisible, !isUndoing else { return }
        answers[current.id] = isCorrect
        queue.enqueue(cardIndex: index, card: current, isCorrect: isCorrect)
        pendingCount = queue.pending.count
        index += 1
        isAnswerVisible = false
        canUndo = true
        // 失敗は次の判定で消さない。再送ボタンで明示的に再開する。
        if errorMessage == nil { retry() }
    }

    func retry() {
        guard let source, !isUndoing, queue.beginDraining() else { return }
        errorMessage = nil
        isSaving = true
        saveTask = Task {
            while let pending = queue.next {
                do {
                    let saved = try await source.saveAnswerWithUndo(card: pending.card, isCorrect: pending.isCorrect, attempt: pending.attempt)
                    savedAnswers[pending.cardIndex] = saved
                    didSave?(pending.card.withLearningProgress(saved.progress))
                    queue.completeFirst()
                    pendingCount = queue.pending.count
                } catch {
                    errorMessage = "未保存の判定があります。\(UserFacingError.message(for: error))"
                    break
                }
                // 取り消し要求が来たら、実行中の1件だけを終えて止まる。
                if isUndoing { break }
            }
            queue.endDraining()
            isSaving = false
        }
    }

    func undo() async {
        guard canUndo, !isUndoing, index > 0, let source else { return }
        isUndoing = true
        await saveTask?.value
        let previousIndex = index - 1
        let card = words[previousIndex]
        do {
            // 送信後に応答だけ失われた場合も、送信前の控えから確実に戻す。
            let pending = queue.pending.last.flatMap { $0.cardIndex == previousIndex ? $0 : nil }
            if let saved = savedAnswers[previousIndex] ?? pending?.attempt.prepared, let cardId = card.cardId {
                try await source.restoreLearningProgress(cardId: cardId, previousProgress: saved.previousProgress)
                didSave?(card)
                savedAnswers.removeValue(forKey: previousIndex)
            }
            queue.removeLast(cardIndex: previousIndex)
            answers.removeValue(forKey: card.id)
            index = previousIndex
            isAnswerVisible = false
            canUndo = false
            pendingCount = queue.pending.count
            errorMessage = nil
        } catch {
            errorMessage = "取り消しを保存できませんでした。「戻る」でもう一度お試しください。"
        }
        isUndoing = false
        if errorMessage == nil { retry() }
    }

    func reset() {
        guard canLeave else { return }
        words = []
        answers = [:]
        index = 0
        canUndo = false
        isAnswerVisible = false
        errorMessage = nil
        savedAnswers = [:]
        source = nil
        didSave = nil
    }
}
