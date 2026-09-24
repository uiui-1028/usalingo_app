import XCTest
@testable import UsalingoIOS

/// カルーセルの並び方と、デッキの並び順を覚えておく仕組みを確かめる。
final class DeckCarouselLayoutTests: XCTestCase {
    private let layout = DeckCarouselLayout(bandHeight: 64, expandedHeight: 240, spacing: 10)

    /// 中央の枠だけが広がり、画面の中央に来る。
    func testCenterSlotIsExpandedAndCentered() {
        XCTAssertEqual(layout.height(offset: 0), 240, accuracy: 0.001)
        XCTAssertEqual(layout.y(offset: 0), 0, accuracy: 0.001)
        XCTAssertEqual(layout.height(offset: 1), 64, accuracy: 0.001)
        XCTAssertEqual(layout.height(offset: -2), 64, accuracy: 0.001)
    }

    /// 動いている途中でも、隣どうしは重ならず、同じ間隔だけ離れる。
    func testSlotsNeverOverlapWhileMoving() {
        for step in -30...30 {
            let offset = CGFloat(step) / 10
            let upper = layout.y(offset: offset) + layout.height(offset: offset) / 2
            let lower = layout.y(offset: offset + 1) - layout.height(offset: offset + 1) / 2
            XCTAssertEqual(lower - upper, 10, accuracy: 0.001, "offset \(offset)")
        }
    }

    /// 中央とその隣は、指の移動にそのまま付いてくる。1枠ぶんで `stride` だけ動く。
    func testCenterMovesExactlyWithTheFinger() {
        for step in -10...10 {
            let offset = CGFloat(step) / 10
            XCTAssertEqual(layout.y(offset: offset), offset * layout.stride, accuracy: 0.001)
        }
        XCTAssertEqual(layout.stride, 162, accuracy: 0.001)
    }

    /// 両端に空き枠を1つずつ置く。デッキが無いときは空き枠1つだけ。
    func testEmptySlotsSitAtBothEnds() {
        let decks = [makeDeck(1), makeDeck(2)]

        XCTAssertEqual(DeckSlot.slots(for: decks), [.empty(.top), .deck(decks[0]), .deck(decks[1]), .empty(.bottom)])
        XCTAssertEqual(DeckSlot.slots(for: []), [.empty(.bottom)])
    }
}

final class DeckOrderStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DeckOrderStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// 覚えた順が無ければ、渡された順のまま。
    func testKeepsGivenOrderAtFirst() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        XCTAssertEqual(store.arranged([makeDeck(3), makeDeck(1)]).map(\.id), [3, 1])
    }

    /// 先頭の空き枠から足したデッキは先頭へ、末尾からなら末尾へ入る。
    func testPlacedDeckGoesToTheChosenEdge() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        let decks = [makeDeck(1), makeDeck(2), makeDeck(3)]

        store.place(deckId: 3, at: .top, in: [1, 2])
        XCTAssertEqual(store.arranged(decks).map(\.id), [3, 1, 2])

        store.place(deckId: 4, at: .bottom, in: [3, 1, 2])
        XCTAssertEqual(store.arranged(decks + [makeDeck(4)]).map(\.id), [3, 1, 2, 4])
    }

    /// 消えたデッキは詰め、覚えていないデッキは末尾へ足す。
    func testDeletedDecksCloseTheGapAndNewOnesGoLast() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        _ = store.arranged([makeDeck(1), makeDeck(2), makeDeck(3)])

        XCTAssertEqual(store.arranged([makeDeck(9), makeDeck(3), makeDeck(1)]).map(\.id), [1, 3, 9])
    }

    /// 利用者が違えば、並び順も最後に選んだデッキも混ざらない。
    func testEachAccountKeepsItsOwnOrder() {
        let first = DeckOrderStore(accountId: "a", defaults: defaults)
        let second = DeckOrderStore(accountId: "b", defaults: defaults)
        _ = first.arranged([makeDeck(2), makeDeck(1)])
        first.selectedDeckId = 2

        XCTAssertEqual(second.arranged([makeDeck(1), makeDeck(2), makeDeck(3)]).map(\.id), [1, 2, 3])
        XCTAssertNil(second.selectedDeckId)
        XCTAssertEqual(first.arranged([makeDeck(1), makeDeck(2)]).map(\.id), [2, 1])
        XCTAssertEqual(first.selectedDeckId, 2)
    }

    func testRemoveAllForgetsOnlyThatAccount() {
        let first = DeckOrderStore(accountId: "a", defaults: defaults)
        let second = DeckOrderStore(accountId: "b", defaults: defaults)
        first.selectedDeckId = 1
        second.selectedDeckId = 2

        first.removeAll()

        XCTAssertNil(first.selectedDeckId)
        XCTAssertEqual(second.selectedDeckId, 2)
    }

    func testRemembersSelectedDeck() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        XCTAssertNil(store.selectedDeckId)

        store.selectedDeckId = -5
        XCTAssertEqual(DeckOrderStore(accountId: "a", defaults: defaults).selectedDeckId, -5)
    }
}

private func makeDeck(_ id: Int) -> Deck {
    Deck(id: id, deckName: "deck\(id)", description: nil)
}

final class DeckCoverStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DeckCoverStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// 一度選んだ表紙は、読み直しても同じ1枚のままにする。
    func testSelectedCoverStaysTheSameOnLaterLoads() {
        let cards = (1...20).map { makeCard(id: $0, imagePath: "images/\($0).png") }
        let first = DeckCoverStore(defaults: defaults)
            .coverURL(deckId: 3, cards: cards)
        XCTAssertNotNil(first)

        // アプリを開き直した想定で、別のインスタンスから同じ保存先を読む。
        for _ in 0..<10 {
            let again = DeckCoverStore(defaults: defaults)
                .coverURL(deckId: 3, cards: cards)
            XCTAssertEqual(again, first)
        }
    }

    /// 覚えていたカードがデッキから消えたら、残っているカードから選び直す。
    func testCoverIsPickedAgainWhenTheSavedCardIsGone() {
        let cards = [makeCard(id: 1, imagePath: "images/1.png")]
        let store = DeckCoverStore(defaults: defaults)
        XCTAssertEqual(store.coverURL(deckId: 3, cards: cards)?.lastPathComponent, "1.png")

        let replaced = [makeCard(id: 2, imagePath: "images/2.png")]
        XCTAssertEqual(store.coverURL(deckId: 3, cards: replaced)?.lastPathComponent, "2.png")
    }

    /// 絵の無いカードは表紙に選ばない。1枚も無ければ仮表紙にまかせる。
    func testDeckWithoutImagesHasNoCover() {
        let cards = [makeCard(id: 1, imagePath: nil), makeCard(id: 2, imagePath: nil)]
        let store = DeckCoverStore(defaults: defaults)

        XCTAssertNil(store.coverURL(deckId: 3, cards: cards))
    }

    func testOnlyCardsWithImagesArePicked() {
        let cards = [
            makeCard(id: 1, imagePath: nil),
            makeCard(id: 2, imagePath: "images/2.png"),
            makeCard(id: 3, imagePath: nil)
        ]
        let store = DeckCoverStore(defaults: defaults)

        XCTAssertEqual(store.coverURL(deckId: 3, cards: cards)?.lastPathComponent, "2.png")
    }

    /// 利用者が変わって同じデッキ番号が別のデッキを指しても、無い画像は出さない。
    func testCoverIsPickedAgainWhenTheDeckNumberPointsAtAnotherDeck() {
        let cards = [makeCard(id: 1, imagePath: "images/1.png")]
        _ = DeckCoverStore(defaults: defaults).coverURL(deckId: 3, cards: cards)

        let otherCards = [makeCard(id: 9, imagePath: "images/9.png")]
        let other = DeckCoverStore(defaults: defaults)
            .coverURL(deckId: 3, cards: otherCards)

        XCTAssertEqual(other?.lastPathComponent, "9.png")
    }

    private func makeCard(id: Int, imagePath: String?) -> WordCard {
        WordCard(
            id: id,
            text: "word\(id)",
            meaning: "いみ\(id)",
            partOfSpeech: nil,
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: imagePath,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )
    }
}
