import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var selectedTab = 1

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", symbol: "paintpalette.fill", color: AppStyle.secondary),
        .init(title: "学習", symbol: "bolt.fill", color: AppStyle.accent),
        .init(title: "プロフィール", symbol: "person.crop.circle.fill", color: AppStyle.sun)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            GridBackground()

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
                        .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selectedTab == index ? .white : AppStyle.muted)
                    .frame(width: 48, height: 48)
                    .background(selectedTab == index ? tab.color : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(12)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

private struct ShellTab {
    let title: String
    let symbol: String
    let color: Color
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
