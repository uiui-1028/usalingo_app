import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 1

    private let tabs: [ShellTab] = [
        .init(title: "デザイン", symbol: "paintpalette.fill", color: .blue),
        .init(title: "学習", symbol: "graduationcap.fill", color: .orange),
        .init(title: "プロフィール", symbol: "person.fill", color: .green)
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
            Text("Usalingo")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(AppStyle.ink)

            Spacer()

            Button("Sign Out") {
                appState.session = nil
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.white.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(selectedTab == index ? tab.color : AppStyle.muted)
                    .frame(height: 44)
                    .padding(.horizontal, selectedTab == index ? 14 : 12)
                    .background(selectedTab == index ? tab.color.opacity(0.16) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(AppStyle.line)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

private struct ShellTab {
    let title: String
    let symbol: String
    let color: Color
}
