import SwiftUI

/// Outline Wireframe Design System — 枠線 + 影の中核 Modifier（仕様書 Section 4.2）。
///
/// 個別の View で `.overlay(RoundedRectangle...)` を直接書かず、必ずこれを通す。
struct OutlineSurface: ViewModifier {
    var radius: CGFloat = WireMetrics.radiusCard
    var stroke: CGFloat = WireMetrics.strokeBase
    var shadow: OffsetShadow? = .card
    /// 破壊的操作を表す破線（Section 3.2）。赤は使わない。
    var dashed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(WireColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        WireColor.ink,
                        style: StrokeStyle(
                            lineWidth: stroke,
                            dash: dashed ? WireMetrics.destructiveDash : []
                        )
                    )
            )
            .offsetShadow(shadow, radius: radius)
    }
}

/// 円形部品用（アバター、アイコンボタン、タイムラインのドット）。
struct OutlineCircleSurface: ViewModifier {
    var stroke: CGFloat = WireMetrics.strokeBase
    var shadow: OffsetShadow?
    var filled: Bool = false

    func body(content: Content) -> some View {
        content
            .background(Circle().fill(filled ? WireColor.ink : WireColor.surface))
            .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: stroke))
            .offsetShadow(shadow, in: Circle())
    }
}

extension View {
    func outlineSurface(
        radius: CGFloat = WireMetrics.radiusCard,
        stroke: CGFloat = WireMetrics.strokeBase,
        shadow: OffsetShadow? = .card,
        dashed: Bool = false
    ) -> some View {
        modifier(OutlineSurface(radius: radius, stroke: stroke, shadow: shadow, dashed: dashed))
    }

    func outlineCircleSurface(
        stroke: CGFloat = WireMetrics.strokeBase,
        shadow: OffsetShadow? = nil,
        filled: Bool = false
    ) -> some View {
        modifier(OutlineCircleSurface(stroke: stroke, shadow: shadow, filled: filled))
    }

    /// 無効状態の表現（Section 3.2）。色は使わず不透明度で落とす。
    func wireDisabled(_ isDisabled: Bool) -> some View {
        opacity(isDisabled ? WireMetrics.disabledOpacity : 1)
    }
}
