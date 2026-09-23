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
    /// バナーに並べる所持デッキ。
    @Published private(set) var decks: [Deck] = []
    /// デッキ一覧の取得失敗。単語側の `message` とは混ぜない。
    @Published private(set) var deckMessage = ""

    /// いま単語を表示しているデッキ。nil なら全デッキの単語リスト。
    @Published private(set) var deck: Deck?
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
        let requestedDeckID = deck?.id
        isLoading = true
        // 後から始めた取得がまだ走っているなら、スピナーはそちらに任せる。
        defer { if deck?.id == requestedDeckID { isLoading = false } }

        do {
            let loaded: [WordCard]
            if let requestedDeckID {
                loaded = try await dataSource.fetchCards(deckId: requestedDeckID)
            } else {
                loaded = try await dataSource.fetchWordList()
            }
            // 取得中に別のデッキへ送られていたら、古い結果で上書きしない。
            guard deck?.id == requestedDeckID else { return }
            words = loaded
            clearMissingTagFilter()
            message = ""
        } catch {
            guard deck?.id == requestedDeckID else { return }
            message = UserFacingError.message(for: error)
        }
    }

    /// 所持デッキを取り、前に選んでいたデッキ（無ければ先頭）の単語を読む。
    func loadDecks(dataSource: any StudyDataSource, preferredDeckID: Int?) async {
        guard previewWords == nil else { return }
        do {
            decks = try await dataSource.fetchDecks()
            deckMessage = ""
        } catch {
            decks = []
            words = []
            deckMessage = "デッキを読み込めませんでした。"
            return
        }
        guard let selected = decks.first(where: { $0.id == preferredDeckID }) ?? decks.first else {
            deck = nil
            words = []
            message = ""
            return
        }
        deck = selected
        await load(dataSource: dataSource)
    }

    /// バナーで選んだデッキへ単語を差し替える。
    /// タグはデッキごとに違うので解除し、並べ替えと表示モードは好みとして残す。
    func selectDeck(_ newDeck: Deck, dataSource: any StudyDataSource) async {
        guard previewWords == nil, newDeck.id != deck?.id else { return }
        deck = newDeck
        // 前のデッキの単語を残すと、取得に失敗したときに別デッキの中身に見える。
        words = []
        selectedTagFilter = nil
        await load(dataSource: dataSource)
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

    func revealAnswer() {
        guard current != nil, !isUndoing else { return }
        isAnswerVisible = true
    }

    func replaceWord(_ word: WordCard) {
        guard let index = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[index] = word
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
