import SwiftUI

struct DeckListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decks: [Deck] = []
    @State private var progressByDeckId: [Int: DeckProgressSummary] = [:]
    @State private var message = ""
    @State private var isLoading = false

    private let deckService = DeckService()
    private let studyService = StudyService()

    var body: some View {
        NavigationStack {
            ZStack {
                GridBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("学習デッキ")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(AppStyle.ink)
                            Text("今日はどのデッキで連続記録を伸ばす？")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppStyle.muted)
                        }
                        .padding(.top, 10)

                        ForEach(decks) { deck in
                            NavigationLink(value: deck) {
                                DeckRow(deck: deck, progress: progressByDeckId[deck.id])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Sign Out") {
                    appState.signOut()
                }
            }
            .navigationDestination(for: Deck.self) { deck in
                DeckDetailView(deck: deck, progress: progressByDeckId[deck.id])
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if decks.isEmpty {
                    Text(message.isEmpty ? "No decks" : message)
                        .foregroundStyle(AppStyle.muted)
                }
            }
            .task { await load() }
            .task(id: appState.studyDataVersion) { await loadProgress() }
        }
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        do {
            decks = try await deckService.fetchDecks(accessToken: session.accessToken)
            await loadProgress()
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func loadProgress() async {
        guard let session = appState.session, !decks.isEmpty else { return }
        var summaries: [Int: DeckProgressSummary] = [:]
        for deck in decks {
            if let summary = try? await studyService.fetchDeckProgress(deckId: deck.id, session: session) {
                summaries[deck.id] = summary
            }
        }
        progressByDeckId = summaries
    }
}

private struct DeckDetailView: View {
    let deck: Deck
    let progress: DeckProgressSummary?

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(deck.deckName)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(AppStyle.ink)
                        if let description = deck.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(AppStyle.muted)
                        }
                    }
                    .padding(.top, 10)

                    if let progress {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                ProgressTile(title: "総単語", value: progress.totalCount, color: AppStyle.accent)
                                ProgressTile(title: "復習", value: progress.dueCount, color: AppStyle.sun)
                            }
                            HStack(spacing: 10) {
                                ProgressTile(title: "学習済み", value: progress.studiedCount, color: AppStyle.secondary)
                                ProgressTile(title: "習得", value: progress.masteredCount, color: AppStyle.accentDark)
                            }
                        }
                    }

                    Text("学習モード")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppStyle.ink)

                    VStack(spacing: 12) {
                        ForEach(StudyMode.allCases) { mode in
                            NavigationLink {
                                StudySessionView(deck: deck, studyMode: mode)
                            } label: {
                                StudyModeRow(mode: mode, progress: progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    NavigationLink {
                        WordListView(deck: deck)
                    } label: {
                        Label("単語を見る", systemImage: "list.bullet")
                            .font(.headline.weight(.black))
                            .foregroundStyle(AppStyle.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppStyle.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .navigationTitle("デッキ詳細")
    }
}

private struct StudyModeRow: View {
    let mode: StudyMode
    let progress: DeckProgressSummary?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: color.opacity(0.28), radius: 0, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppStyle.ink)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer()
            if let progress {
                Text("\(count(from: progress))語")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
        .shadow(color: AppStyle.shadow, radius: 0, y: 5)
    }

    private var symbol: String {
        switch mode {
        case .newOnly: return "sparkle"
        case .reviewOnly: return "clock.arrow.circlepath"
        case .all: return "rectangle.stack.fill"
        case .weakOnly: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch mode {
        case .newOnly: return AppStyle.accent
        case .reviewOnly: return AppStyle.sun
        case .all: return AppStyle.secondary
        case .weakOnly: return AppStyle.coral
        }
    }

    private func count(from progress: DeckProgressSummary) -> Int {
        switch mode {
        case .newOnly: return progress.newCount
        case .reviewOnly: return progress.dueCount
        case .all: return progress.totalCount
        case .weakOnly: return progress.weakCount
        }
    }
}

private struct ProgressTile: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.14), radius: 0, y: 4)
    }
}

private struct DeckRow: View {
    let deck: Deck
    let progress: DeckProgressSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(AppStyle.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                Text(deck.deckName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppStyle.ink)
                Spacer()
                if let progress {
                    Text("\(progress.totalCount)語")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.muted)
                }
            }

            if let description = deck.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
                    .lineLimit(2)
            }

            if let progress {
                HStack(spacing: 8) {
                    deckChip("学習済み \(progress.studiedCount)", color: AppStyle.accent)
                    deckChip("復習 \(progress.dueCount)", color: AppStyle.sun)
                    deckChip("習得 \(progress.masteredCount)", color: AppStyle.accentDark)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(16)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
        .shadow(color: AppStyle.shadow, radius: 0, y: 6)
    }

    private func deckChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
