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
                if !appState.isShellChromeHidden {
                    header
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
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

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppStyle.accent(designSettings))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: AppStyle.shadow, radius: 0, y: 3)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Usalingo")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppStyle.ink)
                    Text("今日も1セット進めよう")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppStyle.muted)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: selectedTab == index ? tab.color.opacity(0.28) : .clear, radius: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(12)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
        .shadow(color: AppStyle.shadow, radius: 18, y: 8)
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
