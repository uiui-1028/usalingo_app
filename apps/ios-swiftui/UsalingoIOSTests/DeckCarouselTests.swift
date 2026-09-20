import XCTest
@testable import UsalingoIOS

/// カルーセルの並び順と、表紙の1枚を覚えておく仕組みを確かめる。
final class DeckCarouselLayoutTests: XCTestCase {
    /// 1件だけのときは回さない。中央の1枚だけを出す。
    func testSingleDeckShowsOnlyTheCenterCard() {
        let placements = DeckCarouselLayout(count: 1).placements(position: 0)

        XCTAssertEqual(placements.map(\.index), [0])
        XCTAssertEqual(placements[0].offset, 0, accuracy: 0.0001)
    }

    func testNoDeckShowsNothing() {
        XCTAssertTrue(DeckCarouselLayout(count: 0).placements(position: 0).isEmpty)
    }

    /// 何件でも同じデッキを2か所へ出さない。
    func testNoDeckIsShownTwice() {
        for count in 1...8 {
            let layout = DeckCarouselLayout(count: count)
            for step in 0...(count * 10) {
                let indices = layout.placements(position: Double(step) / 10).map(\.index)
                XCTAssertEqual(Set(indices).count, indices.count, "\(count) 件で重複した")
            }
        }
    }

    /// 先頭にいるとき、上には何も出さない。一周して最後のデッキが現れない。
    func testFirstDeckHasNothingAbove() {
        let placements = DeckCarouselLayout(count: 7).placements(position: 0)

        XCTAssertEqual(placements.map(\.index), [0, 1, 2])
        XCTAssertTrue(placements.allSatisfy { $0.offset >= 0 })
    }

    /// 最後にいるとき、下には何も出さない。
    func testLastDeckHasNothingBelow() {
        let placements = DeckCarouselLayout(count: 7).placements(position: 6)

        XCTAssertEqual(placements.map(\.index), [4, 5, 6])
        XCTAssertTrue(placements.allSatisfy { $0.offset <= 0 })
    }

    /// 真ん中にいるときだけ、上下2枚ずつの5枚になる。
    func testMiddleDeckShowsTwoAboveAndTwoBelow() {
        let placements = DeckCarouselLayout(count: 7).placements(position: 3)
        let byIndex = Dictionary(uniqueKeysWithValues: placements.map { ($0.index, $0.offset) })

        XCTAssertEqual(placements.count, 5)
        XCTAssertEqual(byIndex[1], -2)
        XCTAssertEqual(byIndex[2], -1)
        XCTAssertEqual(byIndex[3], 0)
        XCTAssertEqual(byIndex[4], 1)
        XCTAssertEqual(byIndex[5], 2)
    }

    /// 範囲の中では、指の動きをそのまま通す。
    func testRubberBandDoesNothingInsideTheRange() {
        let layout = DeckCarouselLayout(count: 5)

        for position in [0.0, 0.5, 2.0, 3.7, 4.0] {
            XCTAssertEqual(layout.rubberBanded(position, limit: 0.45), position, accuracy: 0.0001)
        }
    }

    /// 端をはみ出すと、引くほど伸びにくくなり、上限より先へは出ない。
    func testRubberBandStretchesLessTheHarderYouPull() {
        let layout = DeckCarouselLayout(count: 5)
        let limit = 0.45

        let gentle = layout.rubberBanded(-0.5, limit: limit)
        let hard = layout.rubberBanded(-3.0, limit: limit)

        XCTAssertLessThan(gentle, 0)
        XCTAssertLessThan(hard, gentle)
        XCTAssertGreaterThan(hard, -limit)
        // 指の移動の6倍でも、伸びは2倍に満たない。
        XCTAssertLessThan(abs(hard), abs(gentle) * 2)
        XCTAssertGreaterThan(layout.rubberBanded(-100, limit: limit), -limit)
    }

    /// 最後のデッキの先でも同じように縮める。
    func testRubberBandWorksAtTheLastDeck() {
        let layout = DeckCarouselLayout(count: 5)
        let limit = 0.45

        let pulled = layout.rubberBanded(6.0, limit: limit)

        XCTAssertGreaterThan(pulled, 4)
        XCTAssertLessThan(pulled, 4 + limit)
    }

    /// デッキが1件のときは、どちらへ引いても同じ1枚のまわりで縮める。
    func testRubberBandWithASingleDeck() {
        let layout = DeckCarouselLayout(count: 1)
        let limit = 0.45

        XCTAssertGreaterThan(layout.rubberBanded(-2, limit: limit), -limit)
        XCTAssertLessThan(layout.rubberBanded(2, limit: limit), limit)
    }

    /// 画面端を通過してもカードの上下順が逆転しない。
    func testSpacingRemainsOrderedAcrossVisibleRange() {
        let offsets = (-250...250).map { Double($0) / 100 }
        let positions = offsets.map(DeckCarouselLayout.compressedOffset)
        for (previous, next) in zip(positions, positions.dropFirst()) {
            XCTAssertLessThan(previous, next)
        }
        for offset in offsets {
            XCTAssertEqual(DeckCarouselLayout.compressedOffset(-offset),
                           -DeckCarouselLayout.compressedOffset(offset), accuracy: 0.0001)
        }
    }

    /// 端より先へは進めない。
    func testClampStopsAtBothEnds() {
        let layout = DeckCarouselLayout(count: 5)
        XCTAssertEqual(layout.clamp(-1), 0)
        XCTAssertEqual(layout.clamp(-4), 0)
        XCTAssertEqual(layout.clamp(5), 4)
        XCTAssertEqual(layout.clamp(2), 2)
        XCTAssertEqual(DeckCarouselLayout(count: 0).clamp(3), 0)
    }
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
