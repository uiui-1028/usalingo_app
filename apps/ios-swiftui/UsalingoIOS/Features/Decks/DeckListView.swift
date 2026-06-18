import SwiftUI

struct DeckListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var decks: [Deck] = []
    @State private var message = ""
    @State private var isLoading = false

    private let deckService = DeckService()

    var body: some View {
        NavigationStack {
            List(decks) { deck in
                NavigationLink(value: deck) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.deckName)
                            .font(.headline)
                        if let description = deck.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(AppStyle.muted)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("学習デッキ")
            .toolbar {
                Button("Sign Out") {
                    appState.session = nil
                }
            }
            .navigationDestination(for: Deck.self) { deck in
                StudySessionView(deck: deck)
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
        }
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        do {
            decks = try await deckService.fetchDecks(accessToken: session.accessToken)
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }
}
