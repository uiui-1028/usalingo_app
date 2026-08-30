import SwiftUI

/// Outline Wireframe Design System — カラートークン（仕様書 Section 2.1）。
///
/// 色相を持つ色は定義しない。強調は「線幅」と「黒ベタ反転」で行う。
/// Dark mode は現時点で未定義のため、`Color(red:green:blue:)` の
/// 固定 sRGB 値を使い、配色がカラースキームで反転しないようにしている。
enum WireColor {
    /// 全ての境界線・主要テキスト・Primary ボタン背景。`#1C1C1E`
    static let ink = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0)
    /// 部品の背景（原則すべてこれ）。`#FFFFFF`
    static let surface = Color.white
    /// 画面の下地。`#F4F4F5`
    static let background = Color(red: 244.0 / 255.0, green: 244.0 / 255.0, blue: 245.0 / 255.0)
    /// 補助テキスト。`#6B6D71`
    static let subText = Color(red: 107.0 / 255.0, green: 109.0 / 255.0, blue: 113.0 / 255.0)
    /// Drawer 背面など、退避した面。`#E9E9EA`
    static let scrim = Color(red: 233.0 / 255.0, green: 233.0 / 255.0, blue: 234.0 / 255.0)
}
