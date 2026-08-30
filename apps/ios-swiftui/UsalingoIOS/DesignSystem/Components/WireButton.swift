import SwiftUI

/// Outline Wireframe Design System — ボタン（仕様書 Section 3 / 4.4）。
///
/// 独自 View ではなく `ButtonStyle` として実装し、既存の `Button` 呼び出しを
/// 壊さずに着せ替えられるようにする。
///
/// ```swift
/// Button("ログイン") { … }.buttonStyle(.wirePrimary)
/// Button("アカウント作成") { … }.buttonStyle(.wireSecondary)
/// Button("削除する") { … }.buttonStyle(.wireDestructive)
/// ```
struct WireButtonStyle: ButtonStyle {
    enum Kind {
        /// ink 反転。画面の主行動。
        case primary
        /// surface + 枠線。
        case secondary
        /// 破線の枠線で破壊的操作を示す。赤は使わない。
        case destructive
    }

    var kind: Kind
    var radius: CGFloat = WireMetrics.radiusControl

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(kind: kind, radius: radius, configuration: configuration)
    }

    private struct StyleBody: View {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let kind: Kind
        let radius: CGFloat
        let configuration: Configuration

        var body: some View {
            configuration.label
                .wireFont(.label, color: kind == .primary ? WireColor.surface : WireColor.ink)
                .padding(.vertical, WireMetrics.spacingM)
                .padding(.horizontal, WireMetrics.spacingL)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(kind == .primary ? WireColor.ink : WireColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            WireColor.ink,
                            style: StrokeStyle(
                                lineWidth: WireMetrics.strokeBase,
                                dash: kind == .destructive ? WireMetrics.destructiveDash : []
                            )
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .wirePressEffect(configuration.isPressed, reduceMotion: reduceMotion)
                .wireDisabled(!isEnabled)
        }
    }
}

extension ButtonStyle where Self == WireButtonStyle {
    static var wirePrimary: WireButtonStyle { WireButtonStyle(kind: .primary) }
    static var wireSecondary: WireButtonStyle { WireButtonStyle(kind: .secondary) }
    static var wireDestructive: WireButtonStyle { WireButtonStyle(kind: .destructive) }
}

extension View {
    /// 押下表現（Section 3.2）。`Reduce Motion` 有効時はアニメーションを止める。
    func wirePressEffect(_ isPressed: Bool, reduceMotion: Bool) -> some View {
        scaleEffect(isPressed && !reduceMotion ? WireMetrics.pressedScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
    }
}
