import SwiftUI

struct WordListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var words: [WordCard] = []
    @State private var searchText = ""
    @State private var selectedTagFilter: String?
    @State private var selectedStatusFilter: WordStatusFilter = .all
    @State private var selectedDueFilter: WordDueFilter = .all
    @State private var selectedSort: WordSortOption = .registered
    @State private var selectedDisplayMode: WordListDisplayMode = .list
    @State private var selectedWord: WordCard?
    @State private var message = ""
    @State private var isLoading = false

    private let deck: Deck?
    private let previewWords: [WordCard]?
    private let studyService = StudyService()

    init(deck: Deck? = nil, previewWords: [WordCard]? = nil) {
        self.deck = deck
        self.previewWords = previewWords
        _words = State(initialValue: previewWords ?? [])
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(WireColor.ink)
                    Spacer()
                }
                .wireListRow()
            } else if !message.isEmpty && words.isEmpty {
                WordListErrorBox(info: WordListErrorInfo(rawMessage: message)) {
                    Task { await load() }
                }
                .wireListRow(vertical: WireMetrics.spacingXL)
            } else {
                Section {
                    displayModePicker
                        .wireListRow(vertical: WireMetrics.spacingXS)
                }

                if !availableTags.isEmpty {
                    Section {
                        tagFilterBar
                            .wireListRow(vertical: WireMetrics.spacingXS)
                    }
                }

                Section {
                    statusFilterBar
                        .wireListRow(vertical: WireMetrics.spacingXS)
                }

                Section {
                    dueFilterBar
                        .wireListRow(vertical: WireMetrics.spacingXS)
                }

                if filteredWords.isEmpty {
                    ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                        .wireListRow()
                } else if selectedDisplayMode == .cards {
                    LazyVGrid(columns: cardColumns, spacing: WireMetrics.spacingM) {
                        ForEach(filteredWords) { word in
                            Button {
                                selectedWord = word
                            } label: {
                                WordLibraryCard(word: word)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .wireListRow()
                } else {
                    ForEach(filteredWords) { word in
                        Button {
                            selectedWord = word
                        } label: {
                            WordRow(word: word)
                        }
                        .buttonStyle(.plain)
                        .wireListRow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(WireColor.background)
        .navigationTitle(deck?.deckName ?? "単語リスト")
        .toolbarBackground(WireColor.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .searchable(text: $searchText, prompt: "英単語・意味・例文を検索")
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

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible())
        ]
    }

    /// セグメント表示は既製の見た目なので、ピルの並びに置き換える（Section 3）。
    private var displayModePicker: some View {
        HStack(spacing: WireMetrics.spacingS) {
            ForEach(WordListDisplayMode.allCases) { mode in
                Button {
                    selectedDisplayMode = mode
                } label: {
                    Label(mode.title, systemImage: mode.symbol)
                        .wireFont(.label)
                        .fontWeight(selectedDisplayMode == mode ? .bold : .semibold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WireMetrics.spacingS)
                        .outlineSurface(
                            radius: WireMetrics.radiusSmall,
                            stroke: selectedDisplayMode == mode
                                ? WireMetrics.strokeHeavy
                                : WireMetrics.strokeBase,
                            shadow: nil
                        )
                        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedDisplayMode == mode ? .isSelected : [])
            }
        }
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                tagFilterButton(title: "すべて", isSelected: selectedTagFilter == nil) {
                    selectedTagFilter = nil
                }

                ForEach(availableTags, id: \.self) { tag in
                    tagFilterButton(title: tag, isSelected: selectedTagFilter == tag) {
                        selectedTagFilter = tag
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(WordStatusFilter.allCases) { filter in
                    tagFilterButton(title: filter.title, isSelected: selectedStatusFilter == filter) {
                        selectedStatusFilter = filter
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }

    private var dueFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(WordDueFilter.allCases) { filter in
                    tagFilterButton(title: filter.title, isSelected: selectedDueFilter == filter) {
                        selectedDueFilter = filter
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }

    /// 選択は黒ベタ反転ではなく、枠線の昇格と太字で示す（Section 3.2）。
    private func tagFilterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WirePill(title: title, isSelected: isSelected, font: .caption)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func load() async {
        guard previewWords == nil else { return }
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
            message = UserFacingError.message(for: error)
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

private struct WordListErrorInfo {
    let number: String
    let action: String

    init(rawMessage: String) {
        let parsedCode = Self.databaseCode(from: rawMessage)
        number = parsedCode ?? Self.fallbackNumber(for: rawMessage)
        action = Self.recoveryAction(for: rawMessage, parsedCode: parsedCode)
    }

    private static func databaseCode(from rawMessage: String) -> String? {
        guard let data = rawMessage.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String,
              !code.isEmpty else {
            return nil
        }
        return code
    }

    private static func fallbackNumber(for rawMessage: String) -> String {
        let lowercased = rawMessage.lowercased()
        if lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("network") {
            return "WL-001"
        }
        if lowercased.contains("unauthorized") || lowercased.contains("jwt") || lowercased.contains("session") {
            return "WL-002"
        }
        return "WL-000"
    }

    private static func recoveryAction(for rawMessage: String, parsedCode: String?) -> String {
        let lowercased = rawMessage.lowercased()
        if lowercased.contains("relation") || parsedCode == "42P01" {
            return "データベースの単語テーブル設定を確認してください。"
        }
        if lowercased.contains("permission") || lowercased.contains("rls") || parsedCode == "42501" {
            return "ログイン状態またはデータベース権限を確認してください。"
        }
        if lowercased.contains("unauthorized") || lowercased.contains("jwt") || lowercased.contains("session") {
            return "一度サインアウトしてから、再度サインインしてください。"
        }
        if lowercased.contains("timed out") || lowercased.contains("offline") || lowercased.contains("network") {
            return "通信状態を確認してから、もう一度読み込んでください。"
        }
        return "時間をおいて再読み込みしてください。改善しない場合はエラー番号を控えてください。"
    }
}

private struct WordListErrorBox: View {
    let info: WordListErrorInfo
    let retry: () -> Void

    var body: some View {
        // 色相を使わずに異常を示す（破線 + 文言）。
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            HStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "exclamationmark.triangle")
                    .wireFont(.titleS)
                    .frame(width: 42, height: 42)
                    .outlineCircleSurface()

                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text("読み込みできません")
                        .wireFont(.titleS)
                    Text("エラー番号: \(info.number)")
                        .wireFont(.caption)
                }
            }

            Text("対処方法: \(info.action)")
                .wireFont(.body)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                retry()
            } label: {
                Label("再読み込み", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.wireSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card, dashed: true)
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

private enum WordListDisplayMode: String, CaseIterable, Identifiable {
    case list
    case cards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list:
            "リスト"
        case .cards:
            "カード"
        }
    }

    var symbol: String {
        switch self {
        case .list:
            "list.bullet"
        case .cards:
            "rectangle.grid.2x2"
        }
    }
}

private struct WordLibraryCard: View {
    let word: WordCard

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipped()

            Text(word.text)
                .wireFont(.titleS)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, WireMetrics.spacingS)
                .padding(.vertical, WireMetrics.spacingXS)
        }
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(word.text)
        .accessibilityHint("単語の詳細を開きます")
    }

    @ViewBuilder
    private var illustration: some View {
        if let url = word.illustrationURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    imagePlaceholder(showProgress: true)
                case .failure:
                    imagePlaceholder(showProgress: false)
                @unknown default:
                    imagePlaceholder(showProgress: false)
                }
            }
        } else {
            imagePlaceholder(showProgress: false)
        }
    }

    private func imagePlaceholder(showProgress: Bool) -> some View {
        ZStack {
            WireImagePlaceholder(radius: WireMetrics.radiusControl)
            if showProgress {
                ProgressView()
                    .tint(WireColor.ink)
            }
        }
    }
}

private struct WordRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: WireMetrics.spacingM) {
            WireAvatar(initials: String(word.text.prefix(1)).uppercased(), diameter: 42)

            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                HStack(spacing: WireMetrics.spacingS) {
                    Text(word.text)
                        .wireFont(.titleS)
                    if let part = word.partOfSpeech {
                        WirePill(title: part.uppercased(), font: .caption)
                    }
                    StatusBadge(status: word.learningStatus)
                }
                Text(word.meaning)
                    .wireFont(.body)
                    .lineLimit(1)
                if let sentence = word.sentenceEnglish, !sentence.isEmpty {
                    Text(sentence)
                        .wireFont(.caption)
                        .lineLimit(1)
                }
                if !word.tags.isEmpty {
                    TagChipRow(tags: Array(word.tags.prefix(3)))
                }
                if let learning = word.learning {
                    Text("次回: \(learning.formattedNextReviewDate)")
                        .wireFont(.caption)
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .wireFont(.caption)
        }
        .padding(WireMetrics.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
    }
}

private struct StatusBadge: View {
    let status: String?

    var body: some View {
        WirePill(title: title, isSelected: status == "mastered", font: .caption)
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
                VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                    if let url = word.illustrationURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                                .tint(WireColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 180)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: nil)
                    }

                    VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                        Text(word.text)
                            .wireFont(.titleL)
                        Text(word.meaning)
                            .wireFont(.titleS)
                        if let part = word.partOfSpeech {
                            Text(part.uppercased())
                                .wireFont(.caption)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("単語詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WireColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isTagging = true
                    } label: {
                        Image(systemName: "tag")
                            .wireFont(.label)
                    }
                    .accessibilityLabel("タグを編集")
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .wireFont(.label)
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
        HStack(spacing: WireMetrics.spacingS) {
            StatusBadge(status: word.learningStatus)
            if let part = word.partOfSpeech {
                WirePill(title: part.uppercased(), font: .caption)
            }
            if let learning = word.learning {
                WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
            }
            WirePill(title: "\(word.tags.count)タグ", font: .caption)
        }
        .padding(.top, WireMetrics.spacingXS)
    }
}

private struct TagChipRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingXS) {
                ForEach(tags, id: \.self) { tag in
                    WirePill(title: tag, font: .caption)
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
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text(title)
                .wireFont(.caption)
            Text(text)
                .wireFont(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}
