import SwiftUI
import UniformTypeIdentifiers

/// 学習タブ。1列のデッキリスト（D-4）。行をタップしたら確認を挟まずに学習画面へ入る（D-8）。
/// 「どう遊ぶか」を決める `DeckConceptView` は、行の右端のボタンから開く。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var decks: [Deck] = []
    @State private var countsByDeckId: [Int: StudyDeckCounts] = [:]
    @State private var selectedDeck: Deck?
    @State private var conceptDeck: Deck?
    @State private var isEditing = false
    @State private var isShowingLibrary = false
    @State private var isShowingWordList = false
    @State private var errorMessage: String?
    @State private var exportDocument: DeckDocument?
    @State private var exportFileName = "deck"

    var body: some View {
        NavigationStack {
            list
                .navigationDestination(item: $selectedDeck) { deck in
                    StudySessionView(deck: deck)
                }
                .navigationDestination(item: $conceptDeck) { deck in
                    DeckConceptView(deck: deck, counts: countsByDeckId[deck.id])
                }
                .navigationDestination(isPresented: $isShowingLibrary) {
                    DeckLibraryView { Task { await reload() } }
                }
                .navigationDestination(isPresented: $isShowingWordList) {
                    WordListView()
                }
        }
        .task(id: reloadKey) { await reload() }
    }

    /// 画面は上から「デッキ一覧」「保存したコンセプト」「単語」「操作」「通知」へ分ける。
    /// 下へ行くほど面を1段濃くする（計画書 6）。
    private var list: some View {
        List {
            // まとまり1: デッキ一覧。List のまま行背景で1つの枠を描くので、
            // swipeActions / onMove / onDelete はそのまま使える。
            Section {
                // 見出しと行の左端を揃えるため、余白は行の中身側で持つ。
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text("デッキ一覧")
                        .wireFont(.titleS)
                    // 習得率と習得・苦手の数はまだデータ層から出せないので、
                    // 仮の数字であることをここで断る（デザインタブと同じ扱い）。
                    WireframeNotice(text: "習得率と、習得・苦手の数はまだ仮の数字です。")
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(WireMetrics.spacingL)
                    .bentoListRow(
                        position: .top,
                        tone: deckGroupTone,
                        showsDivider: true
                    )

                if decks.isEmpty {
                    emptyState
                        .bentoListRow(position: .bottom, tone: deckGroupTone)
                } else {
                    ForEach(decks) { deck in
                        let isLast = deck.id == decks.last?.id
                        deckRow(deck)
                            .bentoListRow(
                                position: isLast ? .bottom : .middle,
                                tone: deckGroupTone,
                                showsDivider: !isLast
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
            }

            // まとまり2: 保存したコンセプト（A-5）。デッキより先に「遊び方」から入る導線。
            Section {
                BentoGroup(title: "保存したコンセプト", tone: .l2) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WireMetrics.spacingS) {
                            ForEach(SavedConcept.samples) { concept in
                                SavedConceptCard(concept: concept)
                            }
                        }
                        .padding(.vertical, WireMetrics.strokeHeavy)
                    }
                    WireframeNotice(text: "保存先はまだありません。並びを見るためのサンプルです。")
                }
                .wireListRow()
            }

            // まとまり3: 単語（D-1 / D-2 / D-3）。作ってあった単語画面への入口。
            Section {
                BentoGroup(title: "単語", tone: .l2) {
                    Button {
                        isShowingWordList = true
                    } label: {
                        wordEntryRow(
                            title: "単語をさがす",
                            detail: "タグ・品詞・状態でしぼれます"
                        )
                    }
                    .buttonStyle(.bentoRow(tone: .l2))

                    Button {
                        isShowingWordList = true
                    } label: {
                        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                            wordEntryRow(title: "最近学習した単語", detail: nil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: WireMetrics.spacingS) {
                                    ForEach(DeckDisplaySample.recentWordsSample, id: \.self) { word in
                                        WirePill(title: word, font: .caption)
                                    }
                                }
                                .padding(.vertical, WireMetrics.strokeHeavy)
                            }
                        }
                    }
                    .buttonStyle(.bentoRow(tone: .l2))
                }
                .wireListRow()
            }

            // まとまり4: 操作。
            if appState.isGuest {
                Section {
                    BentoGroup(tone: .l3) {
                        VStack(spacing: WireMetrics.spacingM) {
                            if isEditing {
                                Button("編集を終える") {
                                    isEditing = false
                                }
                                .buttonStyle(.wireSecondary)
                            }

                            Button("＋ デッキを追加") {
                                isEditing = false
                                isShowingLibrary = true
                            }
                            .buttonStyle(.wirePrimary)
                        }
                    }
                    .wireListRow()
                }
            }

            // まとまり5: 通知。エラーがなければグループごと出さない。
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
                    .wireListRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(WireColor.background)
        .contentMargins(.top, WireMetrics.spacingM, for: .scrollContent)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
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

    /// 行の本体をタップしたら、確認を挟まずに学習画面へ入る（D-8）。
    /// コンセプト画面は行の右端のボタンから開く。
    private func deckRow(_ deck: Deck) -> some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            // 上段だけを2列に分ける。習得率バーと内訳チップは行の幅いっぱいを使えるので、
            // 文字が「…」で切れない。
            HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                Button {
                    guard !isEditing else { return }
                    selectedDeck = deck
                } label: {
                    HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                        // B-12 見分けの記号。色相を使えないので枠と記号で区別する。
                        DeckCoverMark(symbol: sample(for: deck).coverSymbol)

                        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                            Text(deck.deckName)
                                .wireFont(.titleS)
                            // B-1 説明文。取得済みなのに出していなかった。
                            Text(deck.description ?? "説明はまだありません")
                                .wireFont(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                // 行は枠を持たない。押せることは押下中の面の濃さと縮小で示す。
                .buttonStyle(.bentoRow(tone: deckGroupTone))
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                        if appState.isGuest { isEditing = true }
                    }
                )

                Button {
                    guard !isEditing else { return }
                    conceptDeck = deck
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .wireFont(.titleS)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.bentoRow(tone: deckGroupTone))
                .accessibilityLabel("\(deck.deckName) のコンセプトを選ぶ")
            }

            // B-2 / B-3 分母と習得率。
            DeckMasteryBar(
                masteredCount: sample(for: deck).masteredCount,
                totalCount: sample(for: deck).totalCount,
                ratio: sample(for: deck).masteryRatio,
                percentText: sample(for: deck).masteryPercentText
            )
            // B-4 状態内訳。
            DeckStatusChips(sample: sample(for: deck))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
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
            Image(systemName: "chevron.right")
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, WireMetrics.spacingS)
    }

    /// デッキ一覧グループの中に収める空状態。枠は外側のグループが持つので重ねない。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text("デッキがありません")
                .wireFont(.body)
            Text(appState.isGuest ? "「＋ デッキを追加」から追加してください。" : "利用できるデッキがまだありません。")
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
    }

    /// デッキ一覧は画面の一番上のまとまりなので、最も薄い段を使う。
    private var deckGroupTone: BentoTone { .l1 }

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
            isEditing = false
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
            isEditing = false
        }
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
