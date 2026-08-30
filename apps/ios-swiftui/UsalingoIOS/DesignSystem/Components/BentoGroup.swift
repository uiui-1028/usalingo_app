import SwiftUI

/// Bento グルーピング — 面の段階（計画書 4.2）。
///
/// 画面の上にあるまとまりほど薄く、下にあるまとまりほど濃くする。
/// 濃さの下限は「補助テキスト `subText` が WCAG AA の本文基準 4.5:1 を
/// 満たすこと」から逆算していて、`l3` がその限界にあたる。
/// **これ以上濃い段を足さないこと。**
enum BentoTone {
    case l1
    case l2
    case l3

    var fill: Color {
        switch self {
        case .l1: return WireColor.groupL1
        case .l2: return WireColor.groupL2
        case .l3: return WireColor.groupL3
        }
    }

    /// 押下中の面。可読性の下限である `l3` まで濃くして、
    /// 枠線を持たない行でも「押した」ことが分かるようにする。
    var pressed: BentoTone { .l3 }
}

/// Bento グルーピング — まとまりを囲う枠（計画書 5.1）。
///
/// ```swift
/// BentoGroup(title: "デッキ一覧", tone: .l1) {
///     // 中身。原則としてここに置く要素は枠を持たない。
/// }
/// ```
///
/// 中に個別のカード枠を重ねない。区切りは `WireDivider` と余白で行う。
struct BentoGroup<Content: View, Accessory: View>: View {
    var title: String?
    var tone: BentoTone = .l1
    /// 既定は影なし。`List` の行背景で描くグループと見た目を揃えるため（計画書 4.3）。
    var shadow: OffsetShadow?
    var padding: CGFloat = WireMetrics.spacingL
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    private var hasAccessory: Bool { Accessory.self != EmptyView.self }

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            if title != nil || hasAccessory {
                HStack(alignment: .firstTextBaseline, spacing: WireMetrics.spacingS) {
                    if let title {
                        Text(title).wireFont(.titleS)
                    }
                    Spacer(minLength: 0)
                    accessory
                }
            }
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineSurface(
            radius: WireMetrics.radiusLarge,
            stroke: WireMetrics.strokeHeavy,
            shadow: shadow,
            fill: tone.fill
        )
    }
}

extension BentoGroup where Accessory == EmptyView {
    init(
        title: String? = nil,
        tone: BentoTone = .l1,
        shadow: OffsetShadow? = nil,
        padding: CGFloat = WireMetrics.spacingL,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            tone: tone,
            shadow: shadow,
            padding: padding,
            content: content,
            accessory: { EmptyView() }
        )
    }
}

// MARK: - List の行で1つの枠を描く（計画書 5.2）

/// グループの中での行の位置。枠のどの辺を描くかを決める。
enum BentoRowPosition {
    case top
    case middle
    case bottom
    /// 1行だけでグループが完結する場合。
    case single

    var hasTop: Bool { self == .top || self == .single }
    var hasBottom: Bool { self == .bottom || self == .single }

    init(isFirst: Bool, isLast: Bool) {
        switch (isFirst, isLast) {
        case (true, true): self = .single
        case (true, false): self = .top
        case (false, true): self = .bottom
        case (false, false): self = .middle
        }
    }
}

/// `List` の行背景。行をまたいで1つの角丸の枠に見せる。
///
/// 角丸長方形を行の外へはみ出させてから行の範囲で切り取ることで、
/// 上端・下端の線と角丸を「その行に必要な分だけ」残す。
/// 手で円弧を描くより崩れにくい。
struct BentoRowBackground: View {
    var position: BentoRowPosition
    var tone: BentoTone = .l1
    var horizontalInset: CGFloat = WireMetrics.screenPadding
    /// 次の行との区切り線。グループの最終行では出さない。
    var showsDivider: Bool = false

    private let radius = WireMetrics.radiusLarge

    var body: some View {
        GeometryReader { proxy in
            let overhang = radius + WireMetrics.strokeHeavy
            let top = position.hasTop ? 0 : overhang
            let bottom = position.hasBottom ? 0 : overhang
            let shape = RoundedRectangle(cornerRadius: radius, style: .circular)

            shape
                .fill(tone.fill)
                .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHeavy))
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height + top + bottom
                )
                .offset(y: -top)
        }
        .clipped()
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(WireColor.ink)
                    .frame(height: WireMetrics.strokeHair)
                    .padding(.horizontal, WireMetrics.spacingL)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, horizontalInset)
    }
}

/// 枠を持たない行のボタン。押下中だけ面を濃くして、押せることを示す。
struct BentoRowButtonStyle: ButtonStyle {
    var tone: BentoTone = .l1
    var radius: CGFloat = WireMetrics.radiusControl

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(tone: tone, radius: radius, configuration: configuration)
    }

    private struct StyleBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let tone: BentoTone
        let radius: CGFloat
        let configuration: Configuration

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(configuration.isPressed ? tone.pressed.fill : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .wirePressEffect(configuration.isPressed, reduceMotion: reduceMotion)
        }
    }
}

extension ButtonStyle where Self == BentoRowButtonStyle {
    static var bentoRow: BentoRowButtonStyle { BentoRowButtonStyle() }

    static func bentoRow(tone: BentoTone) -> BentoRowButtonStyle {
        BentoRowButtonStyle(tone: tone)
    }
}

extension View {
    /// `List` の行をグループの一部として敷く。行自身の背景・区切り線・余白を
    /// 消し、代わりに `BentoRowBackground` を敷く。
    ///
    /// - Parameters:
    ///   - horizontal: 枠の内側に足す余白。行の中身が枠線へ触れないようにする。
    func bentoListRow(
        position: BentoRowPosition,
        tone: BentoTone = .l1,
        showsDivider: Bool = false,
        horizontal: CGFloat = WireMetrics.spacingXS,
        vertical: CGFloat = 0
    ) -> some View {
        listRowBackground(
            BentoRowBackground(position: position, tone: tone, showsDivider: showsDivider)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: vertical,
                leading: WireMetrics.screenPadding + horizontal,
                bottom: vertical,
                trailing: WireMetrics.screenPadding + horizontal
            )
        )
    }
}
