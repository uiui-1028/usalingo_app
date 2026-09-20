import Foundation

/// 神経衰弱の盤。12マスに英単語6枚と日本語訳6枚を裏向きで並べる。
///
/// 4ペア消えるたびに、空いた8マスへ新しい4ペアをまとめて入れる。盤に残っている札は
/// 動かさないので、覚えた位置が補充で無駄にならない。デッキの語を出し切り、盤が空に
/// なったところで終わる。
///
/// 画面を持たない値型にしてあるのは、めくり・判定・補充の規則をテストで確かめるため。
struct MatchingGame {
    /// 盤のマス数。3×4で並べる。
    static let slotCount = 12
    /// 何ペア消えたら補充するか。
    static let refillPairCount = 4

    /// 札の面。同じ語の英語と日本語が1組になる。
    enum Face {
        case english
        case japanese
    }

    struct Tile: Identifiable, Equatable {
        /// 補充で入れ替わっても重ならない通し番号。SwiftUI の差分描画はこれで見る。
        let id: Int
        let cardId: Int
        let face: Face
        let text: String
    }

    /// 1回めくった結果。
    enum Flip: Equatable {
        /// 何も起きなかった（空きマス、すでに表、判定待ちの最中）。
        case ignored
        /// 1枚目が表になった。
        case revealed
        /// 2枚が揃った。`isCorrect` は、その語で一度もミスしていないかどうか。
        case matched(cardId: Int, isCorrect: Bool)
        /// 2枚が違った。呼ぶ側が少し見せてから `hideRevealed()` を呼ぶ。
        case mismatched
    }

    /// マスの中身。`nil` は空きマス。補充までそのまま空けておく。
    private(set) var slots: [Tile?]
    /// いま表にしている札。2枚になった時点で判定する。
    private(set) var revealed: [Int] = []

    /// まだ盤に出していない語。
    private var pool: [WordCard]
    /// 一度でもミスした語。揃ったときに不正解として記録する。
    private var missedCardIds: Set<Int> = []
    /// 前の補充から消したペア数。
    private var clearedSinceRefill = 0
    private var nextTileId = 0
    private let shufflesOrder: Bool

    /// - Parameter shufflesOrder: 語の順と札の置き場所を混ぜるか。テストだけ `false` にする。
    init(words: [WordCard], shufflesOrder: Bool = true) {
        self.shufflesOrder = shufflesOrder
        pool = shufflesOrder ? words.shuffled() : words
        slots = Array(repeating: nil, count: Self.slotCount)
        fillEmptySlots(pairLimit: Self.slotCount / 2)
    }

    /// デッキを一周した。盤も空で、もう出す語がない。
    var isFinished: Bool {
        pool.isEmpty && slots.allSatisfy { $0 == nil }
    }

    /// 判定待ちで札を見せている最中か。この間のタップは受け付けない。
    var isAwaitingHide: Bool {
        revealed.count == 2
    }

    func tile(at slot: Int) -> Tile? {
        slots.indices.contains(slot) ? slots[slot] : nil
    }

    func isRevealed(_ tile: Tile) -> Bool {
        revealed.contains(tile.id)
    }

    mutating func flip(tileId: Int) -> Flip {
        guard !isAwaitingHide, !revealed.contains(tileId) else { return .ignored }
        guard let slot = slots.firstIndex(where: { $0?.id == tileId }), let second = slots[slot] else {
            return .ignored
        }

        revealed.append(tileId)
        guard revealed.count == 2, let first = tile(withId: revealed[0]) else { return .revealed }

        guard first.cardId == second.cardId else {
            // 違った2枚は、次に出会ったときのために「一度ミスした語」として控える。
            missedCardIds.insert(first.cardId)
            missedCardIds.insert(second.cardId)
            return .mismatched
        }

        let isCorrect = !missedCardIds.contains(second.cardId)
        removeTiles(cardId: second.cardId)
        revealed.removeAll()
        clearedSinceRefill += 1
        if clearedSinceRefill >= Self.refillPairCount {
            clearedSinceRefill = 0
            fillEmptySlots(pairLimit: Self.refillPairCount)
        }
        return .matched(cardId: second.cardId, isCorrect: isCorrect)
    }

    /// 違った2枚を裏に戻す。
    mutating func hideRevealed() {
        revealed.removeAll()
    }

    private func tile(withId id: Int) -> Tile? {
        slots.compactMap { $0 }.first { $0.id == id }
    }

    private mutating func removeTiles(cardId: Int) {
        for slot in slots.indices where slots[slot]?.cardId == cardId {
            slots[slot] = nil
        }
    }

    /// 空きマスへ、出していない語から最大 `pairLimit` ペアを入れる。
    /// 語が足りないときは入る分だけ入れる。
    private mutating func fillEmptySlots(pairLimit: Int) {
        let emptySlots = slots.indices.filter { slots[$0] == nil }
        let pairCount = min(pairLimit, pool.count, emptySlots.count / 2)
        guard pairCount > 0 else { return }

        let words = pool.prefix(pairCount)
        pool.removeFirst(pairCount)

        var tiles: [Tile] = []
        for word in words {
            tiles.append(Tile(id: takeTileId(), cardId: word.id, face: .english, text: word.text))
            tiles.append(Tile(id: takeTileId(), cardId: word.id, face: .japanese, text: word.primaryMeaning))
        }

        for (slot, tile) in zip(emptySlots, shufflesOrder ? tiles.shuffled() : tiles) {
            slots[slot] = tile
        }
    }

    private mutating func takeTileId() -> Int {
        defer { nextTileId += 1 }
        return nextTileId
    }
}
