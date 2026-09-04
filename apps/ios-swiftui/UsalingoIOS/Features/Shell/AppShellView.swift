import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var selectedTab = 1
    @State private var isTabBarHiddenByScroll = false
    @State private var previousVerticalDragTranslation: CGFloat?
    @State private var tabBarHeight: CGFloat = 0

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", selectedTitle: "Design", symbol: "paintpalette"),
        .init(title: "学習", selectedTitle: "Game", symbol: "bolt"),
        .init(title: "プロフィール", selectedTitle: "Profile", symbol: "person.crop.circle")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            shellBody
                // 下端の操作をタブバーの下までスクロールできるようにする。これは透明な
                // スペーサーなので、Body の背景を切ったり、見た目の高さを固定したりしない。
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        // 学習タブは NavigationStack 内の List が自分で末尾余白を持つ。
                        // 二重に確保しないよう、ほかの Body だけシェル側で避ける。
                        .frame(height: isTabBarPresented && selectedTab != 1 ? tabBarScrollClearance : 0)
                        .allowsHitTesting(false)
                }

            if isTabBarPresented {
                floatingTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: appState.isShellChromeHidden)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isTabBarHiddenByScroll)
        // ScrollView / List を各画面ごとに実装し直さず、Body 配下の縦ドラッグを同時に
        // 見る。下方向へ動いたら隠し、折り返して少しでも上方向へ動いた時点で戻す。
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged(updateTabBarVisibility)
                .onEnded { _ in previousVerticalDragTranslation = nil },
            including: .subviews
        )
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
        .onPreferenceChange(ShellTabBarHeightKey.self) { tabBarHeight = $0 }
    }

    private var shellBody: some View {
        Group {
            switch selectedTab {
            case 0:
                DesignDashboardView()
            case 2:
                ProfileDashboardView()
            default:
                LearningDashboardView(
                    bottomActionBarClearance: isTabBarPresented ? tabBarScrollClearance : 0,
                    setActionBarHidden: { isTabBarHiddenByScroll = $0 }
                )
            }
        }
    }

    private var isTabBarPresented: Bool {
        !appState.isShellChromeHidden && !isTabBarHiddenByScroll
    }

    private var tabBarScrollClearance: CGFloat {
        // 実測値を優先するので、将来タブの文字や余白が大きくなっても末尾の操作に重ならない。
        max(ShellTabBarLayout.minimumScrollClearance, tabBarHeight + WireMetrics.screenPadding)
    }

    private func updateTabBarVisibility(_ value: DragGesture.Value) {
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

    private var floatingTabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                let isSelected = selectedTab == index

                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        selectedTab = index
                    }
                } label: {
                    HStack(spacing: WireMetrics.spacingS) {
                        Image(systemName: tab.symbol)

                        if isSelected {
                            Text(tab.selectedTitle)
                                .wireFont(.label, color: WireColor.surface)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .foregroundStyle(isSelected ? WireColor.surface : WireColor.ink)
                    .frame(minWidth: 48, minHeight: 48)
                    .padding(.horizontal, isSelected ? WireMetrics.spacingM : 0)
                    .background(Capsule().fill(isSelected ? WireColor.ink : WireColor.surface))
                    .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isSelected)
            }
        }
        .padding(WireMetrics.spacingM)
        .background(Capsule().fill(.clear))
        .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
        .offsetShadow(.card, in: Capsule())
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingXL)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ShellTabBarHeightKey.self, value: proxy.size.height)
            }
        }
    }
}

private enum ShellTabBarLayout {
    /// 初回レイアウトでバー高を実測するまで確保する、安全側の最小値。
    static let minimumScrollClearance: CGFloat = 48 + (WireMetrics.spacingM * 2) + WireMetrics.spacingXL + WireMetrics.screenPadding
}

private struct ShellTabBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ShellTab {
    let title: String
    let selectedTitle: String
    let symbol: String
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
