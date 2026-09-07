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
        // 操作はすべて下の浮動バーに集めたので、上のヘッダーごと消す。
        // ヘッダーを消すと端からのスワイプで戻る動きも止まるため、それだけ戻す。
        .toolbar(.hidden, for: .navigationBar)
        .background(InteractiveSwipeBackEnabler().frame(width: 0, height: 0))
        // 左のバーに絞り込み・並べ替え・検索、右のバーに表示切り替えを収める。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WordListBottomBars(
                tags: viewModel.availableTags,
                selectedTag: $viewModel.selectedTagFilter,
                selectedStatusFilter: $viewModel.selectedStatusFilter,
                selectedDueFilter: $viewModel.selectedDueFilter,
                selectedSort: $viewModel.selectedSort,
                searchText: $viewModel.searchText,
                selectedDisplayMode: $viewModel.selectedDisplayMode
            )
        }
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word, words: viewModel.filteredWords) { savedWord in
                _ = viewModel.replaceWord(savedWord)
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
