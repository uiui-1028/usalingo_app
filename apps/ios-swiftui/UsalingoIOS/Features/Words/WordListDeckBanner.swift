import SwiftUI

/// 単語リストの背面（バナー）に置くデッキ選択の帯。
///
/// 前面のシートより1段退いた面に、所持しているデッキを札で並べる。
/// 真ん中に来ている札が「いま選んでいるデッキ」。横スワイプで送り、
/// 端は決めずに何周でも回る（A→B→C→D→A→…）。
///
/// - Important: 札の帯は**戻るスワイプを止める領域**にしている
///   （`backSwipeProtectedRegion`）。同じ指の動きに「デッキ送り」と
///   「前の画面へ戻る」を両方は割り当てられないため。札の帯より下
///   （点の行）と、シートの上から始めたスワイプでは今までどおり戻れる。
struct WordListDeckBanner: View {
    let decks: [Deck]
    let onSelect: (Deck) -> Void

    /// 送りの通し番号。デッキ数を超えても戻さず、割った余りで札を決める。
    /// こうすると端が無くなり、右にも左にも回り続けられる。
    @State private var index = 0
    @State private var dragTranslation: CGFloat = 0

    /// 札の縦横比。横スワイプで送る「カード」に見える程度に縦長。
    private let cardAspectRatio: CGFloat = 0.92
    /// 点の行の高さと、その上下の間合い。
    private let indicatorRowHeight: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let cardHeight = max(
                48,
                proxy.size.height - indicatorRowHeight - WireMetrics.spacingS
            )
            let cardWidth = cardHeight * cardAspectRatio
            let step = cardWidth + WireMetrics.spacingL

            VStack(spacing: WireMetrics.spacingS) {
                cardStrip(cardWidth: cardWidth, cardHeight: cardHeight, step: step)
                    .frame(height: cardHeight)

                WordListDeckPageDots(count: decks.count, currentIndex: currentDeckIndex)
                    .frame(height: indicatorRowHeight)
            }
        }
        .onChange(of: index) { _, _ in
            guard let deck = currentDeck else { return }
            onSelect(deck)
        }
    }

    /// 札の帯。真ん中の1枚を選択中として見せ、左右は送り先の予告として覗かせる。
    private func cardStrip(cardWidth: CGFloat, cardHeight: CGFloat, step: CGFloat) -> some View {
        ZStack {
            ForEach(visibleSlots, id: \.self) { slot in
                let isCenter = slot == index
                WordListDeckTile(deck: deck(at: slot), isSelected: isCenter)
                    .frame(width: cardWidth, height: cardHeight)
                    .offset(x: CGFloat(slot - index) * step + dragTranslation)
                    .zIndex(isCenter ? 1 : 0)
                    .cardTapTarget {
                        guard !isCenter else { return }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            index = slot
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        // 札からはみ出した左右の札は、帯の外へ描かない。
        .clipped()
        .contentShape(Rectangle())
        .gesture(carouselGesture(step: step))
        // ここから始めた横の動きは「デッキ送り」に使う。戻るスワイプには渡さない。
        .backSwipeProtectedRegion()
    }

    /// 1枚ぶん動かすのに必要な距離は札の 1/3。勢いよく払ったときは
    /// 指を離した先の位置で判定するので、短い動きでも送れる。
    private func carouselGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                let travel = value.predictedEndTranslation.width
                let threshold = step / 3
                var next = index
                if travel < -threshold {
                    next += 1
                } else if travel > threshold {
                    next -= 1
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    index = next
                    dragTranslation = 0
                }
            }
    }

    /// 画面に出る可能性のある札だけを作る。両端の2枚は画面の外だが、
    /// 送りはじめに空白が見えないよう先に用意しておく。
    private var visibleSlots: [Int] {
        guard !decks.isEmpty else { return [] }
        return Array((index - 3)...(index + 3))
    }

    /// 通し番号を実際のデッキへ割り当てる。負の数でも正しく回るようにする。
    private func deck(at slot: Int) -> Deck {
        let count = decks.count
        return decks[((slot % count) + count) % count]
    }

    private var currentDeckIndex: Int {
        guard !decks.isEmpty else { return 0 }
        let count = decks.count
        return ((index % count) + count) % count
    }

    private var currentDeck: Deck? {
        guard !decks.isEmpty else { return nil }
        return decks[currentDeckIndex]
    }
}

/// いま何枚目かを示す点の行。塗りつぶしが今いる場所。
struct WordListDeckPageDots: View {
    let count: Int
    let currentIndex: Int

    private let diameter: CGFloat = 8

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            ForEach(0..<max(0, count), id: \.self) { position in
                Circle()
                    .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair)
                    .background(
                        Circle().fill(position == currentIndex ? WireColor.surface : WireColor.ink)
                    )
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("デッキ \(currentIndex + 1) / \(count)")
    }
}

/// デッキ1件分の札。選択中は「線を太く・面を白く・影を付ける」で示す。
/// 色は使わない（Outline Wireframe Design System Section 2.1）。
struct WordListDeckTile: View {
    let deck: Deck
    let isSelected: Bool

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            DeckCoverMark(symbol: DeckDisplaySample.forDeck(id: deck.id).coverSymbol, size: 34)
            Text(deck.deckName)
                .wireFont(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WireMetrics.spacingS)
        .outlineSurface(
            radius: WireMetrics.radiusCard,
            stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
            shadow: isSelected ? .card : nil,
            fill: isSelected ? WireColor.surface : WireColor.scrim
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityHint("このデッキの単語に切り替えます")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
