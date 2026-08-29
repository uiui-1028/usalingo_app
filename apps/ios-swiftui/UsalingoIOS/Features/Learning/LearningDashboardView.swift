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

    private var list: some View {
        List {
            Section {
                ForEach(decks) { deck in
                    deckRow(deck)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("書き出す") { prepareExport(deck) }
                        }
                }
                .onMove(perform: moveHandler)
                .onDelete(perform: deleteHandler)
            }

            Section {
                if isEditing {
                    Button {
                        isEditing = false
                    } label: {
                        Text("編集を終える")
                            .font(.headline)
                            .foregroundStyle(AppStyle.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isEditing = false
                    isShowingLibrary = true
                } label: {
                    Text("＋ デッキを追加")
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .overlay {
            if decks.isEmpty {
                emptyState
            }
        }
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
            VStack(alignment: .leading, spacing: 6) {
                Text(deck.name)
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                Text(counterText(for: deck))
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                isEditing = true
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("デッキがありません")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            Text("「＋ デッキを追加」から追加してください。")
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .padding(24)
    }

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
    ZStack {
        GridBackground()
        LearningDashboardView()
    }
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
