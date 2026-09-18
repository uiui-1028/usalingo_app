import Foundation

/// デッキの表紙に使うカードを1枚だけ選び、端末へ覚えておく。
///
/// 覚えるのはカードのIDだけで、画像のURLは持たない。配信URLは期限や置き場所が変わるため、
/// 表紙は「どのカードか」だけを固定し、URLは毎回そのカードから作り直す。
///
/// 覚えた1枚がデッキから消えたときや、絵が外されたときは、残っているカードから選び直す。
/// 取り込み直しで同じIDが別のカードへ付いても、実際のカード一覧と突き合わせてから使うので、
/// そのデッキに無い画像を出すことはない。
///
/// 保存先は端末で1か所にする。利用者ごとに分けると、匿名の利用者IDが起動ごとに変わる
/// たびに選び直しになり、「次回起動後も同じ表紙」を守れない。デッキも学習記録も端末に
/// 持っているので、利用者が変わって同じデッキ番号が別のデッキを指しても、覚えたカードが
/// 見つからず選び直しになるだけで済む。
struct DeckCoverStore {
    private static let storageKey = "learning.deckCover"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// そのデッキの表紙にする画像。絵のあるカードが1枚も無ければ `nil`。
    func coverURL(deckId: Int, cards: [WordCard]) -> URL? {
        let candidates = cards.filter { $0.illustrationURL != nil }
        guard !candidates.isEmpty else { return nil }

        let key = String(deckId)
        var saved = savedCardIds
        if let savedId = saved[key], let card = candidates.first(where: { $0.id == savedId }) {
            return card.illustrationURL
        }

        guard let picked = candidates.randomElement() else { return nil }
        saved[key] = picked.id
        defaults.set(saved, forKey: Self.storageKey)
        return picked.illustrationURL
    }

    private var savedCardIds: [String: Int] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: Int] ?? [:]
    }
}
