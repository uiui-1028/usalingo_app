import Foundation

/// マッチングの盤。左に日本語、右に英語を5枚ずつ表向きで並べ、同じ語の2枚を選んで消す。
///
/// 裏返して覚える遊びではなく、並んだ語の中から意味の組を選ぶ遊びにしてある。記憶力では
/// なく語彙そのものを問うため、札は最初から全部読める。
///
/// 3組消えるたび、消えた場所へ新しい3組をまとめて入れる。消えていない札は動かさない。
/// 消した札はすぐ取り除かず、薄いまま場所に残す。並びが崩れず、どこまで進んだかも見える。
///
/// 画面を持たない値型にしてあるのは、選択・判定・補充の規則をテストで確かめるため。
struct MatchingGame {
    /// 盤に出す組数。左右あわせて10枚になる。
    static let pairsOnBoard = 5
    /// 何組消えたら補充するか。
    static let refillPairCount = 3

    /// 札を置く列。組は必ず左右ひとつずつになる。
    enum Column {
        case japanese
        case english
    }

    struct Tile: Identifiable, Equatable {
        /// 補充で入れ替わっても重ならない通し番号。SwiftUI の差分描画はこれで見る。
        let id: Int
        let cardId: Int
        let column: Column
        let text: String
        /// 揃って薄く残っている札。もう選べない。
        var isCleared: Bool
    }

    /// 1回タップした結果。
    enum Tap: Equatable {
        /// 何も起きなかった（空きマス、消した札）。
        case ignored
        /// 選んだ札が変わった。相手待ち、または選び直し。
        case selected
        /// 組が揃った。`isCorrect` は、その語で一度もミスしていないかどうか。
        case matched(cardId: Int, isCorrect: Bool, tileIds: [Int])
        /// 組が違った。呼ぶ側が短く揺らして知らせる。
        case mismatched(tileIds: [Int])
    }

    /// 左の列（日本語）。`nil` は、出す語が尽きた空きマス。
    private(set) var japanese: [Tile?]
    /// 右の列（英語）。
    private(set) var english: [Tile?]
    /// いま選んでいる札。相手を選ぶまで持ち続ける。
    private(set) var selectedTileId: Int?

    /// まだ盤に出していない語。
    private var pool: [WordCard]
    /// 一度でもミスした語。揃ったときに不正解として記録する。
    private var missedCardIds: Set<Int> = []
    /// 前の補充から消した組数。
    private var clearedSinceRefill = 0
    private var nextTileId = 0
    private let shufflesOrder: Bool

    /// - Parameter shufflesOrder: 語の順と置き場所を混ぜるか。テストだけ `false` にする。
    init(words: [WordCard], shufflesOrder: Bool = true) {
        self.shufflesOrder = shufflesOrder
        pool = shufflesOrder ? words.shuffled() : words
        japanese = Array(repeating: nil, count: Self.pairsOnBoard)
        english = Array(repeating: nil, count: Self.pairsOnBoard)
        placeNewPairs(limit: Self.pairsOnBoard)
    }

    /// デッキを一周した。出す語がなく、盤の札も消し終えている。
    var isFinished: Bool {
        pool.isEmpty && tiles.allSatisfy(\.isCleared)
    }

    /// 消えた組が溜まり、補充できる状態か。呼ぶ側は消える演出を見せてから `refill()` する。
    var needsRefill: Bool {
        clearedSinceRefill >= Self.refillPairCount
    }

    var tiles: [Tile] {
        (japanese + english).compactMap { $0 }
    }

    func tiles(in column: Column) -> [Tile?] {
        column == .japanese ? japanese : english
    }

    mutating func tap(tileId: Int) -> Tap {
        guard let tapped = tile(withId: tileId), !tapped.isCleared else { return .ignored }

        // 1枚目、選び直し、同じ札の取り消しは、どれも「選んだ札が変わった」で返す。
        guard let selectedTileId, let first = tile(withId: selectedTileId), first.id != tapped.id else {
            self.selectedTileId = self.selectedTileId == tapped.id ? nil : tapped.id
            return .selected
        }
        guard first.column != tapped.column else {
            self.selectedTileId = tapped.id
            return .selected
        }

        self.selectedTileId = nil
        guard first.cardId == tapped.cardId else {
            // 違った2枚は、次に出会ったときのために「一度ミスした語」として控える。
            missedCardIds.insert(first.cardId)
            missedCardIds.insert(tapped.cardId)
            return .mismatched(tileIds: [first.id, tapped.id])
        }

        let isCorrect = !missedCardIds.contains(tapped.cardId)
        markCleared(cardId: tapped.cardId)
        clearedSinceRefill += 1
        return .matched(cardId: tapped.cardId, isCorrect: isCorrect, tileIds: [first.id, tapped.id])
    }

    /// 残っている札の置き場所だけを混ぜる。語の中身も、消した札も、進み具合も変えない。
    /// 目で追う場所が変わるだけなので、記録には何も起きない。
    mutating func shuffleBoard() {
        selectedTileId = nil
        shuffleRemaining(in: &japanese)
        shuffleRemaining(in: &english)
    }

    /// まだ消えていない札を、いま使っているマスの中で置き換える。
    private func shuffleRemaining(in column: inout [Tile?]) {
        let slots = column.indices.filter { column[$0]?.isCleared == false }
        guard slots.count > 1 else { return }
        let tiles = slots.compactMap { column[$0] }
        for (slot, tile) in zip(slots, shufflesOrder ? tiles.shuffled() : tiles.reversed()) {
            column[slot] = tile
        }
    }

    /// 消えた場所へ新しい組を入れる。出す語が足りなければ、余った場所は空きマスにする。
    mutating func refill() {
        guard needsRefill else { return }
        clearedSinceRefill = 0
        let placed = placeNewPairs(limit: Self.refillPairCount)
        guard placed == 0 else { return }
        // もう出す語がない。薄いまま残していた札を片付け、終わりにする。
        clearClearedSlots()
    }

    private func tile(withId id: Int) -> Tile? {
        tiles.first { $0.id == id }
    }

    private mutating func markCleared(cardId: Int) {
        for index in japanese.indices where japanese[index]?.cardId == cardId {
            japanese[index]?.isCleared = true
        }
        for index in english.indices where english[index]?.cardId == cardId {
            english[index]?.isCleared = true
        }
    }

    /// 空きマスと、消して薄くなっているマスへ、最大 `limit` 組を入れる。入れた組数を返す。
    @discardableResult
    private mutating func placeNewPairs(limit: Int) -> Int {
        let japaneseSlots = openSlots(in: japanese)
        let englishSlots = openSlots(in: english)
        let pairCount = min(limit, pool.count, japaneseSlots.count, englishSlots.count)
        guard pairCount > 0 else { return 0 }

        let words = Array(pool.prefix(pairCount))
        pool.removeFirst(pairCount)

        let japaneseTiles = words.map {
            Tile(id: takeTileId(), cardId: $0.id, column: .japanese, text: $0.primaryMeaning, isCleared: false)
        }
        let englishTiles = words.map {
            Tile(id: takeTileId(), cardId: $0.id, column: .english, text: $0.text, isCleared: false)
        }

        // 左右は別々に混ぜる。同じ行に組が並んで答えが見えてしまわないようにする。
        for (slot, tile) in zip(japaneseSlots, shufflesOrder ? japaneseTiles.shuffled() : japaneseTiles) {
            japanese[slot] = tile
        }
        for (slot, tile) in zip(englishSlots, shufflesOrder ? englishTiles.shuffled() : englishTiles) {
            english[slot] = tile
        }
        return pairCount
    }

    private func openSlots(in column: [Tile?]) -> [Int] {
        column.indices.filter { column[$0] == nil || column[$0]?.isCleared == true }
    }

    private mutating func clearClearedSlots() {
        for index in japanese.indices where japanese[index]?.isCleared == true {
            japanese[index] = nil
        }
        for index in english.indices where english[index]?.isCleared == true {
            english[index] = nil
        }
    }

    private mutating func takeTileId() -> Int {
        defer { nextTileId += 1 }
        return nextTileId
    }
}
