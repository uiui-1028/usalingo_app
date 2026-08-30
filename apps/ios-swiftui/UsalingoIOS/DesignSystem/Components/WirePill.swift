import SwiftUI

/// Outline Wireframe Design System — ピル / チップ（仕様書 Section 3）。
///
/// 選択状態は色ではなく「枠線を `strokeHeavy` へ昇格 + 文字を `.bold`」で示す（Section 3.2）。
struct WirePill: View {
    let title: String
    var isSelected: Bool = false

    var body: some View {
        Text(title)
            .wireFont(.label)
            .fontWeight(isSelected ? .bold : .semibold)
            .padding(.vertical, WireMetrics.spacingS)
            .padding(.horizontal, WireMetrics.spacingM)
            .outlineSurface(
                radius: WireMetrics.radiusSmall,
                stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
                shadow: nil
            )
    }
}

/// メニュー項目（仕様書 Section 3）。
/// 選択時のみ枠線を出し、未選択は線を出さない。
struct WireMenuItem: View {
    let title: String
    var isSelected: Bool = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(isSelected ? .bold : .regular))
            .foregroundStyle(WireColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WireMetrics.spacingS)
            .padding(.horizontal, WireMetrics.spacingM)
            .modifier(WireMenuItemBackground(isSelected: isSelected))
    }
}

private struct WireMenuItemBackground: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.outlineSurface(radius: WireMetrics.radiusSmall, shadow: nil)
        } else {
            content
        }
    }
}
