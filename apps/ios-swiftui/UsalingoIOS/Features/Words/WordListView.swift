import SwiftUI

struct WordListView: View {
    /// 詳細ページへ組み込むときは、バナーを省いて単語シートだけを表示する。
    private let sheetOnly: Bool
    /// シートが画面の高さに占める割合。7.5割で固定し、引っ張っても変えない。
    private static let sheetHeightRatio: CGFloat = 0.75
    /// 浮動バーの高さと下余白のぶん、最後の行が隠れないように空ける量。
    @State private var bottomBarClearance: CGFloat = 96
    @State private var isRedSheetEnabled = false
    @State private var redSheetTopRatio: CGFloat = 0.4
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var lastRowHeight: CGFloat = 80
    @StateObject private var check = RedSheetCheckModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: WordListViewModel
    @State private var selectedWord: WordCard?
    @State private var taggingWord: WordCard?

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list,
        previewRedSheetEnabled: Bool = false,
        previewCheck: RedSheetCheckModel? = nil,
        sheetOnly: Bool = false
    ) {
        self.sheetOnly = sheetOnly
        _check = StateObject(wrappedValue: previewCheck ?? RedSheetCheckModel())
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
            if sheetOnly {
                sheet(bottomInset: 0)
            } else {
                let insets = proxy.safeAreaInsets
                // セーフエリアまで含めた画面の高さ。シートの高さはここから割合で決める。
                let screenHeight = proxy.size.height + insets.top + insets.bottom
                let sheetHeight = isRedSheetEnabled
                    ? proxy.size.height + insets.bottom
                    : screenHeight * Self.sheetHeightRatio
                let bannerHeight = max(0, screenHeight - sheetHeight - insets.top - WireMetrics.spacingS)

                ZStack(alignment: .top) {
                    // シートより1段退いた面。これで前後関係を作る。
                    WireColor.scrim
                        .ignoresSafeArea()

                    if !isRedSheetEnabled {
                        deckBanner
                        .padding(.horizontal, WireMetrics.screenPadding)
                        .padding(.top, WireMetrics.spacingS)
                        .frame(height: bannerHeight + WireMetrics.spacingS, alignment: .top)
                        .transition(.opacity)
                    }

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        sheet(bottomInset: insets.bottom)
                            .frame(height: sheetHeight)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: isRedSheetEnabled)
            }
        }
        // 操作はすべてシートの中の浮動バーに集めたので、上のヘッダーごと消す。
        // ヘッダーを消すと戻るスワイプも一緒に止まるため、学習画面と同じ仕組みで戻す。
        .toolbar(sheetOnly && !isRedSheetEnabled ? .visible : .hidden, for: .navigationBar)
        .background {
            if !sheetOnly || isRedSheetEnabled { BackSwipeEnabler() }
            // 未保存の判定を置いたまま画面を離れない。再タップできる赤シートボタンを使う。
            if isRedSheetEnabled { BackSwipeProtectedRegionMarker() }
        }
        .onChange(of: isRedSheetEnabled) { _, enabled in
            if enabled {
                startCheck()
            } else {
                check.reset()
            }
        }
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word, words: viewModel.filteredWords) { savedWord in
                _ = viewModel.replaceWord(savedWord)
            }
        }
        .sheet(item: $taggingWord) { word in
            TagSheet(word: word) { savedWord in
                _ = viewModel.replaceWord(savedWord)
                check.replaceWord(savedWord)
            }
            .presentationDetents([.medium])
        }
        .task(id: appState.session?.user.id ?? "guest") {
            if sheetOnly {
                await viewModel.load(dataSource: appState.studyDataSource)
            } else {
                await viewModel.loadDecks(
                    dataSource: appState.studyDataSource,
                    preferredDeckID: appState.wordListDeckID
                )
            }
        }
        // 浮いているタブバーが一覧の末尾に重なるので、この画面にいる間は
        // シェルの操作面を隠す。戻る導線はスワイプが担う。
        .onAppear {
            if !sheetOnly { appState.isShellChromeHidden = true }
        }
        .onDisappear {
            if !sheetOnly { appState.isShellChromeHidden = false }
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
                        && !displayedWords.isEmpty && !viewModel.isLoading && !check.isComplete {
                        WordRedSheet(
                            topRatio: $redSheetTopRatio,
                            availableHeight: contentHeight,
                            stops: check.isStarted ? checkStops : WordListRowSnapping.sheetStops(frames: Array(rowFrames.values), availableHeight: contentHeight),
                            controlledTop: check.isStarted ? checkSheetTop : nil,
                            onSettle: check.isStarted ? { position in
                                guard let frame = currentRowFrame else { return }
                                check.isAnswerVisible = position >= frame.midY
                            } : nil
                        )
                            .frame(width: proxy.size.width / 2, height: proxy.size.height)
                    }
                }
                .coordinateSpace(name: "wordListViewport")
                .onPreferenceChange(WordListRowFramesKey.self) { frames in
                    rowFrames = frames
                    if let id = displayedWords.last?.id, let height = frames[id]?.height {
                        lastRowHeight = height
                    }
                }
                .onChange(of: displayedWords.last?.id) { _, _ in lastRowHeight = 80 }
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
                Group {
                    if isRedSheetEnabled {
                        redSheetControls
                    } else {
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
                    }
                }
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
        ScrollViewReader { reader in
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
                    } else if displayedWords.isEmpty {
                        ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                            .padding(.vertical, WireMetrics.spacingXL)
                    } else if viewModel.selectedDisplayMode == .cards {
                        LazyVGrid(columns: cardColumns, spacing: WireMetrics.spacingM) {
                            ForEach(displayedWords) { word in
                                WordLibraryCard(word: word)
                                    .cardTapTarget { selectedWord = word }
                            }
                        }
                        .padding(WireMetrics.screenPadding)
                    } else {
                        ForEach(Array(displayedWords.enumerated()), id: \.element.id) { index, word in
                            WordRow(
                                word: word,
                                number: index + 1,
                                hidesMeaningFromAccessibility: meaningIsHidden(at: index),
                                checkResult: check.answers[word.id],
                                reservesCheckResultSpace: check.isStarted,
                                isCheckTarget: check.current?.id == word.id,
                                coversMeaning: check.isStarted && meaningIsHidden(at: index)
                            )
                                .cardTapTarget(radius: 0) {
                                    if check.isStarted {
                                        if word.id == check.current?.id { check.isAnswerVisible = true }
                                    } else {
                                        selectedWord = word
                                    }
                                }
                                .id(word.id)
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
            .onChange(of: check.current?.id) { _, id in
                guard let id else { return }
                // 前の印を少し残しつつ、大きな文字でも対象行が画面内に収まる位置へ進める。
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    reader.scrollTo(id, anchor: UnitPoint(x: 0, y: 0.25))
                }
            }
        }
    }

    private var displayedWords: [WordCard] { check.isStarted ? check.words : viewModel.filteredWords }
    private var currentRowFrame: CGRect? { check.current.flatMap { rowFrames[$0.id] } }
    private var checkStops: [CGFloat] {
        guard let frame = currentRowFrame else { return [0] }
        return [max(0, frame.minY), max(0, frame.maxY)]
    }
    private var checkSheetTop: CGFloat {
        guard let frame = currentRowFrame else { return 0 }
        return max(0, check.isAnswerVisible ? frame.maxY : frame.minY)
    }

    private func meaningIsHidden(at index: Int) -> Bool {
        guard isRedSheetEnabled else { return false }
        guard check.isStarted else { return true }
        return index > check.index || (index == check.index && !check.isAnswerVisible)
    }

    private func startCheck() {
        check.start(words: viewModel.filteredWords, source: appState.studyDataSource) { word in
            viewModel.replaceWord(word)
            appState.markStudyDataChanged()
        }
    }

    private var redSheetControls: some View {
        VStack(spacing: 10) {
            redSheetSaveStatus
            StudyAnswerActionBar(
                correctSymbol: "circle",
                incorrectLabel: check.isAnswerVisible ? "不正解" : "答えを表示。もう一度押すと不正解",
                correctLabel: check.isAnswerVisible ? "正解" : "答えを表示。もう一度押すと正解",
                isDisabled: check.current == nil || check.isUndoing,
                onIncorrect: { check.revealOrSubmit(isCorrect: false) },
                onCorrect: { check.revealOrSubmit(isCorrect: true) }
            ) {
                redSheetToolbar
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var redSheetSaveStatus: some View {
        if let error = check.errorMessage {
            VStack(spacing: WireMetrics.spacingS) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("もう一度保存", action: check.retry)
                    .buttonStyle(.wireSecondary)
                    .disabled(check.pendingCount == 0 || check.isSaving || check.isUndoing)
            }
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private var redSheetToolbar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button(action: endRedSheet) {
                Image(systemName: "rectangle.fill")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.wireIcon(diameter: 40, isSelected: true, invertsWhenSelected: true))
            .disabled(!check.canLeave)
            .accessibilityLabel("赤シート")
            .accessibilityValue("オン")
            .accessibilityHint("赤シートを終了します")

            Button {
                taggingWord = check.current
            } label: {
                Image(systemName: "tag")
            }
            .buttonStyle(.wireIcon(diameter: 40))
            .disabled(check.current == nil)
            .accessibilityLabel("タグ")
        }
        .padding(.horizontal, WireMetrics.spacingM)
        .padding(.vertical, WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
    }

    private func endRedSheet() {
        guard check.canLeave else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88)) {
            isRedSheetEnabled = false
        }
    }

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible())
        ]
    }

    /// 背面のデッキ選択。0件と取得失敗は札を並べず、1行の案内にとどめる。
    @ViewBuilder
    private var deckBanner: some View {
        if viewModel.decks.isEmpty {
            Text(viewModel.deckMessage.isEmpty ? "デッキがありません" : viewModel.deckMessage)
                .wireFont(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WordListDeckBanner(decks: viewModel.decks, selectedDeckID: viewModel.deck?.id) { deck in
                appState.wordListDeckID = deck.id
                Task { await viewModel.selectDeck(deck, dataSource: appState.studyDataSource) }
            }
        }
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
        // 通常範囲（20〜80%）に加え、その外側の境界を上下1行分ずつ動かせる範囲に含める。
        guard let first = boundaries.firstIndex(where: { $0 >= availableHeight * 0.2 }),
              let last = boundaries.lastIndex(where: { $0 <= availableHeight * 0.8 }),
              first <= last else {
            // 少数の単語や大きな文字で通常範囲に境界がない場合も、行途中には置かない。
            return boundaries.isEmpty ? [0] : boundaries
        }
        return Array(boundaries[max(0, first - 1)...min(boundaries.count - 1, last + 1)])
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
    var controlledTop: CGFloat? = nil
    var onSettle: ((CGFloat) -> Void)? = nil
    @State private var settledTop: CGFloat?
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.18)))
    private var dragTranslation: CGFloat?

    private var restingTop: CGFloat {
        controlledTop ?? settledTop ?? WordListRowSnapping.nearestStop(to: availableHeight * topRatio, stops: stops)
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
            guard controlledTop == nil else { return }
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard dragTranslation == nil else { return }
            settle(at: availableHeight * topRatio)
        }
    }

    private func settle(at position: CGFloat) {
        let top = WordListRowSnapping.nearestStop(to: position, stops: stops)
        if let onSettle {
            onSettle(top)
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            settledTop = top
            topRatio = top / max(1, availableHeight)
        }
    }
}
