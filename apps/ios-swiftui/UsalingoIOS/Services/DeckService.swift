import Foundation

final class DeckService {
    private let client = SupabaseClient.shared

    func fetchDecks(accessToken: String) async throws -> [Deck] {
        let decks: [Deck] = try await client.request(
            path: "decks",
            queryItems: [
                URLQueryItem(name: "select", value: "id,deck_name,description"),
                URLQueryItem(name: "order", value: "id.asc")
            ],
            accessToken: accessToken
        )
        if decks.isEmpty {
            return [Deck(id: -1, deckName: "すべての単語", description: "登録済みの単語から学習します")]
        }
        return decks
    }
}
