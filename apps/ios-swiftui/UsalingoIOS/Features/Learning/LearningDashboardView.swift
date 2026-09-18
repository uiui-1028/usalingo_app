import SwiftUI
import UniformTypeIdentifiers

/// デッキを開くときの遊び方。タブバー上の切り替えバーで選び、端末に覚えておく。
enum DeckPlayStyle: String, CaseIterable, Identifiable {
    case card
    case choice
    case list

    static let storageKey = "learning.deckPlayStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "カード"
        case .choice: return "5択"
        case .list: return "リスト"
        }
    }
}

/// 学習タブ。デッキをタップすると、選んだ遊び方でそのデッキを開く。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    /// シェルの浮動アクションバーが見えている間だけ、List の末尾へ確保する余白。
    private let bottomActionBarClearance: CGFloat
    private let setActionBarHidden: (Bool) -> Void

    @State private var decks: [Deck] = []
    /// デッキごとの進み具合。カードを読み終えるまでは空のまま出す。
    @State private var summaries: [Int: DeckProgressSummary] = [:]
    @State private var studyLaunch: StudyLaunch?
    /// 並べ替えモード。`.constant` で渡すと `List` 側から抜けられなくなるので、
    /// 書き戻せる状態として持つ。
    @State private var editMode: EditMode = .inactive
    @State private var isShowingLibrary = false
    @State private var wordListDeck: Deck?
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card
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
                .navigationDestination(item: $wordListDeck) { deck in
                    WordListView(deck: deck)
                }
        }
        .task(id: reloadKey) { await reload() }
        .onChange(of: appState.session?.user.id) { _, _ in
            // 利用者が変わったら、前の人の教材を開いている画面を閉じる。
            studyLaunch = nil
            isShowingLibrary = false
            wordListDeck = nil
            decks = []
        }
        // 詳細へのpushでも表示状態は変わらないため、画面ごとの出入りで競合させない。
        .onChange(of: isShowingLibrary) { _, isPresented in
            appState.isShellChromeHidden = isPresented
        }
    }

    /// デッキだけを縦に並べ、エラーがあるときだけ末尾に通知を出す。
    private var list: some View {
        List {
            Section {
                if decks.isEmpty {
                    emptyState
                        .wireListRow()
                } else {
                    ForEach(decks) { deck in
                        deckRow(deck)
                            .wireListRow(vertical: WireMetrics.spacingXS)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if canExport(deck) {
                                    Button("書き出す") { prepareExport(deck) }
                                }
                            }
                    }
                    .onMove(perform: moveHandler)
                    .onDelete(perform: deleteHandler)
                }
            }

            // 通知。エラーがなければグループごと出さない。
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
        // 右上に固定した「デッキ追加」ボタンの下から並べ始める。
        .contentMargins(.top, addDeckButtonClearance, for: .scrollContent)
        // NavigationStack の内側にある List では、外側の safeAreaInset だけでは
        // 最後の行が避けない。末尾をバー高ぶんだけ追加でスクロールできるようにする。
        .contentMargins(.bottom, bottomActionBarClearance, for: .scrollContent)
        // 並べ替え側は双方向 Binding が必要。constant にすると終了操作が反映されない。
        .environment(\.editMode, $editMode)
        .overlay(alignment: .topTrailing) {
            if !isEditing {
                addDeckButton
            }
        }
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

    /// デッキ全体を学習開始の入口にする。長押しによる並べ替えは維持する。
    private func deckRow(_ deck: Deck) -> some View {
        Button {
            guard !isEditing else { return }
            switch playStyle {
            // ponytail: 5択はまだ無いのでカードと同じ学習を開く。5択画面ができたらここで分ける。
            case .card, .choice:
                studyLaunch = StudyLaunch(deck: deck, mode: .all)
            case .list:
                wordListDeck = deck
            }
        } label: {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                    DeckCoverMark(symbol: DeckCoverSymbol.forDeck(id: deck.id))
                    VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                        Text(deck.deckName)
                            .wireFont(.titleS)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DeckMasteryBar(
                    masteredCount: summary(for: deck).masteredCount,
                    totalCount: summary(for: deck).totalCount,
                    ratio: summary(for: deck).masteryRatio,
                    percentText: summary(for: deck).masteryPercentText
                )
                DeckStatusChips(summary: summary(for: deck))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.spacingL)
        }
        // デッキは1件ずつ枠で囲う。どこからどこまでが1つのデッキか、
        // 区切り線だけだと分かりにくかったため（外枠より細い線と1段濃い面）。
        .buttonStyle(.bentoCard(tone: deckCardTone))
        .accessibilityHint(playStyle == .list ? "単語リストを開きます" : "学習を始めます")
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard appState.studyDataSource.supportsDeckReordering, !isEditing else { return }
                withAnimation(.easeInOut(duration: 0.2)) { editMode = .active }
            }
        )
    }

    /// 並べ替え中は行が動くので、追加ボタンは隠す。
    /// ログインの有無では出し分けない。デッキを増やせることは、どちらでも同じにする。
    private var addDeckButton: some View {
        Button {
            isShowingLibrary = true
        } label: {
            Text("デッキ追加 +")
                .wireFont(.label, color: WireColor.surface)
                .padding(.horizontal, WireMetrics.spacingL)
                .frame(height: Self.addDeckButtonHeight)
                .background(Capsule().fill(WireColor.ink))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, WireMetrics.spacingS)
        .padding(.trailing, WireMetrics.screenPadding)
        .accessibilityLabel("デッキを追加")
        .accessibilityHint("デッキライブラリを開きます")
    }

    private static let addDeckButtonHeight: CGFloat = 44

    private var addDeckButtonClearance: CGFloat {
        Self.addDeckButtonHeight + WireMetrics.spacingS + WireMetrics.spacingM
    }

    /// デッキが1件もないときの案内。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text("デッキがありません")
                .wireFont(.body)
            Text("右上の「デッキ追加 +」から追加してください。")
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
    }

    /// デッキカードは背景より1段濃くして、1件ずつの囲いを見せる。
    private var deckCardTone: BentoTone { .l2 }

    /// そのデッキの進み具合。まだ読めていないデッキは 0 枚として出す。
    private func summary(for deck: Deck) -> DeckProgressSummary {
        summaries[deck.id] ?? .empty
    }

    private var reloadKey: String {
        "\(appState.session?.user.id ?? "guest")-\(appState.studyDataVersion)"
    }

    private func reload() async {
        let dataSource = appState.localStudy
        do {
            let fetched = try await dataSource.fetchDecks()
            guard appState.localStudy === dataSource else { return }
            decks = fetched
            errorMessage = nil
            await loadSummaries(for: fetched, from: dataSource)
        } catch {
            guard appState.localStudy === dataSource else { return }
            decks = []
            summaries = [:]
            errorMessage = UserFacingError.message(for: error)
            editMode = .inactive
            return
        }
        if decks.isEmpty {
            editMode = .inactive
        }
    }

    /// デッキごとの進み具合を数える。1件が読めなくても残りの行は出す。
    ///
    /// ponytail: 数え方はデッキのカードを全部読む素直なやり方。デッキが増えるか
    /// 1デッキが大きくなって一覧の表示が遅れたら、データ層に件数だけを返す
    /// 問い合わせ（`fetchDeckCounts` と同じ置き場所）を足して置き換える。
    private func loadSummaries(for decks: [Deck], from dataSource: LocalStudyDataSource) async {
        var loaded: [Int: DeckProgressSummary] = [:]
        for deck in decks {
            guard let cards = try? await dataSource.fetchCards(deckId: deck.id) else { continue }
            loaded[deck.id] = DeckProgressSummary(cards: cards)
        }
        guard appState.localStudy === dataSource else { return }
        summaries = loaded
    }

    /// 並べ替えモードを抜ける。出口はここ1か所にまとめる。
    private func endEditing() {
        withAnimation(.easeInOut(duration: 0.2)) { editMode = .inactive }
    }

    private var moveHandler: ((IndexSet, Int) -> Void)? {
        isEditing && appState.studyDataSource.supportsDeckReordering ? move : nil
    }

    private var deleteHandler: ((IndexSet) -> Void)? {
        isEditing ? delete : nil
    }

    /// 書き出しは端末のデッキファイルが元になる。公式デッキには出さない。
    private func canExport(_ deck: Deck) -> Bool {
        appState.studyDataSource.supportsDeckFileTransfer && appState.studyDataSource.canManage(deck)
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
        let targets = offsets.compactMap { decks.indices.contains($0) ? decks[$0] : nil }
        let dataSource = appState.studyDataSource
        let managed = targets.filter { dataSource.canManage($0) }

        guard !managed.isEmpty else {
            errorMessage = "配信中のデッキは削除できません。"
            return
        }

        Task {
            do {
                for deck in managed {
                    try await dataSource.deleteDeck(id: deck.id)
                }
                errorMessage = managed.count == targets.count
                    ? nil
                    : "配信中のデッキは削除していません。"
                await reload()
            } catch {
                errorMessage = "デッキを削除できませんでした。\(UserFacingError.advice(for: error))"
            }
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
