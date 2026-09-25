import SwiftUI
import UniformTypeIdentifiers

/// デッキを開くときの遊び方。タブバー上の切り替えバーで選び、端末に覚えておく。
enum DeckPlayStyle: String, CaseIterable, Identifiable {
    // バーには宣言順に左から並ぶ。
    case card
    case choice
    case match
    case list
    case audio

    static let storageKey = "learning.deckPlayStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "カード"
        case .choice: return "5択"
        case .list: return "リスト"
        case .audio: return "音声"
        case .match: return "ペア"
        }
    }

    /// バーに並べるアイコン。5つを1行に収めるため、名前は選んだものだけ出す。
    var symbol: String {
        switch self {
        case .card: return "rectangle.on.rectangle"
        case .choice: return "checklist"
        case .list: return "list.bullet"
        case .audio: return "waveform"
        case .match: return "square.grid.3x2"
        }
    }
}

/// 学習タブ。表紙・名前・進み具合をまとめたカードを上下に回して選び、中央のカードを
/// タップすると、選んだ遊び方でそのデッキを開く。両端の空き枠からデッキを1つずつ足す。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var decks: [Deck] = []
    /// デッキごとの進み具合。カードを読み終えるまでは空のまま出す。
    @State private var summaries: [Int: DeckProgressSummary] = [:]
    /// デッキごとの表紙画像。選んだ1枚は `DeckCoverStore` が端末へ覚えている。
    @State private var covers: [Int: URL] = [:]
    @State private var studyLaunch: StudyLaunch?
    @State private var isShowingLibrary = false
    /// 空き枠から開いたライブラリで追加したデッキを、どちらの端へ入れるか。
    @State private var addEdge: DeckSlotEdge = .bottom
    @State private var wordListDeck: Deck?
    @State private var radioDeck: Deck?
    @State private var matchingDeck: Deck?
    @State private var choiceDeck: Deck?
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card
    @State private var errorMessage: String?
    @State private var exportDocument: DeckDocument?
    @State private var exportFileName = "deck"

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $studyLaunch) { launch in
                    StudySessionView(deck: launch.deck, studyMode: launch.mode)
                }
                .navigationDestination(isPresented: $isShowingLibrary) {
                    DeckLibraryView(onAdded: placeAddedDeck)
                }
                .navigationDestination(item: $wordListDeck) { deck in
                    WordListView(deck: deck)
                }
                .navigationDestination(item: $radioDeck) { deck in
                    AudioRadioView(deck: deck)
                }
                .navigationDestination(item: $matchingDeck) { deck in
                    MatchingGameView(deck: deck)
                }
                .navigationDestination(item: $choiceDeck) { deck in
                    FiveChoiceView(deck: deck)
                }
        }
        .task(id: reloadKey) { await reload() }
        .onChange(of: appState.session?.user.id) { _, _ in
            // 利用者が変わったら、前の人の教材を開いている画面を閉じる。
            studyLaunch = nil
            isShowingLibrary = false
            wordListDeck = nil
            radioDeck = nil
            matchingDeck = nil
            choiceDeck = nil
            decks = []
            covers = [:]
        }
        // タブバーの出し入れは push / pop が始まった時点で決める。子画面の
        // onAppear / onDisappear は遷移が終わってから呼ばれるため、そこで戻すと
        // 学習タブが出そろった後にバーが浮き上がってきてしまう。
        .onChange(of: isCoveringScreenPresented) { _, isPresented in
            // 隠すときだけ下へ滑らせる。戻すときは即座に出し、pop に合わせて
            // 浮き上がったり薄く現れたりしないようにする。
            withAnimation(isPresented ? .spring(response: 0.28, dampingFraction: 0.86) : nil) {
                appState.isShellChromeHidden = isPresented
            }
        }
    }

    /// タブバーの上に重なる全画面の子画面が出ているか。
    private var isCoveringScreenPresented: Bool {
        studyLaunch != nil
            || isShowingLibrary
            || wordListDeck != nil
            || radioDeck != nil
            || matchingDeck != nil
    }

    /// デッキのカードを上下に回すカルーセル。お知らせがあるときだけ下に足す。
    private var content: some View {
        VStack(spacing: WireMetrics.spacingM) {
            carousel
            notice
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.top, WireMetrics.spacingM)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var carousel: some View {
        DeckCarouselView(
            decks: decks,
            centeredDeckId: deckOrder.selectedDeckId,
            coverURL: { covers[$0.id] },
            summary: summary(for:),
            onOpen: open,
            onSelect: { deckOrder.selectedDeckId = $0.id },
            onAdd: { edge in
                addEdge = edge
                isShowingLibrary = true
            },
            onExport: prepareExport,
            onDelete: delete,
            canExport: canExport,
            canDelete: { appState.studyDataSource.canManage($0) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 読み込みや削除に失敗したときだけ出すお知らせ。
    @ViewBuilder
    private var notice: some View {
        if let errorMessage {
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
    }

    /// デッキ全体を学習開始の入口にする。
    private func open(_ deck: Deck) {
        switch playStyle {
        case .card:
            studyLaunch = StudyLaunch(deck: deck, mode: .all)
        case .choice:
            choiceDeck = deck
        case .list:
            wordListDeck = deck
        case .audio:
            radioDeck = deck
        case .match:
            matchingDeck = deck
        }
    }

    /// ライブラリで追加した公式デッキを、選んだ空き枠の端へ入れて中央に置き、学習タブへ戻る。
    private func placeAddedDeck(remoteDeckId: Int) {
        let store = deckOrder
        let deckId = LocalStudyDataSource.cachedDeckId(remoteDeckId: remoteDeckId)
        store.place(deckId: deckId, at: addEdge, in: decks.map(\.id))
        store.selectedDeckId = deckId
        isShowingLibrary = false
        // 読み直しは追加の時点で上がる `studyDataVersion` にまかせる。ここでも呼ぶと、
        // 全デッキのカードを2回読むことになる。
    }

    /// 並び順と最後に選んだデッキ。利用者ごとに分けて覚える。
    private var deckOrder: DeckOrderStore {
        DeckOrderStore(accountId: appState.session?.user.id ?? "guest")
    }

    /// そのデッキの進み具合。まだ読めていないデッキは 0 枚として出す。
    private func summary(for deck: Deck) -> DeckProgressSummary {
        summaries[deck.id] ?? .empty
    }

    private var reloadKey: String {
        "\(appState.session?.user.id ?? "guest")-\(appState.studyDataVersion)"
    }

    private func reload() async {
        let dataSource = appState.localStudy
        let order = deckOrder
        do {
            let fetched = try await dataSource.fetchDecks()
            guard appState.localStudy === dataSource else { return }
            decks = order.arranged(fetched)
            errorMessage = nil
            await loadDeckDetails(for: fetched, from: dataSource)
        } catch {
            guard appState.localStudy === dataSource else { return }
            decks = []
            summaries = [:]
            covers = [:]
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// デッキごとの進み具合と表紙を、同じカード一覧から一度に作る。
    /// 1件が読めなくても残りのデッキは出す。
    ///
    /// ponytail: 数え方はデッキのカードを全部読む素直なやり方。デッキが増えるか
    /// 1デッキが大きくなって一覧の表示が遅れたら、データ層に件数だけを返す
    /// 問い合わせ（`fetchDeckCounts` と同じ置き場所）を足して置き換える。
    private func loadDeckDetails(for decks: [Deck], from dataSource: LocalStudyDataSource) async {
        let store = DeckCoverStore()
        var loadedSummaries: [Int: DeckProgressSummary] = [:]
        var loadedCovers: [Int: URL] = [:]
        for deck in decks {
            guard let cards = try? await dataSource.fetchCards(deckId: deck.id) else { continue }
            loadedSummaries[deck.id] = DeckProgressSummary(cards: cards)
            loadedCovers[deck.id] = store.coverURL(deckId: deck.id, cards: cards)
        }
        // 利用者が切り替わっていたら、前の人の結果は捨てる。
        guard appState.localStudy === dataSource else { return }
        summaries = loadedSummaries
        covers = loadedCovers
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

    private func delete(_ deck: Deck) {
        let dataSource = appState.studyDataSource
        guard dataSource.canManage(deck) else {
            errorMessage = "配信中のデッキは削除できません。"
            return
        }

        // 中央のデッキを消したら、詰めて上がってくる下の隣を中央にする。下が無ければ上の隣。
        let order = deckOrder
        if (order.selectedDeckId ?? decks.first?.id) == deck.id,
           let index = decks.firstIndex(of: deck) {
            let neighbor = decks.indices.contains(index + 1) ? decks[index + 1]
                : decks.indices.contains(index - 1) ? decks[index - 1] : nil
            order.selectedDeckId = neighbor?.id
        }

        Task {
            do {
                try await dataSource.deleteDeck(id: deck.id)
                errorMessage = nil
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

/// 学習画面へ渡す組み合わせ。`navigationDestination(item:)` に載せるためだけの入れ物。
struct StudyLaunch: Identifiable, Hashable {
    let deck: Deck
    let mode: StudyMode

    var id: String { "\(deck.id)-\(mode.rawValue)" }
}
