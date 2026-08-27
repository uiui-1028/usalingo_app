import SwiftUI

struct DesignDashboardView: View {
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var activeSheet: DesignSheet?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("ワイヤーフレーム開発モード", systemImage: "square.dashed")
                        .font(.headline.bold())
                    Text("機能と画面構成を固める間は、白黒・枠線中心の仮デザインで表示します。")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppStyle.surface)
                .overlay {
                    Rectangle().stroke(AppStyle.ink, lineWidth: 2)
                }

                DesignSettingRow(title: "UIテーマ設定", subtitle: "現在は白黒ワイヤーフレームに固定", symbol: "paintpalette.fill") {
                    activeSheet = .theme
                }
                DesignSettingRow(title: "カードUI設定", subtitle: "現在は細い枠線と小さい角丸に固定", symbol: "rectangle.stack.fill") {
                    activeSheet = .card
                }
                DesignSettingRow(title: "アプリ挙動設定", subtitle: "フォントや触覚などを変更", symbol: "gearshape.fill") {
                    activeSheet = .behavior
                }
                DesignSettingRow(title: "アルゴリズム設定", subtitle: "学習アルゴリズムの調整", symbol: "square.grid.2x2.fill") {
                    activeSheet = .algorithm
                }
            }
            .padding(16)
        }
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
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppStyle.accent)
                    .frame(width: 56, height: 56)
                    .background(AppStyle.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppStyle.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppStyle.muted)
            }
            .padding(18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppStyle.line)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DesignOptionSheet: View {
    @EnvironmentObject private var designSettings: DesignSettings
    let sheet: DesignSheet

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

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

            Spacer()
        }
        .padding(20)
    }

    private var accentOptions: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.square.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("白黒ワイヤーフレーム")
                    .font(.headline)
                Text("色や装飾は、画面の流れが固まってから決めます。")
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(AppStyle.surface)
        .overlay { Rectangle().stroke(AppStyle.line) }
    }

    private var cardOptions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ワイヤーフレーム用カード")
                .font(.headline)
            Text("細い黒枠・影なし・小さい角丸で固定しています。")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
        }
        .padding(14)
        .background(AppStyle.surface)
        .overlay { Rectangle().stroke(AppStyle.line) }
    }

    private var staticOptions: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.0) { option in
                optionRow(option)
            }
        }
    }

    private func settingButton(_ title: String, _ symbol: String, _ subtitle: String, id: String, current: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol)
                    .frame(width: 32)
                    .foregroundStyle(AppStyle.accent(designSettings))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
                Spacer()
                if id == current {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppStyle.accent(designSettings))
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func optionRow(_ option: (String, String, String)) -> some View {
        HStack {
            Image(systemName: option.1)
                .frame(width: 32)
                .foregroundStyle(AppStyle.accent(designSettings))
            VStack(alignment: .leading, spacing: 3) {
                Text(option.0)
                    .font(.headline)
                Text(option.2)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                ("マテリアル", "square.stack.3d.up.fill", "標準的な階層表現"),
                ("ニューモーフ", "circle.hexagongrid.fill", "ソフトな影効果"),
                ("ガラス", "circle.dotted", "透明感のある表現")
            ]
        case .card:
            return [
                ("スワイプ感度", "hand.draw.fill", "カード操作のしきい値"),
                ("カード角丸", "rectangle.roundedtop.fill", "カードの丸み"),
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
                ("正答時の増加量", "arrow.up.forward.circle.fill", "SRSレベル調整"),
                ("誤答時の戻し幅", "arrow.down.backward.circle.fill", "復習負荷の調整")
            ]
        }
    }
}
