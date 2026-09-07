import Foundation

struct Deck: Identifiable, Decodable, Hashable {
    let id: Int
    let deckName: String
    let description: String?
    /// デッキの持ち主。`nil` は運営が配る公式デッキで、利用者は読むだけ。
    /// 値があるときは、そのIDの利用者だけが読み書きできる個人デッキ。
    let ownerId: String?

    init(id: Int, deckName: String, description: String?, ownerId: String? = nil) {
        self.id = id
        self.deckName = deckName
        self.description = description
        self.ownerId = ownerId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case deckName = "deck_name"
        case description
        case ownerId = "owner_id"
    }
}
