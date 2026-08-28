import SwiftUI

/// 「＋ デッキを追加」から開くデッキライブラリ。同梱サンプルデッキを一覧から追加する。
/// JSONの読み込み・書き出しは T-4 で追加する。
struct DeckLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let onChanged: () -> Void

    @State private var bundledDecks: [DeckFile] = []
    @State private var message: String?

    var body: some View {
        List {
            Section("同梱デッキ") {
                if bundledDecks.isEmpty {
                    Text("追加できる同梱デッキはありません。")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                } else {
                    ForEach(bundledDecks, id: \.deckId) { file in
                        bundledRow(file)
                    }
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("デッキを追加")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private func bundledRow(_ file: DeckFile) -> some View {
        Button {
            add(file)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(file.deckName)
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                Text(file.description ?? "\(file.cards.count) 語")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        bundledDecks = appState.localStudy.availableBundledDecks()
    }

    private func add(_ file: DeckFile) {
        do {
            let deck = try appState.localStudy.installBundledDeck(key: file.deckId)
            message = "「\(deck.name)」を追加しました。"
            reload()
            onChanged()
        } catch {
            message = error.localizedDescription
        }
    }
}
