import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 1
    @State private var isTabBarHiddenByScroll = false
    @State private var previousVerticalDragTranslation: CGFloat?
    @State private var playStyleFrames: [DeckPlayStyle: CGRect] = [:]
    @State private var playStyleDragOffset: CGFloat = 0
    @Namespace private var playStyleSelection
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card

    var body: some View {
        TabView(selection: $selectedTab) {
            DesignDashboardView()
                .tabItem { Label("Design", systemImage: "paintpalette") }
                .tag(0)
                .glassTabBar(tabBarVisibility)

            LearningDashboardView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !appState.isShellChromeHidden {
                        playStyleBar
                            .padding(.horizontal, WireMetrics.screenPadding)
                            .padding(.bottom, WireMetrics.spacingM)
                    }
                }
                .tabItem { Label("Game", systemImage: "bolt") }
                .tag(1)
                .glassTabBar(tabBarVisibility)

            ProfileDashboardView(onScrollDrag: updateTabBarVisibility)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(2)
                .glassTabBar(tabBarVisibility)
        }
        .onChange(of: selectedTab) { _, _ in
            isTabBarHiddenByScroll = false
            previousVerticalDragTranslation = nil
        }
        .onChange(of: appState.isShellChromeHidden) { _, isHidden in
            previousVerticalDragTranslation = nil
            if !isHidden {
                isTabBarHiddenByScroll = false
            }
        }
    }

    private var tabBarVisibility: Visibility {
        appState.isShellChromeHidden || isTabBarHiddenByScroll ? .hidden : .visible
    }

    private func updateTabBarVisibility(_ value: DragGesture.Value?) {
        guard let value else {
            previousVerticalDragTranslation = nil
            return
        }
        // 横スクロール（保存済みコンセプトなど）の僅かな縦ブレでは反応しない。
        guard abs(value.translation.height) > abs(value.translation.width) else {
            previousVerticalDragTranslation = nil
            return
        }

        defer { previousVerticalDragTranslation = value.translation.height }
        guard let previousVerticalDragTranslation else { return }

        let verticalMovement = value.translation.height - previousVerticalDragTranslation
        guard abs(verticalMovement) > 0.5 else { return }
        isTabBarHiddenByScroll = verticalMovement < 0
    }

    /// 遊び方は5つあるので、普段はアイコンだけにし、
    /// 選んだものにだけ名前を出す。1行に収めたまま、いまの選択が読めるようにする。
    private var playStyleBar: some View {
        HStack(spacing: WireMetrics.spacingXS) {
            ForEach(DeckPlayStyle.allCases) { style in
                let isSelected = playStyle == style
                Button {
                    playStyle = style
                } label: {
                    HStack(spacing: WireMetrics.spacingXS) {
                        Image(systemName: style.symbol)

                        if isSelected {
                            Text(style.title)
                                .wireFont(.label, color: .primary)
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.horizontal, isSelected ? WireMetrics.spacingM : 0)
                    .background {
                        if isSelected {
                            playStyleSelectionBackground
                                .offset(x: playStyleDragOffset)
                                .matchedGeometryEffect(id: "selection", in: playStyleSelection)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .named("playStyleBar"))
                        .onChanged { value in
                            guard isSelected else { return }
                            playStyleDragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard isSelected else { return }
                            finishPlayStyleDrag(value)
                        }
                )
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PlayStyleFramesKey.self,
                            value: [style: geometry.frame(in: .named("playStyleBar"))]
                        )
                    }
                }
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(WireMetrics.spacingXS)
        .glassBarSurface(in: Capsule())
        .coordinateSpace(name: "playStyleBar")
        .onPreferenceChange(PlayStyleFramesKey.self) { playStyleFrames = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: playStyle)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("デッキの遊び方")
    }

    @ViewBuilder
    private var playStyleSelectionBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear).glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule().fill(.primary.opacity(0.14))
        }
    }

    private func finishPlayStyleDrag(_ value: DragGesture.Value) {
        let barBounds = playStyleFrames.values.reduce(CGRect.null) { $0.union($1) }
        let destination = value.location
        let nextStyle: DeckPlayStyle? = barBounds.contains(destination)
            ? playStyleFrames.min { abs($0.value.midX - destination.x) < abs($1.value.midX - destination.x) }?.key
            : nil

        withAnimation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82)) {
            playStyleDragOffset = 0
            if let nextStyle { playStyle = nextStyle }
        }
    }

}

private struct PlayStyleFramesKey: PreferenceKey {
    static var defaultValue: [DeckPlayStyle: CGRect] = [:]

    static func reduce(value: inout [DeckPlayStyle: CGRect], nextValue: () -> [DeckPlayStyle: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
