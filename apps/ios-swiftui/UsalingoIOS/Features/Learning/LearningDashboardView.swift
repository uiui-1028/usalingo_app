import SwiftUI
import UniformTypeIdentifiers

/// 学習タブ。デッキをタップして学習モード設定を開き、上部の開始ボタンから学習へ進む。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    /// シェルの浮動アクションバーが見えている間だけ、List の末尾へ確保する余白。
    private let bottomActionBarClearance: CGFloat
    private let setActionBarHidden: (Bool) -> Void

    @State private var decks: [Deck] = []
    @State private var countsByDeckId: [Int: StudyDeckCounts] = [:]
    @State private var studyLaunch: StudyLaunch?
    @State private var pendingStudyLaunch: StudyLaunch?
    @State private var conceptDeck: Deck?
    /// 開始ボタンをシートの外へ出したので、選ばれた学習モードはここで持つ。
    @State private var conceptMode: StudyMode = .all
    /// シート高を自分で決めるために測る、画面（ウィンドウ）全体の高さ。
    @State private var windowHeight: CGFloat = 0
    /// 並べ替えモード。`.constant` で渡すと `List` 側から抜けられなくなるので、
    /// 書き戻せる状態として持つ。
    @State private var editMode: EditMode = .inactive
    @State private var isShowingLibrary = false
    @State private var isShowingWordList = false
    @State private var errorMessage: String?
    @State private var exportDocument: DeckDocument?
    @State private var exportFileName = "deck"
    @State private var previousVerticalDragTranslation: CGFloat?

    init(
        bottomActionBarClearance: CGFloat = 0,
        setActionBarHidden: @escaping (Bool) -> Void = { _ in }
    ) {
        self.bottomActionBarClearance = bottomActionBarClearance
        self.setActionBarHidden = setActionBarHidden
    }

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack {
            list
                .navigationDestination(item: $studyLaunch) { launch in
                    StudySessionView(deck: launch.deck, studyMode: launch.mode)
                }
                .navigationDestination(isPresented: $isShowingLibrary) {
                    DeckLibraryView { Task { await reload() } }
                }
                .navigationDestination(isPresented: $isShowingWordList) {
                    WordListView()
                }
        }
        .background {
            // シート高を自分で決めるので、画面全体の高さを測っておく。
            GeometryReader { proxy in
                Color.clear
                    .onAppear { windowHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in windowHeight = height }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $conceptDeck, onDismiss: {
            // Wait until the sheet is gone before pushing the study screen.
            guard let pendingStudyLaunch else { return }
            self.pendingStudyLaunch = nil
            studyLaunch = pendingStudyLaunch
        }) { deck in
            DeckConceptSheet(
                deck: deck,
                counts: countsByDeckId[deck.id],
                selectedMode: $conceptMode
            ) { mode in
                pendingStudyLaunch = StudyLaunch(deck: deck, mode: mode)
                conceptDeck = nil
            }
            // 高さは1つに固定する。上端に「始める」の帯を持つぶん、面より少し高い。
            .presentationDetents([.height(conceptSheetHeight)])
            // 面の上端はシート枠ではなくパネル側にあるので、標準の指示子は使わない。
            .presentationDragIndicator(.hidden)
            // 面はシートの中で自分で描く。枠の背景は透かして、上端の帯を地に見せる。
            .presentationBackground { Color.clear }
            // 枠の角丸は面（パネル）側で描くので、シート枠側は角を持たせない。
            .presentationCornerRadius(0)
            // 背景を暗くしない。透かした帯の向こうにデッキ一覧を見せるため。
            .presentationBackgroundInteraction(.enabled)
        }
        .task(id: reloadKey) { await reload() }
    }

    /// シートの高さ。面（画面の約72%）と、その上に載せる「始める」の帯を足した値。
    /// まだ画面を測れていないときは安全側の固定値を使う。
    private var conceptSheetHeight: CGFloat {
        guard windowHeight > 0 else { return 520 + startButtonStripHeight }
        return windowHeight * 0.72 + startButtonStripHeight
    }

    /// 「始める」の帯の高さ。ボタンの上下余白（spacingM×2）＋文字の行と、面とのすき間。
    private var startButtonStripHeight: CGFloat {
        (WireMetrics.spacingM * 2) + 22 + WireMetrics.spacingM
    }

    /// 画面は上から「デッキ一覧」「単語」「操作」「通知」へ分ける。
    /// 下へ行くほど面を1段濃くする（計画書 6）。
    private var list: some View {
        List {
            // まとまり1: デッキ一覧。List のまま行背景で1つの枠を描くので、
            // swipeActions / onMove / onDelete はそのまま使える。
            Section {
                // 見出しと行の左端を揃えるため、余白は行の中身側で持つ。
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    HStack(alignment: .firstTextBaseline, spacing: WireMetrics.spacingS) {
                        Text("デッキ一覧")
                            .wireFont(.titleS)
                        Spacer(minLength: WireMetrics.spacingS)
                        // 並べ替え中は、必ず見えるところに出口を置く。
                        // 下のほうのボタンだけだと画面外になって戻れなくなる。
                        if isEditing {
                            Button {
                                endEditing()
                            } label: {
                                WirePill(title: "並べ替えを終える", font: .caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // 習得率と習得・苦手の数はまだデータ層から出せないので、
                    // 仮の数字であることをここで断る（デザインタブと同じ扱い）。
                    WireframeNotice(text: "習得率と、習得・苦手の数はまだ仮の数字です。")
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(WireMetrics.spacingL)
                    .bentoListRow(
                        position: isEditing ? .single : .top,
                        tone: deckGroupTone,
                        showsDivider: !isEditing
                    )

                if decks.isEmpty {
                    emptyState
                        .bentoListRow(
                            position: showsAddDeckRow ? .middle : .bottom,
                            tone: deckGroupTone,
                            showsDivider: showsAddDeckRow
                        )
                } else {
                    ForEach(decks) { deck in
                        let isLast = deck.id == decks.last?.id && !showsAddDeckRow
                        deckRow(deck)
                            // 並べ替え中は行が動くので、行をまたいで1つの枠を描く
                            // 「はみ出させて切り取る」描き方をやめ、行ごとに閉じた枠にする。
                            // そうしないと切り取られた枠だけが残って見た目が壊れる。
                            // 1件ずつ枠で囲うので、行と行のあいだは区切り線ではなく
                            // すき間で離す。線とカード枠が二重にならないようにする。
                            .bentoListRow(
                                position: isEditing
                                    ? .single
                                    : (isLast ? .bottom : .middle),
                                tone: deckGroupTone,
                                showsDivider: false,
                                // 外枠とカードの線が近すぎて窮屈だったので、左右を少し広げる。
                                horizontal: WireMetrics.spacingS,
                                vertical: WireMetrics.spacingXS
                            )
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if appState.isGuest {
                                    Button("書き出す") { prepareExport(deck) }
                                }
                            }
                    }
                    .onMove(perform: moveHandler)
                    .onDelete(perform: deleteHandler)
                }

                // デッキ追加はデッキ一覧の最後の行に置く。画面下の操作グループだけだと
                // 下のまとまりに押し出されて見つからなくなる。
                if showsAddDeckRow {
                    addDeckRow
                        .bentoListRow(position: .bottom, tone: deckGroupTone)
                }
            }

            // まとまり2: 単語リスト（D-1 / D-2）。作ってあった単語画面への入口。
            // 見出しと行で同じことを言わないよう、グループ見出しは置かず1行にまとめる。
            Section {
                BentoGroup(tone: .l2) {
                    Button {
                        isShowingWordList = true
                    } label: {
                        wordEntryRow(
                            title: "単語リスト",
                            detail: "タグ・品詞・状態でしぼれます"
                        )
                    }
                    .buttonStyle(.bentoRow(tone: .l2))
                }
                .endsDeckEditingOnTap(isEditing) { endEditing() }
                .wireListRow()
            }

            // まとまり3: 操作。並べ替え中の出口だけを置く（追加はデッキ一覧の中）。
            if appState.isGuest && isEditing {
                Section {
                    BentoGroup(tone: .l3) {
                        Button("編集を終える") {
                            endEditing()
                        }
                        .buttonStyle(.wireSecondary)
                    }
                    .endsDeckEditingOnTap(isEditing) { endEditing() }
                    .wireListRow()
                }
            }

            // まとまり4: 通知。エラーがなければグループごと出さない。
            if let errorMessage {
                Section {
                    BentoGroup(title: "通知", tone: .l3) {
                        // 色相を使わずに異常を示す（破線 + 文言）。
                        Text(errorMessage)
                            .wireFont(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(WireMetrics.spacingM)
                            .outlineSurface(
                                radius: WireMetrics.radiusControl,
                                shadow: nil,
                                dashed: true,
                                fill: BentoTone.l3.fill
                            )
                    }
                    .endsDeckEditingOnTap(isEditing) { endEditing() }
                    .wireListRow()
                }
            }
        }
        .listStyle(.plain)
        // 行の隙間や余白など、どの行も受け取らなかったタップ。
        // `gesture` は行の中身に負けるので、デッキ行の操作は邪魔しない。
        .gesture(TapGesture().onEnded { endEditing() }, including: isEditing ? .all : .none)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, WireMetrics.spacingM, for: .scrollContent)
        // NavigationStack の内側にある List では、外側の safeAreaInset だけでは
        // 最後の行が避けない。末尾をバー高ぶんだけ追加でスクロールできるようにする。
        .contentMargins(.bottom, bottomActionBarClearance, for: .scrollContent)
        // 並べ替え側は双方向 Binding が必要。constant にすると終了操作が反映されない。
        .environment(\.editMode, $editMode)
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged(updateActionBarVisibility)
                .onEnded { _ in previousVerticalDragTranslation = nil },
            including: .subviews
        )
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "デッキを書き出せませんでした。\(UserFacingError.advice(for: error))"
            }
        }
    }

    private func updateActionBarVisibility(_ value: DragGesture.Value) {
        guard abs(value.translation.height) > abs(value.translation.width) else {
            previousVerticalDragTranslation = nil
            return
        }

        defer { previousVerticalDragTranslation = value.translation.height }
        guard let previousVerticalDragTranslation else { return }

        let verticalMovement = value.translation.height - previousVerticalDragTranslation
        guard abs(verticalMovement) > 0.5 else { return }
        setActionBarHidden(verticalMovement < 0)
    }

    /// デッキ全体を設定への入口にする。長押しによる並べ替えは維持する。
    private func deckRow(_ deck: Deck) -> some View {
        Button {
            guard !isEditing else { return }
            conceptMode = .all
            conceptDeck = deck
        } label: {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                    DeckCoverMark(symbol: sample(for: deck).coverSymbol)
                    VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                        Text(deck.deckName)
                            .wireFont(.titleS)
                        Text(deck.description ?? "説明はまだありません")
                            .wireFont(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DeckMasteryBar(
                    masteredCount: sample(for: deck).masteredCount,
                    totalCount: sample(for: deck).totalCount,
                    ratio: sample(for: deck).masteryRatio,
                    percentText: sample(for: deck).masteryPercentText
                )
                DeckStatusChips(sample: sample(for: deck))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.spacingL)
        }
        // デッキは1件ずつ枠で囲う。どこからどこまでが1つのデッキか、
        // 区切り線だけだと分かりにくかったため（外枠より細い線と1段濃い面）。
        .buttonStyle(.bentoCard(tone: deckCardTone))
        .accessibilityHint("学習モード設定を開きます")
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard appState.isGuest, !isEditing else { return }
                withAnimation(.easeInOut(duration: 0.2)) { editMode = .active }
            }
        )
    }

    /// 単語画面への入口の1行。枠は外側のグループが持つので重ねない。
    private func wordEntryRow(title: String, detail: String?) -> some View {
        HStack(spacing: WireMetrics.spacingM) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                Text(title)
                    .wireFont(.label)
                if let detail {
                    Text(detail)
                        .wireFont(.caption)
                }
            }
            Spacer(minLength: WireMetrics.spacingS)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, WireMetrics.spacingS)
    }

    /// 並べ替え中は行が動くので、追加行は出さない。
    private var showsAddDeckRow: Bool { appState.isGuest && !isEditing }

    /// デッキ一覧グループの最後に置く「デッキを追加」の行。
    private var addDeckRow: some View {
        Button {
            endEditing()
            isShowingLibrary = true
        } label: {
            HStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "plus")
                    .wireFont(.label)
                    .accessibilityHidden(true)
                Text("デッキを追加")
                    .wireFont(.label)
                Spacer(minLength: WireMetrics.spacingS)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.spacingL)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bentoRow(tone: deckGroupTone))
        .accessibilityLabel("デッキを追加")
        .accessibilityHint("デッキライブラリを開きます")
    }

    /// デッキ一覧グループの中に収める空状態。枠は外側のグループが持つので重ねない。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text("デッキがありません")
                .wireFont(.body)
            Text(appState.isGuest ? "下の「デッキを追加」から追加してください。" : "利用できるデッキがまだありません。")
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
    }

    /// デッキ一覧は画面の一番上のまとまりなので、最も薄い段を使う。
    private var deckGroupTone: BentoTone { .l1 }

    /// グループの中に置くデッキカードは、外枠より1段濃くして囲いを見せる。
    private var deckCardTone: BentoTone { .l2 }

    /// デッキIDから決まる仮の表示値。開き直しても数字が動かないようにしている。
    private func sample(for deck: Deck) -> DeckDisplaySample {
        DeckDisplaySample.forDeck(id: deck.id)
    }

    private var reloadKey: String {
        "\(appState.session?.user.id ?? "guest")-\(appState.studyDataVersion)"
    }

    private func reload() async {
        let dataSource = appState.studyDataSource
        var counts: [Int: StudyDeckCounts] = [:]
        var failed: [String] = []
        do {
            decks = try await dataSource.fetchDecks()
        } catch {
            decks = []
            countsByDeckId = [:]
            errorMessage = UserFacingError.message(for: error)
            editMode = .inactive
            return
        }
        for deck in decks {
            do {
                counts[deck.id] = try await dataSource.fetchDeckCounts(deckId: deck.id)
            } catch {
                failed.append(deck.deckName)
            }
        }
        countsByDeckId = counts
        errorMessage = failed.isEmpty ? nil : "\(failed.joined(separator: "、")) のカードを読み込めませんでした。"
        if decks.isEmpty {
            editMode = .inactive
        }
    }

    /// 並べ替えモードを抜ける。出口はここ1か所にまとめる。
    private func endEditing() {
        withAnimation(.easeInOut(duration: 0.2)) { editMode = .inactive }
    }

    private var moveHandler: ((IndexSet, Int) -> Void)? {
        isEditing ? move : nil
    }

    private var deleteHandler: ((IndexSet) -> Void)? {
        isEditing ? delete : nil
    }

    private func prepareExport(_ deck: Deck) {
        do {
            guard let localDeck = appState.localStudy.deck(id: deck.id) else {
                throw LocalStudyError.deckNotFound
            }
            exportFileName = localDeck.key
            exportDocument = DeckDocument(data: try appState.localStudy.exportData(deckId: deck.id))
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try appState.localStudy.moveDecks(fromOffsets: source, toOffset: destination)
            Task { await reload() }
        } catch {
            errorMessage = "並び順を保存できませんでした。"
        }
    }

    private func delete(atOffsets offsets: IndexSet) {
        do {
            try appState.localStudy.removeDecks(atOffsets: offsets)
            Task { await reload() }
        } catch {
            errorMessage = "デッキを削除できませんでした。"
        }
    }
}

#if DEBUG
#Preview("Learning Dashboard") {
    LearningDashboardView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif

private extension View {
    /// デッキ一覧の外側をタップしたら並べ替えを終える。
    /// 画面下のアクションバーはこの `List` の外にあるので、ここでは反応しない。
    func endsDeckEditingOnTap(_ isEditing: Bool, action: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded { action() },
                including: isEditing ? .all : .none
            )
    }
}
