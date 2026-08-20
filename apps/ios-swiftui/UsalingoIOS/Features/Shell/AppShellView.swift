import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    @State private var selectedTab = 1
    @State private var headerHeight: CGFloat = 0
    @State private var bottomToolbarHeight: CGFloat = 0

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", symbol: "paintpalette.fill", color: AppStyle.secondary),
        .init(title: "学習", symbol: "bolt.fill", color: AppStyle.accent),
        .init(title: "プロフィール", symbol: "person.crop.circle.fill", color: AppStyle.sun)
    ]

    var body: some View {
        ZStack {
            shellBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentMargins(
                    .top,
                    appState.isShellChromeHidden ? 0 : headerHeight,
                    for: .scrollContent
                )
                .contentMargins(
                    .bottom,
                    appState.isShellChromeHidden ? 0 : bottomToolbarHeight,
                    for: .scrollContent
                )
                .background(GridBackground())
        }
        .overlay(alignment: .top) {
            if !appState.isShellChromeHidden {
                header
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HeaderHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if !appState.isShellChromeHidden {
                floatingTabBar
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: BottomToolbarHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onPreferenceChange(HeaderHeightPreferenceKey.self) { height in
            if height > 0 {
                headerHeight = height
            }
        }
        .onPreferenceChange(BottomToolbarHeightPreferenceKey.self) { height in
            if height > 0 {
                bottomToolbarHeight = height
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: appState.isShellChromeHidden)
    }

    @ViewBuilder
    private var shellBody: some View {
        switch selectedTab {
        case 0:
            DesignDashboardView()
        case 2:
            ProfileDashboardView()
        default:
            LearningDashboardView()
        }
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

private struct HeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BottomToolbarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
