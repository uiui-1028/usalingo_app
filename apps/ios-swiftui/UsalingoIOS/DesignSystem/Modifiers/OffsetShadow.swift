import SwiftUI

/// Outline Wireframe Design System — ハードシャドウ（仕様書 Section 2.4 / 4.3）。
///
/// ぼかしは使わない。`.shadow(radius: 0,...)` は環境により描画差があるため、
/// 背面に同形の塗り Shape を敷いて再現する。
struct OffsetShadow: Equatable {
    let x: CGFloat
    let y: CGFloat
    let opacity: Double

    /// カード、注文カード。
    static let card = OffsetShadow(x: 3, y: 3, opacity: 0.07)
    /// 検索欄、入力欄。
    static let control = OffsetShadow(x: 2, y: 2, opacity: 0.08)
    /// 画面レベルのコンテナ。
    static let container = OffsetShadow(x: 4, y: 4, opacity: 0.10)

    /// 押下中は紙が沈むように影を `(1, 1)` へ縮める（Section 3.2）。
    var pressed: OffsetShadow {
        OffsetShadow(x: min(x, 1), y: min(y, 1), opacity: opacity)
    }
}

private struct OffsetShadowModifier<S: Shape>: ViewModifier {
    let shadow: OffsetShadow?
    let shape: S

    func body(content: Content) -> some View {
        if let shadow {
            content.background(
                shape
                    .fill(WireColor.ink.opacity(shadow.opacity))
                    .offset(x: shadow.x, y: shadow.y)
            )
        } else {
            content
        }
    }
}

extension View {
    /// 任意形状の背面にハードシャドウを敷く。
    func offsetShadow<S: Shape>(_ shadow: OffsetShadow?, in shape: S) -> some View {
        modifier(OffsetShadowModifier(shadow: shadow, shape: shape))
    }

    /// 角丸長方形の背面にハードシャドウを敷く。
    func offsetShadow(_ shadow: OffsetShadow?, radius: CGFloat = WireMetrics.radiusCard) -> some View {
        offsetShadow(shadow, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
