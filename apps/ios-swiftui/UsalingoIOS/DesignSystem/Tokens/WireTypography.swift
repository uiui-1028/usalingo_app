import SwiftUI

/// Outline Wireframe Design System — タイポグラフィトークン（仕様書 Section 2.5）。
///
/// HTML ワイヤーは 240pt 幅の縮小モックのため pt 値は移植せず、役割で対応させる。
/// Dynamic Type に追随させるため `.font(.system(size:))` は使わない。
enum WireFont: CaseIterable {
    /// 画面タイトル、価格。
    case titleL
    /// セクション見出し。
    case titleS
    /// 本文。
    case body
    /// ラベル、ボタン文字。
    case label
    /// 補助テキスト（`subText` 色とセット）。
    case caption

    var font: Font {
        switch self {
        case .titleL: return .title2
        case .titleS: return .headline
        case .body: return .body
        case .label: return .subheadline
        case .caption: return .caption
        }
    }

    var weight: Font.Weight {
        switch self {
        case .titleL: return .bold
        case .titleS: return .bold
        case .body: return .regular
        case .label: return .semibold
        case .caption: return .regular
        }
    }

    /// 役割ごとの既定の文字色。`caption` のみ補助色とセットで使う。
    var foreground: Color {
        self == .caption ? WireColor.subText : WireColor.ink
    }
}

extension View {
    /// 役割ベースのフォント + 既定色を当てる。
    ///
    /// 色を変える場合は外側から `.foregroundStyle` を重ねても効かない
    /// （内側の指定が勝つ）ため、必ず `color:` で渡すこと。
    func wireFont(_ role: WireFont, color: Color? = nil) -> some View {
        font(role.font.weight(role.weight))
            .foregroundStyle(color ?? role.foreground)
    }
}
