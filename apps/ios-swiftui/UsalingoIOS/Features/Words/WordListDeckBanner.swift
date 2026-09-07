import SwiftUI

/// 単語リストの背面（バナー）に置くデッキ選択の帯。
///
/// 前面のシートより1段退いた面に、所持しているデッキを横に並べる。
/// ここを押すと「どのデッキの単語を見るか」を切り替える入口になる。
///
/// - Important: この帯は**戻るスワイプの通り道**でもある。横スクロールを
///   持たせると指の動きを取り合ってしまうため、いまは画面幅に収まる数だけを
///   並べ、横スクロールは持たせない。デッキが増えたときの見せ方は
///   `docs/plans/word-list-deck-banner-plan.md` で決める。
struct WordListDeckBanner: View {
    let decks: [Deck]
    let selectedDeckID: Int?
    let onSelect: (Deck) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            HStack(spacing: WireMetrics.spacingM) {
                ForEach(decks) { deck in
                    WordListDeckTile(deck: deck, isSelected: deck.id == selectedDeckID)
                        .cardTapTarget { onSelect(deck) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 見た目だけの段階であることを、この画面の中で断っておく。
            WireframeNotice(text: "デッキの並びと切り替えはまだ仮です。単語の中身は変わりません。")
        }
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
        .padding(WireMetrics.spacingM)
        .outlineSurface(
            radius: WireMetrics.radiusCard,
            stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
            shadow: isSelected ? .card : nil,
            fill: isSelected ? WireColor.surface : WireColor.groupL2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityHint("このデッキの単語に切り替えます")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
