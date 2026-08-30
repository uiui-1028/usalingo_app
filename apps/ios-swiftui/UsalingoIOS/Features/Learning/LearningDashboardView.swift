import SwiftUI
import UniformTypeIdentifiers

/// 学習タブ。1列のデッキリスト（D-4）。行をタップしたら確認を挟まずに学習画面へ入る（D-8）。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var decks: [LocalDeck] = []
    @State private var countsByDeckId: [Int: LocalDeckCounts] = [:]
    @State private var selectedDeck: Deck?
    @State private var isEditing = false
    @State private var isShowingLibrary = false
    @State private var errorMessage: String?
    @State private var exportDocument: DeckDocument?
    @State private var exportFileName = "deck"

    var body: some View {
        NavigationStack {
            list
                .navigationDestination(item: $selectedDeck) { deck in
                    StudySessionView(deck: deck)
                }
                .navigationDestination(isPresented: $isShowingLibrary) {
                    DeckLibraryView { reload() }
                }
        }
        .task { reload() }
        .task(id: appState.studyDataVersion) { reload() }
    }

    /// 画面は上から「デッキ一覧」「操作」「通知」の3つのまとまりへ分ける。
    /// 下へ行くほど面を1段濃くする（計画書 6）。
    private var list: some View {
        List {
            // まとまり1: デッキ一覧。List のまま行背景で1つの枠を描くので、
            // swipeActions / onMove / onDelete はそのまま使える。
            Section {
                // 見出しと行の左端を揃えるため、余白は行の中身側で持つ。
                Text("デッキ一覧")
                    .wireFont(.titleS)
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
                                Button("書き出す") { prepareExport(deck) }
                            }
                    }
                    .onMove(perform: moveHandler)
                    .onDelete(perform: deleteHandler)
                }
            }

            // まとまり2: 操作。
            Section {
                BentoGroup(tone: .l2) {
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

            // まとまり3: 通知。エラーがなければグループごと出さない。
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

    private func deckRow(_ deck: LocalDeck) -> some View {
        Button {
            guard !isEditing else { return }
            selectedDeck = deck.deck
        } label: {
            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                Text(deck.name)
                    .wireFont(.titleS)
                Text(counterText(for: deck))
                    .wireFont(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.spacingL)
        }
        // 行は枠を持たない。押せることは押下中の面の濃さと縮小で示す。
        .buttonStyle(.bentoRow(tone: deckGroupTone))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                isEditing = true
            }
        )
    }

    /// デッキ一覧グループの中に収める空状態。枠は外側のグループが持つので重ねない。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text("デッキがありません")
                .wireFont(.body)
            Text("「＋ デッキを追加」から追加してください。")
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
    }

    /// デッキ一覧は画面の一番上のまとまりなので、最も薄い段を使う。
    private var deckGroupTone: BentoTone { .l1 }

    private func counterText(for deck: LocalDeck) -> String {
        guard let counts = countsByDeckId[deck.id] else { return "新規 - ・ 復習 -" }
        return "新規 \(counts.newCount) ・ 復習 \(counts.dueCount)"
    }

    private func reload() {
        decks = appState.localStudy.decks()
        var counts: [Int: LocalDeckCounts] = [:]
        var failed: [String] = []
        for deck in decks {
            do {
                counts[deck.id] = try appState.localStudy.counts(deckId: deck.id)
            } catch {
                failed.append(deck.name)
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

    private func prepareExport(_ deck: LocalDeck) {
        do {
            exportFileName = deck.key
            exportDocument = DeckDocument(data: try appState.localStudy.exportData(deckId: deck.id))
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try appState.localStudy.moveDecks(fromOffsets: source, toOffset: destination)
            reload()
        } catch {
            errorMessage = "並び順を保存できませんでした。"
        }
    }

    private func delete(atOffsets offsets: IndexSet) {
        do {
            try appState.localStudy.removeDecks(atOffsets: offsets)
            reload()
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
