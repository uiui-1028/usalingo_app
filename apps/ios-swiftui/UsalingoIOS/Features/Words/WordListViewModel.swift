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
