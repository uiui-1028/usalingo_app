import SwiftUI

struct DesignDashboardView: View {
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var activeSheet: DesignSheet?

    var body: some View {
        ScrollView {
            VStack(spacing: WireMetrics.spacingL) {
                DesignSettingRow(
                    title: "UIテーマ設定",
                    subtitle: "現在は白黒ワイヤーフレームに固定",
                    symbol: "paintpalette"
                ) {
                    activeSheet = .theme
                }
                DesignSettingRow(
                    title: "カードUI設定",
                    subtitle: "現在は細い枠線と小さい角丸に固定",
                    symbol: "rectangle.stack"
                ) {
                    activeSheet = .card
                }
                DesignSettingRow(
                    title: "アプリ挙動設定",
                    subtitle: "フォントや触覚などを変更",
                    symbol: "gearshape"
                ) {
                    activeSheet = .behavior
                }
                DesignSettingRow(
                    title: "アルゴリズム設定",
                    subtitle: "学習アルゴリズムの調整",
                    symbol: "square.grid.2x2"
                ) {
                    activeSheet = .algorithm
                }
            }
            .padding(WireMetrics.screenPadding)
        }
        .background(WireColor.background)
        .sheet(item: $activeSheet) { sheet in
            DesignOptionSheet(sheet: sheet)
                .environmentObject(designSettings)
                .presentationDetents([.medium, .large])
        }
    }
}

private enum DesignSheet: String, Identifiable {
    case theme
    case card
    case behavior
    case algorithm

    var id: String { rawValue }
}

private struct DesignSettingRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WireMetrics.spacingL) {
                Image(systemName: symbol)
                    .wireFont(.titleS)
                    .frame(width: 44, height: 44)
                    .outlineCircleSurface()

                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text(title)
                        .wireFont(.titleS)
                    Text(subtitle)
                        .wireFont(.caption)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .wireFont(.caption)
            }
            .padding(WireMetrics.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
            .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DesignOptionSheet: View {
    @EnvironmentObject private var designSettings: DesignSettings
    let sheet: DesignSheet

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                Text(title)
                    .wireFont(.titleL)

                switch sheet {
                case .theme:
                    accentOptions
                case .card:
                    cardOptions
                case .behavior:
                    staticOptions
                case .algorithm:
                    staticOptions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.screenPadding)
        }
        .background(WireColor.background)
    }

    private var accentOptions: some View {
        WireCard {
            HStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "checkmark.square")
                    .wireFont(.titleS)
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text("白黒ワイヤーフレーム")
                        .wireFont(.titleS)
                    Text("色や装飾は、画面の流れが固まってから決めます。")
                        .wireFont(.caption)
                }
                Spacer()
            }
        }
    }

    private var cardOptions: some View {
        WireCard {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text("ワイヤーフレーム用カード")
                    .wireFont(.titleS)
                Text("細い黒枠・影なし・小さい角丸で固定しています。")
                    .wireFont(.caption)
            }
        }
    }

    private var staticOptions: some View {
        VStack(spacing: WireMetrics.spacingM) {
            ForEach(options, id: \.0) { option in
                optionRow(option)
            }
        }
    }

    private func optionRow(_ option: (String, String, String)) -> some View {
        HStack(spacing: WireMetrics.spacingM) {
            Image(systemName: option.1)
                .wireFont(.label)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                Text(option.0)
                    .wireFont(.titleS)
                Text(option.2)
                    .wireFont(.caption)
            }
            Spacer()
        }
        .padding(WireMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil)
    }

    private var title: String {
        switch sheet {
        case .theme: "UIテーマ設定"
        case .card: "カードUI設定"
        case .behavior: "アプリ挙動設定"
        case .algorithm: "アルゴリズム設定"
        }
    }

    private var options: [(String, String, String)] {
        switch sheet {
        case .theme:
            return [
                ("フラット", "square", "ミニマルでシンプル"),
                ("マテリアル", "square.stack.3d.up", "標準的な階層表現"),
                ("ニューモーフ", "circle.hexagongrid", "ソフトな影効果"),
                ("ガラス", "circle.dotted", "透明感のある表現")
            ]
        case .card:
            return [
                ("スワイプ感度", "hand.draw", "カード操作のしきい値"),
                ("カード角丸", "rectangle.roundedtop", "カードの丸み"),
                ("影の強さ", "circle.lefthalf.filled", "立体感の調整")
            ]
        case .behavior:
            return [
                ("フォント", "textformat", "表示フォント"),
                ("触覚フィードバック", "iphone.radiowaves.left.and.right", "操作時の振動")
            ]
        case .algorithm:
            return [
                ("復習間隔", "calendar.badge.clock", "次回復習の間隔"),
                ("正答時の増加量", "arrow.up.forward.circle", "SRSレベル調整"),
                ("誤答時の戻し幅", "arrow.down.backward.circle", "復習負荷の調整")
            ]
        }
    }
}
