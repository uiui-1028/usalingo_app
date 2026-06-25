import SwiftUI

struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decks: [Deck] = []
    @State private var stats = StudyStats.empty
    @State private var selectedDeck: Deck?
    @State private var showWordList = false
    @State private var isLoading = false
    @State private var showGallery = false

    private let deckService = DeckService()
    private let studyService = StudyService()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    learningDeckTile
                    DashboardTile(
                        title: "復習リマインダー",
                        subtitle: "\(stats.dueCount)枚が復習待ち",
                        symbol: "bell.fill",
                        color: AppStyle.sun
                    ) {
                        startStudy()
                    }
                    DashboardTile(
                        title: "単語カウンター",
                        subtitle: "\(stats.studiedCount)語を学習中",
                        symbol: "number.circle.fill",
                        color: AppStyle.accent
                    ) {
                        showWordList = true
                    }
                    DashboardTile(
                        title: "学習統計",
                        subtitle: "\(stats.masteredCount)語マスター",
                        symbol: "chart.pie.fill",
                        color: AppStyle.secondary
                    ) {
                        showGallery = true
                    }
                    addWidgetTile
                    emptyTile
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
            WidgetGallerySheet(startStudy: startStudy)
                .presentationDetents([.large])
        }
    }

    private var learningDeckTile: some View {
        DashboardTile(
            title: "学習デッキ",
            subtitle: "フラッシュカードで学習",
            symbol: "rectangle.stack.fill",
            color: AppStyle.accent
        ) {
            startStudy()
        }
    }

    private var addWidgetTile: some View {
        DashboardTile(
            title: "ウィジェットの追加",
            subtitle: "学習ブロックを選択",
            symbol: "plus",
            color: .secondary
        ) {
            showGallery = true
        }
        .opacity(0.78)
    }

    private var emptyTile: some View {
        DashboardTile(
            title: "ウィジェットの追加",
            subtitle: "空きスロット",
            symbol: "plus",
            color: .secondary
        ) {
            showGallery = true
        }
        .opacity(0.58)
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
        selectedDeck = decks.first ?? Deck(id: -1, deckName: "学習デッキ", description: "フラッシュカードで学習")
    }
}

struct DashboardTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: color.opacity(0.28), radius: 0, y: 5)
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppStyle.ink)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(14)
            .background(AppStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppStyle.line, lineWidth: 1)
            }
            .shadow(color: AppStyle.shadow, radius: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct WidgetGallerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    let startStudy: () -> Void

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
                            if block.title == "フラッシュカード学習" {
                                dismiss()
                                startStudy()
                            } else {
                                dismiss()
                            }
                        }
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
                .init("TOEICスコア予測", "現在の学習状況からスコアを予測", "chart.line.uptrend.xyaxis", .red),
                .init("TOEIC頻出単語", "TOEICでよく出る単語を表示", "star.fill", .yellow),
                .init("TOEIC模擬テスト", "本番形式の模擬テストを実行", "checklist", .indigo),
                .init("TOEIC学習計画", "目標スコア達成のための学習計画", "doc.text.fill", .teal)
            ]
        case 2:
            return [
                .init("日常会話フレーズ", "よく使う日常会話のフレーズ", "bubble.left.and.bubble.right.fill", .cyan),
                .init("シチュエーション別単語", "場面に応じた単語集", "mappin.and.ellipse", .green),
                .init("発音練習", "音声付きの発音練習", "waveform", .pink),
                .init("会話練習", "AIとの会話練習", "sparkles", .blue)
            ]
        case 3:
            return [
                .init("カスタム単語集", "自分で作成した単語集", "square.and.pencil", .brown),
                .init("お気に入り単語", "お気に入りに登録した単語", "heart.fill", .orange),
                .init("学習メモ", "学習中のメモやノート", "note.text", .gray),
                .init("学習履歴", "過去の学習記録", "clock.arrow.circlepath", .secondary)
            ]
        default:
            return [
                .init("フラッシュカード学習", "スワイプジェスチャーで直感的に学習", "rectangle.stack.fill", .indigo),
                .init("学習進捗トラッカー", "今日の学習目標と進捗を可視化", "chart.bar.fill", .blue),
                .init("単語カウンター", "学習した単語数を表示", "number.circle.fill", .green),
                .init("復習リマインダー", "次回復習予定の単語を表示", "bell.fill", .orange),
                .init("学習統計", "週間・月間の学習データ", "chart.pie.fill", .purple)
            ]
        }
    }
}

private struct WidgetBlock {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    init(_ title: String, _ subtitle: String, _ symbol: String, _ color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.color = color
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
