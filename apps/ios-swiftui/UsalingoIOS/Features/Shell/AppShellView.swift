import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var selectedTab = 1

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", symbol: "paintpalette"),
        .init(title: "学習", symbol: "bolt"),
        .init(title: "プロフィール", symbol: "person.crop.circle")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            WireColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        DesignDashboardView()
                    case 2:
                        ProfileDashboardView()
                    default:
                        LearningDashboardView()
                    }
                }
                .padding(.bottom, appState.isShellChromeHidden ? 0 : 96)
            }

            if !appState.isShellChromeHidden {
                floatingTabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: appState.isShellChromeHidden)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        selectedTab = index
                    }
                } label: {
                    Image(systemName: tab.symbol)
                }
                .buttonStyle(
                    .wireIcon(
                        diameter: 48,
                        isSelected: selectedTab == index,
                        invertsWhenSelected: true
                    )
                )
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
            }
        }
        .padding(WireMetrics.spacingM)
        // 画面の一番下にある常設の部品なので、階調の一番濃い段に合わせる。
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card, fill: BentoTone.l3.fill)
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingXL)
    }
}

private struct ShellTab {
    let title: String
    let symbol: String
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
