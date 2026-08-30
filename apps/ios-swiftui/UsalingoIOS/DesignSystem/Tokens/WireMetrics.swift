import SwiftUI

/// Outline Wireframe Design System — 寸法トークン（仕様書 Section 2.2–2.4, 2.6）。
enum WireMetrics {
    // MARK: - 線幅（Section 2.2）

    /// 端末外枠相当のコンテナ、Drawer、アバター等の主役。
    static let strokeHeavy: CGFloat = 2.0
    /// カード、ボタン、入力欄、ピル、アイコンボタン。
    static let strokeBase: CGFloat = 1.5
    /// ダミーテキストバー、区切り線。
    static let strokeHair: CGFloat = 1.0

    // MARK: - 角丸（Section 2.3）

    /// 画面レベルのコンテナ、ヒーロー画像枠。
    static let radiusLarge: CGFloat = 20
    /// カード。
    static let radiusCard: CGFloat = 18
    /// ボタン、検索欄、画像プレースホルダ。
    static let radiusControl: CGFloat = 14
    /// ピル、小さいタグ。
    static let radiusSmall: CGFloat = 12
    /// ダミーテキストバー（カプセル）。
    static let radiusPill: CGFloat = 999

    // MARK: - 余白（Section 2.6）

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 18
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    /// 画面パディング。
    static let screenPadding: CGFloat = spacingL

    // MARK: - 状態（Section 3.2）

    /// 押下中の縮小率。
    static let pressedScale: CGFloat = 0.98
    /// 無効時の不透明度。
    static let disabledOpacity: Double = 0.35
    /// 破壊的操作の破線パターン。
    static let destructiveDash: [CGFloat] = [4, 3]
    /// タイムライン線の不透明度。
    static let timelineLineOpacity: Double = 0.35
    /// 画像プレースホルダの対角線の不透明度。
    static let placeholderCrossOpacity: Double = 0.55
}
