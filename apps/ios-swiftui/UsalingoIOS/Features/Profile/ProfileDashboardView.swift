import SwiftUI

struct ProfileDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats = StudyStats(studiedCount: 0, dueCount: 0, masteredCount: 0, currentStreak: 0)

    private let studyService = StudyService()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ProfileTile(title: "\(stats.currentStreak)", subtitle: "日連続学習", symbol: "flame.fill", color: .orange)
                HeatmapTile()
                ProfileTile(title: "実績サマリー", subtitle: "\(stats.masteredCount)語マスター", symbol: "trophy.fill", color: .yellow)
                ProfileTile(title: "ユーザー名", subtitle: "タップで設定", symbol: "person.crop.circle.fill", color: AppStyle.accent)
                ProfileTile(title: "\(stats.studiedCount)", subtitle: "学習中の単語", symbol: "sparkles", color: .purple)
                ProfileTile(title: "ウィジェットの追加", subtitle: "空きスロット", symbol: "plus", color: .secondary)
                    .opacity(0.6)
            }
            .padding(16)
        }
        .task { await loadStats() }
    }

    private func loadStats() async {
        guard let session = appState.session else { return }
        do {
            stats = try await studyService.fetchStudyStats(session: session)
        } catch {
            stats = StudyStats(studiedCount: 0, dueCount: 0, masteredCount: 0, currentStreak: 0)
        }
    }
}

private struct ProfileTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppStyle.line)
        }
    }
}

private struct HeatmapTile: View {
    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppStyle.accent)
            Text("学習ヒートマップ")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < 5 ? Color.green : Color.gray.opacity(0.25))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppStyle.line)
        }
    }
}
