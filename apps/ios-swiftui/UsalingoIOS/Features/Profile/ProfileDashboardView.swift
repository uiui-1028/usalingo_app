import SwiftUI

struct ProfileDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats = StudyStats.empty
    @State private var profile = UserProfile(userId: "", nickname: nil, plan: "free")
    @State private var isEditingProfile = false
    @State private var message = ""

    private let studyService = StudyService()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ProfileTile(title: "\(stats.currentStreak)", subtitle: "日連続学習", symbol: "flame.fill", color: .orange)
                HeatmapTile(reviewedDays: stats.reviewedDays)
                ProfileTile(title: "実績サマリー", subtitle: "\(stats.masteredCount)語マスター", symbol: "trophy.fill", color: .yellow)
                Button {
                    isEditingProfile = true
                } label: {
                    ProfileTile(
                        title: displayName,
                        subtitle: profile.plan == "free" ? "Free Plan" : (profile.plan ?? "Profile"),
                        symbol: "person.crop.circle.fill",
                        color: AppStyle.accent
                    )
                }
                .buttonStyle(.plain)
                ProfileTile(title: "\(stats.studiedCount)", subtitle: "学習中の単語", symbol: "sparkles", color: .purple)
                ProfileTile(title: "\(stats.totalReviews)", subtitle: "累計レビュー", symbol: "checkmark.circle.fill", color: .green)
            }
            .padding(16)

            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
                    .padding(.horizontal, 16)
            }
        }
        .task { await load() }
        .task(id: appState.studyDataVersion) { await refreshStats() }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditSheet(nickname: profile.nickname ?? "") { nickname in
                await saveNickname(nickname)
            }
            .presentationDetents([.medium])
        }
    }

    private var displayName: String {
        let nickname = profile.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        return appState.session?.user.email ?? "ユーザー名"
    }

    private func load() async {
        guard let session = appState.session else { return }
        do {
            stats = try await studyService.fetchStudyStats(session: session)
            profile = try await studyService.fetchUserProfile(session: session)
            message = ""
        } catch {
            stats = .empty
            message = "プロフィール情報を読み込めませんでした。"
        }
    }

    private func refreshStats() async {
        guard let session = appState.session else { return }
        do {
            stats = try await studyService.fetchStudyStats(session: session)
        } catch {
            stats = .empty
        }
    }

    private func saveNickname(_ nickname: String) async {
        guard let session = appState.session else { return }
        do {
            profile = try await studyService.saveUserProfile(nickname: nickname, session: session)
            message = ""
            isEditingProfile = false
        } catch {
            message = "ユーザー名を保存できませんでした。"
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
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
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
    let reviewedDays: [Date]

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppStyle.accent)
            Text("学習ヒートマップ")
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(9), spacing: 3), count: 7), spacing: 3) {
                ForEach(recentDays, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(reviewedDaySet.contains(day) ? Color.green : Color.gray.opacity(0.25))
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

    private var reviewedDaySet: Set<Date> {
        Set(reviewedDays.map { Calendar.current.startOfDay(for: $0) })
    }

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 13, to: today)
        }
    }
}

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String
    let save: (String) async -> Void

    init(nickname: String, save: @escaping (String) async -> Void) {
        _nickname = State(initialValue: nickname)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ユーザー名") {
                    TextField("ユーザー名", text: $nickname)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await save(nickname.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
