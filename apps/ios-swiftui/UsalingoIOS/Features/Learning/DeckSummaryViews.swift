import SwiftUI

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

/// 状態内訳（B-4）。4つの数の合計が総枚数と合うよう、すべて同じ仮データから引く。
/// 苦手だけ枠線を太くして、色を使わずに目を引かせる。
struct DeckStatusChips: View {
    let sample: DeckDisplaySample

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            WirePill(title: "新規 \(sample.untouchedCount)", font: .caption)
            WirePill(title: "学習中 \(sample.learningCount)", font: .caption)
            WirePill(title: "習得 \(sample.masteredCount)", font: .caption)
            if sample.weakCount > 0 {
                WirePill(title: "苦手 \(sample.weakCount)", isSelected: true, font: .caption)
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

/// 保存したコンセプト1件のカード（A-5）。横スクロールのレールに並べる。
struct SavedConceptCard: View {
    let concept: SavedConcept

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
            Text(concept.title)
                .wireFont(.label)
            Text(concept.summary)
                .wireFont(.caption)
                .lineLimit(2)
        }
        .frame(width: 168, alignment: .leading)
        .padding(WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil)
    }
}
