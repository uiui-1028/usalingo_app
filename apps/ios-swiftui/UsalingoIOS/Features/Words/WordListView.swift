import SwiftUI

struct WordListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var words: [WordCard] = []
    @State private var searchText = ""
    @State private var selectedTagFilter: String?
    @State private var selectedStatusFilter: WordStatusFilter = .all
    @State private var selectedDueFilter: WordDueFilter = .all
    @State private var selectedSort: WordSortOption = .registered
    @State private var selectedWord: WordCard?
    @State private var message = ""
    @State private var isLoading = false

    private let deck: Deck?
    private let studyService = StudyService()

    init(deck: Deck? = nil) {
        self.deck = deck
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                if !availableTags.isEmpty {
                    Section {
                        tagFilterBar
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    statusFilterBar
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                }

                Section {
                    dueFilterBar
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                }

                if filteredWords.isEmpty {
                    ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredWords) { word in
                        Button {
                            selectedWord = word
                        } label: {
                            WordRow(word: word)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(deck?.deckName ?? "単語リスト")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .searchable(text: $searchText, prompt: "英単語・意味・例文を検索")
        .overlay {
            if !message.isEmpty && words.isEmpty && !isLoading {
                ContentUnavailableView("読み込みできません", systemImage: "exclamationmark.triangle", description: Text(message))
            }
        }
        .sheet(item: $selectedWord) { word in
            WordDetailSheet(word: word) { savedWord in
                replaceWord(savedWord)
            }
                .presentationDetents([.medium, .large])
        }
        .task { await load() }
    }

    private var availableTags: [String] {
        Array(Set(words.flatMap(\.tags))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var filteredWords: [WordCard] {
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

    private var sortMenu: some View {
        Menu {
            ForEach(WordSortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    Label(option.title, systemImage: selectedSort == option ? "checkmark" : option.symbol)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("並び替え")
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagFilterButton(title: "すべて", isSelected: selectedTagFilter == nil) {
                    selectedTagFilter = nil
                }

                ForEach(availableTags, id: \.self) { tag in
                    tagFilterButton(title: tag, isSelected: selectedTagFilter == tag) {
                        selectedTagFilter = tag
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WordStatusFilter.allCases) { filter in
                    tagFilterButton(title: filter.title, isSelected: selectedStatusFilter == filter) {
                        selectedStatusFilter = filter
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var dueFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WordDueFilter.allCases) { filter in
                    tagFilterButton(title: filter.title, isSelected: selectedDueFilter == filter) {
                        selectedDueFilter = filter
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func tagFilterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? AppStyle.accent : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : AppStyle.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let deck {
                words = try await studyService.fetchCards(deckId: deck.id, session: session)
            } else {
                words = try await studyService.fetchWordList(session: session)
            }
            clearMissingTagFilter()
            message = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func replaceWord(_ savedWord: WordCard) {
        if let index = words.firstIndex(where: { $0.id == savedWord.id }) {
            words[index] = savedWord
        }
        clearMissingTagFilter()
        selectedWord = savedWord
    }

    private func clearMissingTagFilter() {
        if let selectedTagFilter, !availableTags.contains(selectedTagFilter) {
            self.selectedTagFilter = nil
        }
    }
}

private enum WordDueFilter: String, CaseIterable, Identifiable {
    case all
    case unset
    case due
    case future

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "予定すべて"
        case .unset:
            "未設定"
        case .due:
            "今日まで"
        case .future:
            "今後"
        }
    }

    func matches(_ word: WordCard) -> Bool {
        switch self {
        case .all:
            return true
        case .unset:
            return word.learning == nil
        case .due:
            guard let nextReviewDate = word.learning?.nextReviewDate,
                  let date = Self.parseDate(nextReviewDate) else { return false }
            return date <= Date()
        case .future:
            guard let nextReviewDate = word.learning?.nextReviewDate,
                  let date = Self.parseDate(nextReviewDate) else { return false }
            return date > Date()
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)
    }
}

private enum WordSortOption: String, CaseIterable, Identifiable {
    case registered
    case alphabetical
    case status
    case dueDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .registered:
            "登録順"
        case .alphabetical:
            "A-Z"
        case .status:
            "学習状態"
        case .dueDate:
            "復習予定"
        }
    }

    var symbol: String {
        switch self {
        case .registered:
            "number"
        case .alphabetical:
            "textformat.abc"
        case .status:
            "chart.bar"
        case .dueDate:
            "calendar"
        }
    }

    func sort(_ words: [WordCard]) -> [WordCard] {
        switch self {
        case .registered:
            words.sorted { $0.id < $1.id }
        case .alphabetical:
            words.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        case .status:
            words.sorted {
                let leftRank = statusRank($0.learningStatus)
                let rightRank = statusRank($1.learningStatus)
                if leftRank == rightRank { return $0.id < $1.id }
                return leftRank < rightRank
            }
        case .dueDate:
            words.sorted {
                let leftDate = parseDate($0.learning?.nextReviewDate)
                let rightDate = parseDate($1.learning?.nextReviewDate)
                switch (leftDate, rightDate) {
                case let (left?, right?):
                    if left == right { return $0.id < $1.id }
                    return left < right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return $0.id < $1.id
                }
            }
        }
    }

    private func statusRank(_ status: String?) -> Int {
        switch status {
        case nil:
            0
        case "learning":
            1
        case "mastered":
            2
        default:
            3
        }
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: value) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)
    }
}

private enum WordStatusFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case learning
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "すべて"
        case .new:
            "未学習"
        case .learning:
            "復習中"
        case .mastered:
            "習得済み"
        }
    }

    func matches(_ word: WordCard) -> Bool {
        switch self {
        case .all:
            true
        case .new:
            word.learningStatus == nil
        case .learning:
            word.learningStatus == "learning"
        case .mastered:
            word.learningStatus == "mastered"
        }
    }
}

private struct WordRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppStyle.accent)
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String(word.text.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(word.text)
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                    if let part = word.partOfSpeech {
                        Text(part.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppStyle.accent.opacity(0.12))
                            .foregroundStyle(AppStyle.accent)
                            .clipShape(Capsule())
                    }
                    StatusBadge(status: word.learningStatus)
                }
                Text(word.meaning)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                    .lineLimit(1)
                if let sentence = word.sentenceEnglish, !sentence.isEmpty {
                    Text(sentence)
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                        .lineLimit(1)
                }
                if !word.tags.isEmpty {
                    TagChipRow(tags: Array(word.tags.prefix(3)))
                }
                if let learning = word.learning {
                    Text("次回: \(learning.formattedNextReviewDate)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppStyle.muted)
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
        }
        .padding(.vertical, 8)
    }
}

private struct StatusBadge: View {
    let status: String?

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var title: String {
        switch status {
        case "learning":
            "復習中"
        case "mastered":
            "習得済み"
        default:
            "未学習"
        }
    }

    private var color: Color {
        switch status {
        case "learning":
            AppStyle.accent
        case "mastered":
            .green
        default:
            AppStyle.muted
        }
    }
}

private struct WordDetailSheet: View {
    @State private var word: WordCard
    @State private var isEditing = false
    @State private var isTagging = false
    let onSaved: (WordCard) -> Void

    init(word: WordCard, onSaved: @escaping (WordCard) -> Void) {
        _word = State(initialValue: word)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let url = word.illustrationURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 180)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.text)
                            .font(.largeTitle.bold())
                        Text(word.meaning)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppStyle.ink)
                        if let part = word.partOfSpeech {
                            Text(part.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppStyle.accent)
                        }
                        WordMetaRow(word: word)
                        if !word.tags.isEmpty {
                            TagChipRow(tags: word.tags)
                        }
                    }

                    if let sentence = word.sentenceEnglish {
                        DetailBlock(title: "Example", text: sentence)
                    }

                    if let sentence = word.sentenceJapanese {
                        DetailBlock(title: "日本語", text: sentence)
                    }

                    if let learning = word.learning {
                        DetailBlock(title: "学習メモ", text: learning.studySummary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("単語詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isTagging = true
                    } label: {
                        Image(systemName: "tag")
                    }
                    .accessibilityLabel("タグを編集")
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("単語を編集")
                }
            }
            .sheet(isPresented: $isEditing) {
                WordEditSheet(word: word) { savedWord in
                    word = savedWord
                    onSaved(savedWord)
                }
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $isTagging) {
                TagSheet(word: word) { savedWord in
                    word = savedWord
                    onSaved(savedWord)
                }
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct WordMetaRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: 10) {
            StatusBadge(status: word.learningStatus)
            if let part = word.partOfSpeech {
                metaChip(part.uppercased(), symbol: "textformat")
            }
            if let learning = word.learning {
                metaChip("Lv.\(learning.srsLevel)", symbol: "chart.bar")
            }
            metaChip("\(word.tags.count)タグ", symbol: "tag")
        }
        .padding(.top, 4)
    }

    private func metaChip(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(AppStyle.muted)
            .clipShape(Capsule())
    }
}

private struct TagChipRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppStyle.accent.opacity(0.12))
                        .foregroundStyle(AppStyle.accent)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private extension WordLearningSnapshot {
    var studySummary: String {
        "SRS Lv.\(srsLevel) / \(repetitions)回復習 / 次回: \(formattedNextReviewDate) / 間隔: \(intervalDays)日"
    }

    var formattedNextReviewDate: String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        return nextReviewDate
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct DetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
            Text(text)
                .font(.body)
                .foregroundStyle(AppStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
