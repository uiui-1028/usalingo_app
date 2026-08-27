import SwiftUI

struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decks: [Deck] = []
    @State private var stats = StudyStats.empty
    @State private var selectedDeck: Deck?
    @State private var showWordList = false
    @State private var isLoading = false
    @State private var showGallery = false
    @State private var showUnavailableWidgetAlert = false
    @State private var unavailableWidgetName = ""
    @State private var dashboardWidgets: [LearningDashboardWidget] = [.deck, .reviewReminder, .wordCounter, .studyStats]
    @State private var isEditingWidgets = false

    private let deckService = DeckService()
    private let studyService = StudyService()
    private let maxWidgetCount = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(Array(dashboardWidgets.enumerated()), id: \.offset) { index, widget in
                        widgetTile(widget) {
                            removeWidget(at: index)
                        }
                    }

                    if dashboardWidgets.count < maxWidgetCount {
                        addWidgetTile
                    }
                }
                .padding(16)
            }
            .navigationDestination(item: $selectedDeck) { deck in
                StudySessionView(deck: deck)
            }
            .navigationDestination(isPresented: $showWordList) {
                WordListView()
            }
        }
        .task { await loadDashboard() }
        .task(id: appState.studyDataVersion) { await refreshStats() }
        .sheet(isPresented: $showGallery) {
            WidgetGallerySheet(
                canAddWidget: dashboardWidgets.count < maxWidgetCount,
                addWidget: addWidget
            )
                .presentationDetents([.large])
        }
        .alert("まだできていません", isPresented: $showUnavailableWidgetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("「\(unavailableWidgetName)」はまだ実装されていません。")
        }
    }

    private func widgetTile(_ widget: LearningDashboardWidget, onDelete: @escaping () -> Void) -> some View {
        DashboardTile(
            title: widget.title(stats: stats),
            symbol: widget.symbol,
            color: widget.color,
            isEditing: isEditingWidgets,
            onDelete: onDelete,
            onLongPress: {
                isEditingWidgets = true
            }
        ) {
            guard !isEditingWidgets else {
                isEditingWidgets = false
                return
            }
            performWidgetAction(widget)
        }
    }

    private var addWidgetTile: some View {
        DashboardTile(
            title: "ウィジェットの追加",
            symbol: "plus",
            color: .secondary
        ) {
            isEditingWidgets = false
            showGallery = true
        }
        .opacity(0.78)
    }

    private func loadDashboard() async {
        guard let session = appState.session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            decks = try await deckService.fetchDecks(accessToken: session.accessToken)
            stats = try await studyService.fetchStudyStats(session: session)
        } catch {
            decks = []
        }
    }

    private func refreshStats() async {
        guard let session = appState.session else { return }
        do {
            stats = try await studyService.fetchStudyStats(session: session)
        } catch {
            stats = .empty
        }
    }

    private func startStudy() {
        appState.isShellChromeHidden = true
        selectedDeck = decks.first ?? Deck(id: -1, deckName: "学習デッキ", description: "フラッシュカードで学習")
    }

    private func addWidget(_ widget: LearningDashboardWidget) {
        guard dashboardWidgets.count < maxWidgetCount else { return }
        isEditingWidgets = false
        dashboardWidgets.append(widget)
    }

    private func removeWidget(at index: Int) {
        guard dashboardWidgets.indices.contains(index) else { return }
        dashboardWidgets.remove(at: index)
        if dashboardWidgets.isEmpty {
            isEditingWidgets = false
        }
    }

    private func performWidgetAction(_ widget: LearningDashboardWidget) {
        switch widget.action {
        case .startStudy:
            startStudy()
        case .showWordList:
            showWordList = true
        case .showGallery:
            showGallery = true
        case .showUnavailableMessage:
            unavailableWidgetName = widget.title(stats: stats)
            showUnavailableWidgetAlert = true
        }
    }
}

struct DashboardTile: View {
    let title: String
    let symbol: String
    let color: Color
    var isEditing = false
    var onDelete: (() -> Void)?
    var onLongPress: (() -> Void)?
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            Rectangle().stroke(AppStyle.line, lineWidth: 1)
                        }
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppStyle.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .modifier(WidgetTileStyle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        onLongPress?()
                    }
            )

            if isEditing, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppStyle.muted)
                        .frame(width: 30, height: 30)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(AppStyle.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.84), value: isEditing)
    }
}

private struct WidgetTileStyle: ViewModifier {
    func body(content: Content) -> some View {
        AppStyle.profileWidgetTile {
            content
        }
    }
}

private struct WidgetGallerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    let canAddWidget: Bool
    let addWidget: (LearningDashboardWidget) -> Void

    private let tabs = ["学習", "TOEIC", "日常会話", "カスタム"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ウィジェットブロックライブラリー")
                        .font(.title3.bold())
                    Text("学習に役立つウィジェットブロックを選択して配置できます")
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $selectedTab) {
                ForEach(tabs.indices, id: \.self) { index in
                    Text(tabs[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(blocks, id: \.title) { block in
                        WidgetBlockRow(block: block) {
                            if canAddWidget {
                                addWidget(block.widget)
                            }
                            dismiss()
                        }
                        .disabled(!canAddWidget)
                    }
                }
            }
        }
        .padding(20)
    }

    private var blocks: [WidgetBlock] {
        switch selectedTab {
        case 1:
            return [
                .init(.toeicScore),
                .init(.toeicWords),
                .init(.toeicTest),
                .init(.toeicPlan)
            ]
        case 2:
            return [
                .init(.dailyPhrase),
                .init(.situationWords),
                .init(.pronunciation),
                .init(.conversation)
            ]
        case 3:
            return [
                .init(.customWords),
                .init(.favoriteWords),
                .init(.studyMemo),
                .init(.studyHistory)
            ]
        default:
            return [
                .init(.deck),
                .init(.progressTracker),
                .init(.wordCounter),
                .init(.reviewReminder),
                .init(.studyStats)
            ]
        }
    }
}

private struct WidgetBlock {
    let widget: LearningDashboardWidget

    var title: String { widget.title(stats: .empty) }
    var subtitle: String { widget.gallerySubtitle }
    var symbol: String { widget.symbol }
    var color: Color { widget.color }

    init(_ widget: LearningDashboardWidget) {
        self.widget = widget
    }
}

private struct WidgetBlockRow: View {
    let block: WidgetBlock
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: block.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(block.color)
                    .frame(width: 48, height: 48)
                    .background(block.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                    Text(block.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                }

                Spacer()
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(block.color)
            }
            .padding(14)
            .background(AppStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppStyle.line, lineWidth: 1)
            }
            .shadow(color: AppStyle.shadow, radius: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private enum LearningDashboardWidget {
    case deck
    case reviewReminder
    case wordCounter
    case studyStats
    case progressTracker
    case toeicScore
    case toeicWords
    case toeicTest
    case toeicPlan
    case dailyPhrase
    case situationWords
    case pronunciation
    case conversation
    case customWords
    case favoriteWords
    case studyMemo
    case studyHistory

    var symbol: String {
        switch self {
        case .deck:
            return "rectangle.stack.fill"
        case .reviewReminder:
            return "bell.fill"
        case .wordCounter:
            return "number.circle.fill"
        case .studyStats:
            return "chart.pie.fill"
        case .progressTracker:
            return "chart.bar.fill"
        case .toeicScore:
            return "chart.line.uptrend.xyaxis"
        case .toeicWords:
            return "star.fill"
        case .toeicTest:
            return "checklist"
        case .toeicPlan:
            return "doc.text.fill"
        case .dailyPhrase:
            return "bubble.left.and.bubble.right.fill"
        case .situationWords:
            return "mappin.and.ellipse"
        case .pronunciation:
            return "waveform"
        case .conversation:
            return "sparkles"
        case .customWords:
            return "square.and.pencil"
        case .favoriteWords:
            return "heart.fill"
        case .studyMemo:
            return "note.text"
        case .studyHistory:
            return "clock.arrow.circlepath"
        }
    }

    var color: Color {
        AppStyle.ink
    }

    var gallerySubtitle: String {
        switch self {
        case .deck:
            return "スワイプジェスチャーで直感的に学習"
        case .reviewReminder:
            return "次回復習予定の単語を表示"
        case .wordCounter:
            return "学習した単語数を表示"
        case .studyStats:
            return "週間・月間の学習データ"
        case .progressTracker:
            return "今日の学習目標と進捗を可視化"
        case .toeicScore:
            return "現在の学習状況からスコアを予測"
        case .toeicWords:
            return "TOEICでよく出る単語を表示"
        case .toeicTest:
            return "本番形式の模擬テストを実行"
        case .toeicPlan:
            return "目標スコア達成のための学習計画"
        case .dailyPhrase:
            return "よく使う日常会話のフレーズ"
        case .situationWords:
            return "場面に応じた単語集"
        case .pronunciation:
            return "音声付きの発音練習"
        case .conversation:
            return "AIとの会話練習"
        case .customWords:
            return "自分で作成した単語集"
        case .favoriteWords:
            return "お気に入りに登録した単語"
        case .studyMemo:
            return "学習中のメモやノート"
        case .studyHistory:
            return "過去の学習記録"
        }
    }

    var action: WidgetAction {
        switch self {
        case .deck, .reviewReminder:
            return .startStudy
        case .wordCounter, .customWords, .favoriteWords:
            return .showWordList
        default:
            return .showUnavailableMessage
        }
    }

    func title(stats: StudyStats) -> String {
        switch self {
        case .deck:
            return "学習デッキ"
        case .reviewReminder:
            return "復習リマインダー"
        case .wordCounter:
            return "単語カウンター"
        case .studyStats:
            return "学習統計"
        case .progressTracker:
            return "進捗トラッカー"
        case .toeicScore:
            return "TOEICスコア予測"
        case .toeicWords:
            return "TOEIC頻出単語"
        case .toeicTest:
            return "TOEIC模擬テスト"
        case .toeicPlan:
            return "TOEIC学習計画"
        case .dailyPhrase:
            return "日常会話フレーズ"
        case .situationWords:
            return "シチュエーション別単語"
        case .pronunciation:
            return "発音練習"
        case .conversation:
            return "会話練習"
        case .customWords:
            return "カスタム単語集"
        case .favoriteWords:
            return "お気に入り単語"
        case .studyMemo:
            return "学習メモ"
        case .studyHistory:
            return "学習履歴"
        }
    }

}

private enum WidgetAction {
    case startStudy
    case showWordList
    case showGallery
    case showUnavailableMessage
}

#if DEBUG
#Preview("Learning Dashboard") {
    ZStack {
        GridBackground()
        LearningDashboardView()
    }
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
