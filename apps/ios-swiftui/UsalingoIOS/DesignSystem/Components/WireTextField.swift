import SwiftUI

/// Outline Wireframe Design System — 入力欄 / 検索欄（仕様書 Section 3 / 4.4）。
///
/// ```swift
/// TextField("メールアドレス", text: $email).textFieldStyle(.wire)
/// ```
struct WireTextFieldStyle: TextFieldStyle {
    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .wireFont(.body)
            .padding(.vertical, WireMetrics.spacingM)
            .padding(.horizontal, WireMetrics.spacingL)
            .outlineSurface(
                radius: WireMetrics.radiusControl,
                stroke: WireMetrics.strokeBase,
                shadow: .control
            )
    }
}

extension TextFieldStyle where Self == WireTextFieldStyle {
    static var wire: WireTextFieldStyle { WireTextFieldStyle() }
}

/// `SecureField` など `TextFieldStyle` を当てられない入力にも使える枠。
struct WireFieldBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .wireFont(.body)
            .padding(.vertical, WireMetrics.spacingM)
            .padding(.horizontal, WireMetrics.spacingL)
            .outlineSurface(
                radius: WireMetrics.radiusControl,
                stroke: WireMetrics.strokeBase,
                shadow: .control
            )
    }
}
