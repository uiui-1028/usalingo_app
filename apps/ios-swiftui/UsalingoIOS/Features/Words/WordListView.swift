import SwiftUI

struct WordListView: View {
    /// シートが画面の高さに占める割合。7.5割で固定し、引っ張っても変えない。
    private static let sheetHeightRatio: CGFloat = 0.75
    /// 浮動バーの高さと下余白のぶん、最後の行が隠れないように空ける量。
    @State private var bottomBarClearance: CGFloat = 96
    @State private var isRedSheetEnabled = false
    @State private var redSheetTopRatio: CGFloat = 0.4
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var lastRowHeight: CGFloat = 80

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: WordListViewModel
    @State private var selectedWord: WordCard?
    /// バナーで選んでいるデッキ。いまは見た目だけで、一覧の中身は変えない。
    @State private var selectedDeckID: Int?

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list,
        previewRedSheetEnabled: Bool = false
    ) {
        _isRedSheetEnabled = State(initialValue: previewWords != nil && previewRedSheetEnabled && displayMode == .list)
        _viewModel = StateObject(wrappedValue: WordListViewModel(
            deck: deck,
            previewWords: previewWords,
            displayMode: displayMode
        ))
    }

    /// 画面は「背面のバナー（デッキ選択）」と「前面のシート（単語一覧）」の2層。
    /// バナーは戻るスワイプの通り道でもあるので、横に動く操作は置かない。
    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            // セーフエリアまで含めた画面の高さ。シートの高さはここから割合で決める。
            let screenHeight = proxy.size.height + insets.top + insets.bottom
            let sheetHeight = screenHeight * Self.sheetHeightRatio
            let bannerHeight = max(0, screenHeight - sheetHeight - insets.top - WireMetrics.spacingS)

            ZStack(alignment: .top) {
                // シートより1段退いた面。これで前後関係を作る。
                WireColor.scrim
                    .ignoresSafeArea()

                WordListDeckBanner(decks: bannerDecks) { deck in
                    selectedDeckID = deck.id
                }
                .padding(.horizontal, WireMetrics.screenPadding)
                .padding(.top, WireMetrics.spacingS)
                // シートに覆われない分だけを使う。
                .frame(height: bannerHeight + WireMetrics.spacingS, alignment: .top)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    sheet(bottomInset: insets.bottom)
                        .frame(height: sheetHeight)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        // 操作はすべてシートの中の浮動バーに集めたので、上のヘッダーごと消す。
        // ヘッダーを消すと戻るスワイプも一緒に止まるため、学習画面と同じ仕組みで戻す。
        .toolbar(.hidden, for: .navigationBar)
        .background {
            BackSwipeEnabler()
        }
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word, words: viewModel.filteredWords) { savedWord in
                _ = viewModel.replaceWord(savedWord)
            }
        }
        .task(id: appState.session?.user.id ?? "guest") { await viewModel.load(dataSource: appState.studyDataSource) }
        // 浮いているタブバーが一覧の末尾に重なるので、この画面にいる間は
        // シェルの操作面を隠す。戻る導線はスワイプが担う。
        .onAppear {
            appState.isShellChromeHidden = true
        }
        .onDisappear {
            appState.isShellChromeHidden = false
        }
    }

    /// 前面のシート。高さは固定で、中身だけが縦に流れる。
    /// スクロールした中身はシートの上端まで届き、そこで切り取られる。
    private func sheet(bottomInset: CGFloat) -> some View {
        GeometryReader { proxy in
            let contentHeight = max(0, proxy.size.height - bottomBarClearance - bottomInset)
            wordScroll(bottomInset: bottomInset, viewportHeight: proxy.size.height)
                .overlay(alignment: .topTrailing) {
                    if isRedSheetEnabled && viewModel.selectedDisplayMode == .list
                        && !viewModel.filteredWords.isEmpty && !viewModel.isLoading {
                        WordRedSheet(
                            topRatio: $redSheetTopRatio,
                            availableHeight: contentHeight,
                            stops: WordListRowSnapping.sheetStops(frames: Array(rowFrames.values), availableHeight: contentHeight)
                        )
                            .frame(width: proxy.size.width / 2, height: proxy.size.height)
                    }
                }
                .coordinateSpace(name: "wordListViewport")
                .onPreferenceChange(WordListRowFramesKey.self) { frames in
                    rowFrames = frames
                    if let id = viewModel.filteredWords.last?.id, let height = frames[id]?.height {
                        lastRowHeight = height
                    }
                }
                .onChange(of: viewModel.filteredWords.last?.id) { _, _ in lastRowHeight = 80 }
        }
            .background(WireColor.surface)
            .clipShape(sheetShape)
            .overlay(
                sheetShape
                    .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase)
            )
            // 左のバーに絞り込み・並べ替え・検索、右のバーに表示切り替えを収める。
            // 横に触ることが多いので、ここから始めたスワイプでは戻さない。
            .overlay(alignment: .bottom) {
                WordListBottomBars(
                    tags: viewModel.availableTags,
                    selectedTag: $viewModel.selectedTagFilter,
                    selectedStatusFilter: $viewModel.selectedStatusFilter,
                    selectedDueFilter: $viewModel.selectedDueFilter,
                    selectedSort: $viewModel.selectedSort,
                    searchText: $viewModel.searchText,
                    selectedDisplayMode: $viewModel.selectedDisplayMode,
                    isRedSheetEnabled: $isRedSheetEnabled
                )
                .background {
                    GeometryReader { bar in
                        Color.clear.preference(key: WordListBarHeightKey.self, value: bar.size.height)
                    }
                }
                .padding(.bottom, bottomInset)
                .backSwipeProtectedRegion()
            }
            .onPreferenceChange(WordListBarHeightKey.self) { bottomBarClearance = $0 }
            .onChange(of: viewModel.selectedDisplayMode) { _, mode in
                if mode == .cards { isRedSheetEnabled = false }
            }
    }

    /// 上端だけ角丸、下端は画面の端まで。引っ張って大きさは変えない。
    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: WireMetrics.radiusLarge,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: WireMetrics.radiusLarge,
            style: .continuous
        )
    }

    /// `List` の行に置いたタップは、行の余白や左右の背景まで一緒に反応してしまう。
    /// 背景は戻るスワイプが使う場所なので、行の枠だけがタップに応えるよう
    /// 自前の縦並びにする（この画面はスワイプ削除も並べ替えも使わない）。
    private func wordScroll(bottomInset: CGFloat, viewportHeight: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(WireColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WireMetrics.spacingXL)
                } else if !viewModel.message.isEmpty && viewModel.words.isEmpty {
                    WordListErrorBox(info: WordListErrorInfo(rawMessage: viewModel.message)) {
                        Task { await viewModel.load(dataSource: appState.studyDataSource) }
                    }
                    .padding(.vertical, WireMetrics.spacingXL)
                } else if viewModel.filteredWords.isEmpty {
                    ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                        .padding(.vertical, WireMetrics.spacingXL)
                } else if viewModel.selectedDisplayMode == .cards {
                    LazyVGrid(columns: cardColumns, spacing: WireMetrics.spacingM) {
                        ForEach(viewModel.filteredWords) { word in
                            WordLibraryCard(word: word)
                                .cardTapTarget { selectedWord = word }
                        }
                    }
                    .padding(WireMetrics.screenPadding)
                } else {
                    ForEach(Array(viewModel.filteredWords.enumerated()), id: \.element.id) { index, word in
                        WordRow(word: word, number: index + 1, hidesMeaningFromAccessibility: isRedSheetEnabled)
                            .cardTapTarget(radius: 0) { selectedWord = word }
                            .background {
                                GeometryReader { row in
                                    Color.clear.preference(
                                        key: WordListRowFramesKey.self,
                                        value: [word.id: row.frame(in: .named("wordListViewport"))]
                                    )
                                }
                            }
                    }
                }
            }
            .scrollTargetLayout(isEnabled: viewModel.selectedDisplayMode == .list)
            // 最終行も上端へ揃えられる余白。カード表示は従来どおりの余白。
            .padding(.bottom, viewModel.selectedDisplayMode == .list
                ? WordListRowSnapping.bottomPadding(
                    viewportHeight: viewportHeight,
                    lastRowHeight: lastRowHeight
                )
                : bottomBarClearance + bottomInset)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(WordListRowScrollBehavior(isEnabled: viewModel.selectedDisplayMode == .list))
    }

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible())
        ]
    }

    /// バナーに並べるデッキ。いまは見た目を決めるための仮の並び。
    /// 所持デッキの取得と、選んだデッキで一覧を差し替える処理はこれから作る
    /// （`docs/plans/word-list-deck-banner-plan.md`）。
    private var bannerDecks: [Deck] {
        [
            Deck(id: 1, deckName: "TOEIC 頻出単語", description: nil),
            Deck(id: 2, deckName: "旅行の英語", description: nil),
            Deck(id: 3, deckName: "会議の英語", description: nil),
            Deck(id: 4, deckName: "接客の英語", description: nil),
            Deck(id: 5, deckName: "ニュースの英語", description: nil)
        ]
    }
}

private struct WordListBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 96
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct WordListRowFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct WordListRowScrollBehavior: ScrollTargetBehavior {
    let isEnabled: Bool

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard isEnabled else { return }
        // 指追従と減速は標準のまま、停止位置だけ各行の先頭に合わせる。
        ViewAlignedScrollTargetBehavior(limitBehavior: .never).updateTarget(&target, context: context)
    }
}

/// 行高は折り返し・文字サイズで変わるため、実測した境界だけを停止候補にする。
enum WordListRowSnapping {
    static func sheetStops(frames: [CGRect], availableHeight: CGFloat) -> [CGFloat] {
        let boundaries = Array(Set(frames.flatMap { [$0.minY, $0.maxY] }))
            .filter { $0.isFinite && $0 >= 0 && $0 <= max(0, availableHeight - 44) }
            .sorted()
        let preferred = boundaries.filter { $0 >= availableHeight * 0.2 && $0 <= availableHeight * 0.8 }
        // 少数の単語や大きな文字で通常範囲に境界がない場合も、行途中には置かない。
        return preferred.isEmpty ? (boundaries.isEmpty ? [0] : boundaries) : preferred
    }

    static func nearestStop(to position: CGFloat, stops: [CGFloat]) -> CGFloat {
        stops.min { abs($0 - position) < abs($1 - position) } ?? 0
    }

    static func adjacentStop(to position: CGFloat, stops: [CGFloat], movingDown: Bool) -> CGFloat {
        let sorted = stops.sorted()
        if movingDown { return sorted.first { $0 > position + 0.5 } ?? sorted.last ?? 0 }
        return sorted.last { $0 < position - 0.5 } ?? sorted.first ?? 0
    }

    static func bottomPadding(viewportHeight: CGFloat, lastRowHeight: CGFloat) -> CGFloat {
        max(0, viewportHeight - lastRowHeight)
    }
}

/// 右半分を覆う不透明なシート。つまみ以外は一覧のスクロールを通す。
private struct WordRedSheet: View {
    @Binding var topRatio: CGFloat
    let availableHeight: CGFloat
    let stops: [CGFloat]
    @State private var settledTop: CGFloat?
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.18)))
    private var dragTranslation: CGFloat?

    private var restingTop: CGFloat {
        settledTop ?? WordListRowSnapping.nearestStop(to: availableHeight * topRatio, stops: stops)
    }

    private var displayedTop: CGFloat {
        guard let dragTranslation else { return restingTop }
        return min(stops.last ?? 0, max(stops.first ?? 0, restingTop + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 上端は直線にして、角丸部分から隠した行の文字が見えないようにする。
            Rectangle()
                .fill(Color(red: 1, green: 0.18, blue: 0.23))
                .padding(.top, displayedTop)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Capsule()
                .fill(.white)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("wordListViewport"))
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            settle(at: restingTop + value.translation.height)
                        }
                )
                .accessibilityLabel("赤シートの高さ")
                .accessibilityValue("行の境界に合わせて移動")
                .accessibilityHint("上下にドラッグして調整。指を離すと行の境界で止まります")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        settle(at: WordListRowSnapping.adjacentStop(to: restingTop, stops: stops, movingDown: false))
                    case .decrement:
                        settle(at: WordListRowSnapping.adjacentStop(to: restingTop, stops: stops, movingDown: true))
                    @unknown default: break
                    }
                }
                .offset(y: displayedTop)
                .backSwipeProtectedRegion()
        }
        .clipped()
        // iOS 17でも減速終了・並べ替え・文字サイズ変更を扱えるよう、実測値の
        // 更新が落ち着いてから合わせ直す。スクロール中はシートを飛び跳ねさせない。
        .task(id: stops) {
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard dragTranslation == nil else { return }
            settle(at: availableHeight * topRatio)
        }
    }

    private func settle(at position: CGFloat) {
        let top = WordListRowSnapping.nearestStop(to: position, stops: stops)
        withAnimation(.easeOut(duration: 0.18)) {
            settledTop = top
            topRatio = top / max(1, availableHeight)
        }
    }
}
