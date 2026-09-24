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
    /// 面の塗り。Bento グループでは段階のある灰色を渡す（計画書 4.2）。
    var fill: Color = WireColor.surface

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
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
    /// 操作バーだけに使う。新しいOSはシステムのガラス、旧OSは半透明素材。
    @ViewBuilder
    func glassBarSurface<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
        #else
        // Xcode 16 のCIには glassEffect がない。旧SDKでは半透明素材を使う。
        background(.regularMaterial, in: shape)
        #endif
    }

    func glassBarSelection<S: Shape>(_ selected: Bool, in shape: S) -> some View {
        background {
            if selected {
                shape.fill(.primary.opacity(0.14))
            }
        }
    }

    @ViewBuilder
    func glassNavigationBar() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            toolbarBackground(.regularMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    func glassTabBar(_ visibility: Visibility) -> some View {
        if #available(iOS 26.0, *) {
            toolbar(visibility, for: .tabBar)
        } else {
            toolbar(visibility, for: .tabBar)
                .toolbarBackground(.regularMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }

    func outlineSurface(
        radius: CGFloat = WireMetrics.radiusCard,
        stroke: CGFloat = WireMetrics.strokeBase,
        shadow: OffsetShadow? = .card,
        dashed: Bool = false,
        fill: Color = WireColor.surface
    ) -> some View {
        modifier(
            OutlineSurface(radius: radius, stroke: stroke, shadow: shadow, dashed: dashed, fill: fill)
        )
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
