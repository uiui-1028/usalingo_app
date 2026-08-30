import SwiftUI

/// Outline Wireframe Design System — 画像プレースホルダ（仕様書 Section 3.1）。
///
/// 角丸長方形の枠内に、矩形の対角を結ぶ 2 本の線を描く。枠外へはみ出さないようクリップする。
struct WireImagePlaceholder: View {
    var radius: CGFloat = WireMetrics.radiusControl
    var stroke: CGFloat = WireMetrics.strokeBase

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return shape
            .fill(WireColor.surface)
            .overlay(
                DiagonalCross()
                    .stroke(
                        WireColor.ink.opacity(WireMetrics.placeholderCrossOpacity),
                        lineWidth: stroke
                    )
                    .clipShape(shape)
            )
            .overlay(shape.strokeBorder(WireColor.ink, lineWidth: stroke))
            .accessibilityHidden(true)
    }
}

/// 矩形の対角を結ぶ 2 本の線。
struct DiagonalCross: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
