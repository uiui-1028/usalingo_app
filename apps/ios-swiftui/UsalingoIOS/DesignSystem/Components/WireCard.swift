import SwiftUI

/// Outline Wireframe Design System — カード（仕様書 Section 3）。
///
/// 背景 `surface` / 枠線 `strokeBase` / 角丸 `radiusCard` / 影 `shadowCard`。
struct WireCard<Content: View>: View {
    var radius: CGFloat = WireMetrics.radiusCard
    var stroke: CGFloat = WireMetrics.strokeBase
    var shadow: OffsetShadow? = .card
    var padding: CGFloat = WireMetrics.spacingL
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .outlineSurface(radius: radius, stroke: stroke, shadow: shadow)
    }
}

/// 画面レベルのコンテナ。太線 + 大きい角丸 + `shadowContainer`。
struct WireContainer<Content: View>: View {
    var padding: CGFloat = WireMetrics.screenPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .outlineSurface(
                radius: WireMetrics.radiusLarge,
                stroke: WireMetrics.strokeHeavy,
                shadow: .container
            )
    }
}

/// ダミーテキストバー（カプセル）。ワイヤーの「本文がここに入る」表現。
///
/// 参照 HTML の `.card-title`（高さ 8 / 幅 65% / opacity .75）と
/// `.card-sub`（高さ 6 / 幅 40% / opacity .5）に対応する。
struct WireTextBar: View {
    enum Role {
        case title
        case sub

        var height: CGFloat { self == .title ? 8 : 6 }
        var widthRatio: CGFloat { self == .title ? 0.65 : 0.40 }
        var opacity: Double { self == .title ? 0.75 : 0.5 }
    }

    var role: Role = .title
    /// 明示指定がなければ親幅に対する比率で描く。
    var width: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            Capsule(style: .continuous)
                .strokeBorder(
                    WireColor.ink.opacity(role.opacity),
                    lineWidth: WireMetrics.strokeHair
                )
                .frame(width: width ?? proxy.size.width * role.widthRatio, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: role.height)
        .accessibilityHidden(true)
    }
}

/// 区切り線。
struct WireDivider: View {
    var body: some View {
        Rectangle()
            .fill(WireColor.ink)
            .frame(height: WireMetrics.strokeHair)
            .accessibilityHidden(true)
    }
}

extension View {
    /// `List` の行をワイヤーの下地に載せる。行自身の背景・区切り線・余白を消し、
    /// 影のオフセット分だけ余白を確保する。
    func wireListRow(
        horizontal: CGFloat = WireMetrics.screenPadding,
        vertical: CGFloat = WireMetrics.spacingS
    ) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: vertical,
                    leading: horizontal,
                    bottom: vertical,
                    trailing: horizontal
                )
            )
    }
}
