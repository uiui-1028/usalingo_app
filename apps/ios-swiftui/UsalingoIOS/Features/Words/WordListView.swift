import SwiftUI

struct WordListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: WordListViewModel
    @State private var selectedWord: WordCard?

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list
    ) {
        _viewModel = StateObject(wrappedValue: WordListViewModel(
            deck: deck,
            previewWords: previewWords,
            displayMode: displayMode
        ))
    }

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(WireColor.ink)
                    Spacer()
                }
                .wireListRow()
            } else if !viewModel.message.isEmpty && viewModel.words.isEmpty {
                WordListErrorBox(info: WordListErrorInfo(rawMessage: viewModel.message)) {
                    Task { await viewModel.load(dataSource: appState.studyDataSource) }
                }
                .wireListRow(vertical: WireMetrics.spacingXL)
            } else {
                Section {
                    WordListDisplayModePicker(selectedMode: $viewModel.selectedDisplayMode)
                        .wireListRow(vertical: WireMetrics.spacingXS)
                }

                if viewModel.filteredWords.isEmpty {
                    ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                        .wireListRow()
                } else if viewModel.selectedDisplayMode == .cards {
                    LazyVGrid(columns: cardColumns, spacing: WireMetrics.spacingM) {
                        ForEach(viewModel.filteredWords) { word in
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
                    ForEach(viewModel.filteredWords) { word in
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
        .navigationTitle(viewModel.deck?.deckName ?? "単語リスト")
        .toolbarBackground(WireColor.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                WordListFilterMenu(
                    tags: viewModel.availableTags,
                    selectedTag: $viewModel.selectedTagFilter,
                    selectedStatusFilter: $viewModel.selectedStatusFilter,
                    selectedDueFilter: $viewModel.selectedDueFilter
                )
            }

            ToolbarItem(placement: .primaryAction) {
                WordListSortMenu(selectedSort: $viewModel.selectedSort)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "英単語・意味・例文を検索")
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word) { savedWord in
                selectedWord = viewModel.replaceWord(savedWord)
            }
        }
        .task(id: appState.session?.user.id ?? "guest") { await viewModel.load(dataSource: appState.studyDataSource) }
        // 浮いているタブバーが一覧の末尾に重なるので、この画面にいる間は
        // シェルの操作面を隠す。
        // 戻る導線はナビゲーションバーの戻るボタンとスワイプが担う。
        .onAppear {
            appState.isShellChromeHidden = true
        }
        .onDisappear {
            appState.isShellChromeHidden = false
        }
    }

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible())
        ]
    }
}
