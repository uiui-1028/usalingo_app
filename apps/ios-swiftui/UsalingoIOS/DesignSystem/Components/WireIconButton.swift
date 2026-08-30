import SwiftUI

/// Outline Wireframe Design System — アイコンボタン / アバター（仕様書 Section 3）。
///
/// ```swift
/// Button { … } label: { Image(systemName: "plus") }
///     .buttonStyle(.wireIcon)
///     .accessibilityLabel("追加")
/// ```
struct WireIconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 44
    /// 選択状態。既定は Section 3.2 のとおり枠線を `strokeHeavy` へ昇格して示す。
    var isSelected: Bool = false
    /// タブバーの現在地など、より強い「ここにいる」表現が要る場所だけ
    /// 黒ベタ反転を使う（Section 1 原則 2）。
    var invertsWhenSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(
            diameter: diameter,
            isSelected: isSelected,
            invertsWhenSelected: invertsWhenSelected,
            configuration: configuration
        )
    }

    private struct StyleBody: View {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let diameter: CGFloat
        let isSelected: Bool
        let invertsWhenSelected: Bool
        let configuration: Configuration

        private var isInverted: Bool { isSelected && invertsWhenSelected }

        var body: some View {
            configuration.label
                .font(.body.weight(isSelected ? .bold : .semibold))
                .foregroundStyle(isInverted ? WireColor.surface : WireColor.ink)
                .frame(width: diameter, height: diameter)
                .outlineCircleSurface(
                    stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
                    filled: isInverted
                )
                .contentShape(Circle())
                .wirePressEffect(configuration.isPressed, reduceMotion: reduceMotion)
                .wireDisabled(!isEnabled)
        }
    }
}

extension ButtonStyle where Self == WireIconButtonStyle {
    static var wireIcon: WireIconButtonStyle { WireIconButtonStyle() }

    static func wireIcon(
        diameter: CGFloat = 44,
        isSelected: Bool = false,
        invertsWhenSelected: Bool = false
    ) -> WireIconButtonStyle {
        WireIconButtonStyle(
            diameter: diameter,
            isSelected: isSelected,
            invertsWhenSelected: invertsWhenSelected
        )
    }
}

/// アバター。円に頭文字などを載せる。
struct WireAvatar: View {
    var initials: String = ""
    var diameter: CGFloat = 44

    var body: some View {
        Text(initials)
            .wireFont(.label)
            .frame(width: diameter, height: diameter)
            .outlineCircleSurface(stroke: WireMetrics.strokeBase)
    }
}
