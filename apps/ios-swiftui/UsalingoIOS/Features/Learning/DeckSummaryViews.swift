import SwiftUI

/// デッキの見分け記号（B-12）。デッキIDから決めるので、開き直しても変わらない。
/// 学習の進み具合とは関係がないため、数字と分けて持つ。
enum DeckCoverSymbol {
    private static let symbols = ["diamond", "triangle", "circle", "square", "hexagon", "seal"]

    static func forDeck(id: Int) -> String {
        symbols[abs(id % symbols.count)]
    }
}

/// デッキの進み具合（B-2 / B-3 / B-4 / B-8）。そのデッキの実際のカードと学習記録から数える。
///
/// 新規と復習の「いま出せる枚数」は出題の上限が効くので、`StudyDeckCounts` を別に使う。
struct DeckProgressSummary: Equatable {
    /// 収録内容プレビュー（B-8）に出す語数。
    static let previewWordLimit = 5

    static let empty = DeckProgressSummary(cards: [])

    let totalCount: Int
    let masteredCount: Int
    let learningCount: Int
    let weakCount: Int
    let previewWords: [String]

    /// まだ一度も出していない枚数。4つのチップの合計が総枚数と合うようにする。
    var untouchedCount: Int {
        max(0, totalCount - masteredCount - learningCount - weakCount)
    }

    var masteryRatio: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(masteredCount) / Double(totalCount))
    }

    var masteryPercentText: String {
        "\(Int((masteryRatio * 100).rounded()))%"
    }

    /// 1枚を1つの状態だけに数える。習得が最優先で、苦手は学習中から切り出す。
    /// こうしないとチップの合計が総枚数を超える。
    init(cards: [WordCard]) {
        var mastered = 0
        var learning = 0
        var weak = 0
        for card in cards {
            if card.learningStatus == "mastered" {
                mastered += 1
            } else if card.learning?.isWeak == true {
                weak += 1
            } else if card.learning != nil {
                learning += 1
            }
        }
        totalCount = cards.count
        masteredCount = mastered
        learningCount = learning
        weakCount = weak
        previewWords = cards.prefix(Self.previewWordLimit).map(\.text)
    }
}

/// デッキの見分け記号（B-12）。色相を持てないので、枠と記号だけで区別する。
struct DeckCoverMark: View {
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .wireFont(.titleS)
            .frame(width: size, height: size)
            .outlineSurface(radius: WireMetrics.radiusSmall, shadow: nil)
            .accessibilityHidden(true)
    }
}

/// 習得率バー（B-3）。塗りは ink、下地は scrim。色は使わない。
struct DeckMasteryBar: View {
    let masteredCount: Int
    let totalCount: Int
    let ratio: Double
    let percentText: String

    private let height: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WireColor.scrim)
                    Capsule()
                        .fill(WireColor.ink)
                        .frame(width: max(0, proxy.size.width * ratio))
                }
                .overlay(
                    Capsule()
                        .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair)
                )
            }
            .frame(height: height)

            HStack {
                Text("習得 \(masteredCount) / \(totalCount)")
                Spacer(minLength: WireMetrics.spacingS)
                Text(percentText)
            }
            .wireFont(.caption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("習得率")
        .accessibilityValue("\(totalCount) 語のうち \(masteredCount) 語、\(percentText)")
    }
}

/// 状態内訳（B-4）。4つの数の合計が総枚数と合うよう、すべて同じ集計から引く。
/// 苦手だけ枠線を太くして、色を使わずに目を引かせる。
struct DeckStatusChips: View {
    let summary: DeckProgressSummary
    /// 横に収まらないときは縦に積む。
    var axis: Axis = .horizontal

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: WireMetrics.spacingS))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: WireMetrics.spacingXS))
        layout {
            WirePill(title: "新規 \(summary.untouchedCount)", font: .caption)
            WirePill(title: "学習中 \(summary.learningCount)", font: .caption)
            WirePill(title: "習得 \(summary.masteredCount)", font: .caption)
            if summary.weakCount > 0 {
                WirePill(title: "苦手 \(summary.weakCount)", isSelected: true, font: .caption)
            }
        }
    }
}

/// 仮の数字を出している場所に添える断り書き。
/// デザインタブの「ワイヤーフレーム開発モード」と同じ役割。
struct WireframeNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .wireFont(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
