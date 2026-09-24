import XCTest
@testable import UsalingoIOS

/// カルーセルの並び方と、デッキの並び順を覚えておく仕組みを確かめる。
final class DeckCarouselLayoutTests: XCTestCase {
    private let layout = DeckCarouselLayout(
        bandHeight: 64, spacing: 10, overscrollStep: 162,
        expandedHeights: [64, 240, 240, 240, 64]
    )

    /// 中央の枠だけが広がり、画面の中央に来る。
    func testCenterSlotIsExpandedAndCentered() {
        let frames = layout.frames(center: 2)

        XCTAssertEqual(frames[2].height, 240, accuracy: 0.001)
        XCTAssertEqual(frames[2].y, 0, accuracy: 0.001)
        XCTAssertEqual(frames[1].height, 64, accuracy: 0.001)
        XCTAssertEqual(frames[3].height, 64, accuracy: 0.001)
    }

    /// 動いている途中でも、隣どうしは重ならず、同じ間隔だけ離れる。
    func testSlotsNeverOverlapWhileMoving() {
        for step in 0...40 {
            let frames = layout.frames(center: CGFloat(step) / 10)
            for index in 0..<(frames.count - 1) {
                let gap = (frames[index + 1].y - frames[index + 1].height / 2)
                    - (frames[index].y + frames[index].height / 2)
                XCTAssertEqual(gap, 10, accuracy: 0.001, "center \(Double(step) / 10)")
            }
        }
    }

    /// 枠をまたいでも位置が飛ばない。
    func testPositionsAreContinuous() {
        let before = layout.frames(center: 1.9999)
        let after = layout.frames(center: 2)

        for (lhs, rhs) in zip(before, after) {
            XCTAssertEqual(lhs.y, rhs.y, accuracy: 0.1)
            XCTAssertEqual(lhs.height, rhs.height, accuracy: 0.1)
        }
    }

    /// 端より先へ引いたぶんは、全体をそのままずらす。
    func testOverscrollShiftsEverything() {
        let resting = layout.frames(center: 0)
        let pulled = layout.frames(center: -0.5)

        XCTAssertEqual(pulled[0].y - resting[0].y, 81, accuracy: 0.001)
    }

    func testNoSlotShowsNothing() {
        XCTAssertTrue(DeckCarouselLayout(bandHeight: 64, spacing: 10, overscrollStep: 162, expandedHeights: [])
            .frames(center: 0).isEmpty)
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
        let store = DeckOrderStore(defaults: defaults)
        XCTAssertEqual(store.arranged([makeDeck(3), makeDeck(1)]).map(\.id), [3, 1])
    }

    /// 先頭の空き枠から足したデッキは先頭へ、末尾からなら末尾へ入る。
    func testPlacedDeckGoesToTheChosenEdge() {
        let store = DeckOrderStore(defaults: defaults)
        let decks = [makeDeck(1), makeDeck(2), makeDeck(3)]

        store.place(deckId: 3, at: .top, in: [1, 2])
        XCTAssertEqual(store.arranged(decks).map(\.id), [3, 1, 2])

        store.place(deckId: 4, at: .bottom, in: [3, 1, 2])
        XCTAssertEqual(store.arranged(decks + [makeDeck(4)]).map(\.id), [3, 1, 2, 4])
    }

    /// 消えたデッキは詰め、覚えていないデッキは末尾へ足す。
    func testDeletedDecksCloseTheGapAndNewOnesGoLast() {
        let store = DeckOrderStore(defaults: defaults)
        _ = store.arranged([makeDeck(1), makeDeck(2), makeDeck(3)])

        XCTAssertEqual(store.arranged([makeDeck(9), makeDeck(3), makeDeck(1)]).map(\.id), [1, 3, 9])
    }

    func testRemembersSelectedDeck() {
        let store = DeckOrderStore(defaults: defaults)
        XCTAssertNil(store.selectedDeckId)

        store.selectedDeckId = -5
        XCTAssertEqual(DeckOrderStore(defaults: defaults).selectedDeckId, -5)
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
