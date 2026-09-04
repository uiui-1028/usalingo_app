import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var selectedTab = 1

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", selectedTitle: "Design", symbol: "paintpalette"),
        .init(title: "学習", selectedTitle: "Game", symbol: "bolt"),
        .init(title: "プロフィール", selectedTitle: "Profile", symbol: "person.crop.circle")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
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
