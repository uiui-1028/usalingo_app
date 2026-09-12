import SwiftUI

/// デザインカスタマイズタブ（モック）。
///
/// 画面上 4 割はデザインのプレビュー枠、下 6 割は 4 つの設定モジュールの入口。
/// 実際の設定反映や永続化は行わず、ページ内で選択とスイッチの操作だけを確認する。
struct DesignDashboardView: View {
    @State private var selectedModule: DesignMockModule?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let spacing = WireMetrics.spacingL
                let contentHeight = max(proxy.size.height - WireMetrics.screenPadding * 2 - spacing, 0)
                VStack(spacing: spacing) {
                    DesignPreviewStage()
                        .frame(height: contentHeight * 0.4)
                    DesignModuleGrid(spacing: spacing) { selectedModule = $0 }
                        .frame(height: contentHeight * 0.6)
                }
                .padding(WireMetrics.screenPadding)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedModule) { module in
                DesignModulePage(module: module)
            }
        }
    }
}

/// モジュールごとの仮編集ページ。設定状態はこのページ内だけで保持する。
private struct DesignModulePage: View {
    let module: DesignMockModule
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @GestureState private var sheetDrag: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let panelHeight = min(height * 0.75, max(height * 0.4,
                height * (isExpanded ? 0.75 : 0.5) - sheetDrag))
            let stageHeight = max(0, height - panelHeight)
            let cardHeight = max(0, min(stageHeight - 32, (geometry.size.width - 56) / 0.64))

            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(red: 0.87, green: 0.86, blue: 0.94),
                                        Color(red: 0.72, green: 0.81, blue: 0.91)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black)
                        .frame(width: cardHeight * 0.64, height: cardHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: stageHeight)
                        .allowsHitTesting(false)
                        .accessibilityLabel("カードの仮プレビュー")
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    Button { setExpanded(!isExpanded) } label: {
                        Capsule()
                            .fill(.secondary.opacity(0.3))
                            .frame(width: 44, height: 5)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "編集シートを縮小" : "編集シートを展開")
                    .simultaneousGesture(DragGesture(minimumDistance: 12)
                        .updating($sheetDrag) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            if value.predictedEndTranslation.height < -35 { setExpanded(true) }
                            if value.predictedEndTranslation.height > 35 { setExpanded(false) }
                        })
                    DesignModuleSheet(module: module)
                }
                .frame(height: panelHeight)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.94, green: 0.98, blue: 1))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .background(alignment: .bottom) {
                    Color(red: 0.94, green: 0.98, blue: 1)
                        .frame(height: geometry.safeAreaInsets.bottom)
                        .offset(y: geometry.safeAreaInsets.bottom)
                }
                .shadow(color: .black.opacity(0.12), radius: 20, y: -5)
            }
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear { appState.isShellChromeHidden = false }
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            isExpanded = expanded
        }
    }
}

// MARK: - モックデータ

/// 設定モジュール1件（モック）。
struct DesignMockModule: Identifiable, Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let name: String
    let symbol: String
    let description: String
    let settings: [DesignMockSetting]
}

/// モジュール内の設定項目1件（モック）。
struct DesignMockSetting: Identifiable {
    enum Control {
        /// 選択肢から1つ選ぶ。`defaultIndex` を既定値として強調する。
        case choice(options: [String], defaultIndex: Int?)
        /// ON/OFF を並べる。`onByDefault` が true の項目は ON を強調する。
        case toggles(items: [(label: String, onByDefault: Bool)])
        /// 数値・割合などの入力欄。
        case value(text: String, unit: String)
    }

    let id: String
    let name: String
    let description: String
    let control: Control
    /// 入れ子の選択肢（多義語の表示など）。
    var nested: [DesignMockSetting] = []
}

extension DesignMockModule {
    static let all: [DesignMockModule] = [uiTheme, cardUI, appBehavior, algorithm]

    static let uiTheme = DesignMockModule(
        id: "ui_theme",
        name: "UIテーマ設定モジュール",
        symbol: "paintpalette",
        description: "アプリ全体のルック＆フィールを調整します。この設定はホーム画面のアプリアイコンにも反映されます。",
        settings: [
            DesignMockSetting(
                id: "design_style",
                name: "デザインスタイル",
                description: "UIデザインの基本スタイル。選んだテーマに合わせてアプリアイコンも連動して変わります。",
                control: .choice(
                    options: ["FlatDesign", "Neumorphism", "Glassmorphism", "MaterialDesign"],
                    defaultIndex: 0
                )
            ),
            DesignMockSetting(
                id: "color_mode",
                name: "カラーモード",
                description: "表示モードを切り替えます。",
                control: .choice(
                    options: ["ライトモード", "ダークモード", "システム設定に追従"],
                    defaultIndex: 2
                )
            ),
            DesignMockSetting(
                id: "accent_color",
                name: "アクセントカラー",
                description: "ボタンやアクティブな要素に使う差し色を、用意されたパレットから選びます。",
                control: .choice(
                    options: ["ピンク", "プリセットカラー"],
                    defaultIndex: 0
                )
            )
        ]
    )

    static let cardUI = DesignMockModule(
        id: "card_ui",
        name: "カードUI設定モジュール",
        symbol: "rectangle.stack",
        description: "学習カードの表示要素や操作方法を変更し、集中しやすい情報レイアウトにします。",
        settings: [
            DesignMockSetting(
                id: "card_fields",
                name: "情報表示設定",
                description: "カード上に表示するデータ項目をON/OFFで切り替えます。",
                control: .toggles(items: [
                    ("単語訳", true),
                    ("単語音声", true),
                    ("発音記号", true),
                    ("例文", true),
                    ("例文訳", true),
                    ("例文音声", true),
                    ("品詞", true),
                    ("語源", false),
                    ("類義語", false),
                    ("対義語", false),
                    ("イラスト", false)
                ]),
                nested: [
                    DesignMockSetting(
                        id: "polysemy",
                        name: "多義語の表示",
                        description: "複数の意味を持つ単語の見せ方。",
                        control: .choice(
                            options: ["全ての意味を表示", "主要な意味のみ表示"],
                            defaultIndex: 0
                        )
                    )
                ]
            ),
            DesignMockSetting(
                id: "answer_interaction",
                name: "解答インタラクション",
                description: "解答を表示するときの操作方法を選びます。",
                control: .choice(
                    options: ["パンチアクション（タップで表示）", "カード裏返し（スワイプ／タップで反転）"],
                    defaultIndex: 0
                )
            )
        ]
    )

    static let appBehavior = DesignMockModule(
        id: "app_behavior",
        name: "アプリ挙動設定モジュール",
        symbol: "gearshape",
        description: "視覚以外の感覚フィードバックを調整し、より心地よい学習体験にします。",
        settings: [
            DesignMockSetting(
                id: "font",
                name: "フォント",
                description: "アプリ全体の表示フォント。主にGoogle Fontsから提供し、カスタムフォントも追加予定です。",
                control: .choice(
                    options: ["システム標準フォント", "Google Fontsシリーズ", "カスタムフォント（随時追加）"],
                    defaultIndex: 0
                )
            ),
            DesignMockSetting(
                id: "tts_voice",
                name: "読み上げ音声（TTS）",
                description: "単語や例文を読み上げる音声の種類を選びます。",
                control: .choice(
                    options: ["プリセット音声A（女性・標準速）", "プリセット音声B（男性・標準速）", "プリセット音声C（女性・ゆっくり）"],
                    defaultIndex: 0
                )
            ),
            DesignMockSetting(
                id: "sound_haptics",
                name: "効果音と振動",
                description: "操作時のサウンドエフェクトと触覚フィードバック（Haptics）を切り替えます。",
                control: .toggles(items: [
                    ("効果音", true),
                    ("振動（Haptics）", true)
                ])
            )
        ]
    )

    static let algorithm = DesignMockModule(
        id: "algorithm_settings",
        name: "アルゴリズム設定モジュール",
        symbol: "square.grid.2x2",
        description: "日々の学習ペースや復習の間隔など、記憶の定着を司るアルゴリズムを調整します。",
        settings: [
            DesignMockSetting(
                id: "new_cards_per_day",
                name: "1日の新規カード枚数",
                description: "1日に学習する新しい単語の上限枚数。",
                control: .value(text: "20", unit: "枚／日")
            ),
            DesignMockSetting(
                id: "graduating_interval",
                name: "卒業間隔",
                description: "新規カードを初めて『わかる』にした後、次に復習するまでの日数。",
                control: .value(text: "1", unit: "日")
            ),
            DesignMockSetting(
                id: "easy_interval",
                name: "簡単なカードの間隔",
                description: "学習中のカードを『簡単』と評価した場合の、次の復習までの基本日数。",
                control: .value(text: "4", unit: "日")
            ),
            DesignMockSetting(
                id: "interval_modifier",
                name: "間隔の乗数",
                description: "算出された全ての復習間隔に適用される倍率。",
                control: .value(text: "100", unit: "%")
            ),
            DesignMockSetting(
                id: "maximum_interval",
                name: "最大間隔",
                description: "復習間隔がこの日数を超えないようにする上限値。",
                control: .value(text: "365", unit: "日")
            )
        ]
    )
}

// MARK: - 表示部品

/// 4 つのモジュールを 2 x 2 に敷き詰めるグリッド。説明文は載せない。
private struct DesignModuleGrid: View {
    let spacing: CGFloat
    let onSelect: (DesignMockModule) -> Void

    private var rows: [[DesignMockModule]] {
        stride(from: 0, to: DesignMockModule.all.count, by: 2).map { start in
            Array(DesignMockModule.all[start..<min(start + 2, DesignMockModule.all.count)])
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { module in
                        Button {
                            onSelect(module)
                        } label: {
                            DesignModuleTile(module: module)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(module.name)
                        .accessibilityHint("詳細設定を表示します")
                    }
                }
            }
        }
    }
}

/// グリッド 1 マス分のボタン。アイコンと名前だけを見せる。
private struct DesignModuleTile: View {
    let module: DesignMockModule

    var body: some View {
        VStack(spacing: WireMetrics.spacingM) {
            Image(systemName: module.symbol)
                .wireFont(.titleS)
                .frame(width: 44, height: 44)
                .outlineCircleSurface()

            Text(module.name)
                .wireFont(.label)
                .multilineTextAlignment(.center)
        }
        .padding(WireMetrics.spacingL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}

private struct DesignModuleSheet: View {
    let module: DesignMockModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                HStack(spacing: WireMetrics.spacingM) {
                    Image(systemName: module.symbol)
                        .wireFont(.titleS)
                        .frame(width: 44, height: 44)
                        .outlineCircleSurface()

                    Text(module.name)
                        .wireFont(.titleS)
                }

                ForEach(module.settings) { setting in
                    DesignSettingBlock(setting: setting)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.screenPadding)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct DesignSettingBlock: View {
    let setting: DesignMockSetting

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text(setting.name)
                .wireFont(.label)
            Text(setting.description)
                .wireFont(.caption)

            DesignControlBlock(control: setting.control)

            ForEach(setting.nested) { nested in
                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text(nested.name)
                        .wireFont(.label)
                    Text(nested.description)
                        .wireFont(.caption)
                    DesignControlBlock(control: nested.control)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.spacingM)
                .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil)
    }
}

private struct DesignControlBlock: View {
    let control: DesignMockSetting.Control
    @State private var selectedIndex: Int?
    @State private var toggleValues: [Int: Bool] = [:]

    var body: some View {
        switch control {
        case let .choice(options, defaultIndex):
            WireFlowLayout(spacing: WireMetrics.spacingS) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button { selectedIndex = index } label: {
                        WirePill(
                            title: index == defaultIndex ? "\(option)（デフォルト）" : option,
                            isSelected: index == (selectedIndex ?? defaultIndex),
                            font: .caption
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(index == (selectedIndex ?? defaultIndex) ? .isSelected : [])
                }
            }

        case let .toggles(items):
            VStack(spacing: WireMetrics.spacingXS) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Toggle(item.label, isOn: Binding(
                        get: { toggleValues[index] ?? item.onByDefault },
                        set: { toggleValues[index] = $0 }
                    ))
                    .wireFont(.caption, color: WireColor.ink)
                    .padding(.vertical, WireMetrics.spacingXS)
                }
            }

        case let .value(text, unit):
            HStack(spacing: WireMetrics.spacingS) {
                Text(text)
                    .wireFont(.titleS)
                    .frame(minWidth: 56, alignment: .leading)
                    .padding(.vertical, WireMetrics.spacingS)
                    .padding(.horizontal, WireMetrics.spacingM)
                    .outlineSurface(radius: WireMetrics.radiusSmall, shadow: nil)
                Text(unit)
                    .wireFont(.caption)
                Spacer()
                Text("デフォルト値")
                    .wireFont(.caption)
            }
        }
    }
}

/// ピルを行送りで折り返す簡易レイアウト（モック表示用）。
private struct WireFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needsWrap = !current.items.isEmpty && current.width + spacing + size.width > maxWidth
            if needsWrap {
                rows.append(current)
                current = Row()
            }
            let offset = current.items.isEmpty ? 0 : spacing
            current.items.append(Item(index: index, size: size))
            current.width += offset + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

#Preview {
    DesignDashboardView()
}
