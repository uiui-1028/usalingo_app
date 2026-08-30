import SwiftUI

/// Outline Wireframe Design System — タイムライン（仕様書 Section 3）。
///
/// ドットは太線の円、線は `strokeHair` を不透明度 `0.35` で引く。
struct WireTimeline<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var dotDiameter: CGFloat = 14
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                    VStack(spacing: 0) {
                        WireTimelineDot(diameter: dotDiameter)
                        if index < items.count - 1 {
                            WireTimelineLine()
                        }
                    }
                    .frame(width: dotDiameter)

                    content(item)
                        .padding(.bottom, index < items.count - 1 ? WireMetrics.spacingL : 0)
                }
            }
        }
    }
}

struct WireTimelineDot: View {
    var diameter: CGFloat = 14

    var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .outlineCircleSurface(stroke: WireMetrics.strokeHeavy)
            .accessibilityHidden(true)
    }
}

struct WireTimelineLine: View {
    var body: some View {
        Rectangle()
            .fill(WireColor.ink.opacity(WireMetrics.timelineLineOpacity))
            .frame(width: WireMetrics.strokeHair)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}
