import Foundation

struct Deck: Identifiable, Decodable, Hashable {
    let id: Int
    let deckName: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deckName = "deck_name"
        case description
    }
}

