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
                header
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
                .padding(.bottom, 96)
            }

            floatingTabBar
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

            Button {
                appState.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .foregroundStyle(AppStyle.muted)
                    .frame(width: 44, height: 44)
                    .background(AppStyle.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(AppStyle.line, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
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
                    HStack(spacing: 8) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: .semibold))
                        if selectedTab == index {
                            Text(tab.title)
                                .font(.subheadline.weight(.black))
                        }
                    }
                    .foregroundStyle(selectedTab == index ? .white : AppStyle.muted)
                    .frame(height: 48)
                    .padding(.horizontal, selectedTab == index ? 16 : 12)
                    .background(selectedTab == index ? tab.color : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: selectedTab == index ? tab.color.opacity(0.28) : .clear, radius: 0, y: 4)
                }
                .buttonStyle(.plain)
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
