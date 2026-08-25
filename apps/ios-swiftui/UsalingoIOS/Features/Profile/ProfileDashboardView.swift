import SwiftUI

struct ProfileDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stats = StudyStats.empty
    @State private var profile = UserProfile(userId: "", nickname: nil, plan: "free")
    @State private var isEditingProfile = false
    @State private var isShowingLegalSamples = false
    @State private var message = ""

    private let studyService = StudyService()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ProfileTile(title: "\(stats.currentStreak)", symbol: "flame.fill", color: .orange)
                HeatmapTile(reviewedDays: stats.reviewedDays)
                ProfileTile(title: "実績サマリー", symbol: "trophy.fill", color: .yellow)
                Button {
                    isEditingProfile = true
                } label: {
                    ProfileTile(
                        title: displayName,
                        symbol: "person.crop.circle.fill",
                        color: AppStyle.accent
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                Button {
                    isShowingLegalSamples = true
                } label: {
                    ProfileTile(
                        title: "法務・ライセンス",
                        symbol: "doc.text.magnifyingglass",
                        color: .blue
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityHint("公開前のサンプルを含む法務・ライセンス画面を開きます")
                ProfileTile(title: "\(stats.studiedCount)", symbol: "sparkles", color: .purple)
                ProfileTile(title: "\(stats.totalReviews)", symbol: "checkmark.circle.fill", color: .green)
            }
            .padding(16)

            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
                    .padding(.horizontal, 16)
            }

            Button {
                appState.showSwipeTutorial()
            } label: {
                Label("操作ガイドをもう一度見る", systemImage: "hand.draw")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task { await load() }
        .task(id: appState.studyDataVersion) { await refreshStats() }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditSheet(
                nickname: profile.nickname ?? "",
                signOut: appState.signOut
            ) { nickname in
                await saveNickname(nickname)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingLegalSamples) {
            LegalSamplesView()
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

private struct LegalSamplesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("サンプルデータ・公開前", systemImage: "testtube.2")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("これは画面確認用の見本です。正式な文書、著作者情報、URL、問い合わせ先に置き換えるまで公開しないでください。")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                        .accessibilityLabel("サンプルデータ、公開前です。正式な文書に置き換えるまで公開しないでください。")
                }

                Section("文書とクレジットの見本") {
                    ForEach(LegalSample.editableSamples) { sample in
                        LegalSampleRow(sample: sample)
                    }
                }

                Section("問い合わせ先の見本") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("サンプル問い合わせ先（公開前）")
                            .foregroundStyle(AppStyle.ink)
                        Text("support@example.invalid")
                            .font(.footnote.monospaced())
                            .foregroundStyle(AppStyle.muted)
                        Text("実際のメールは送信しません。正式な窓口へ差し替えてください。")
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section {
                    Text("編集場所: ProfileDashboardView.swift の LegalSample.editableSamples。公開前にサンプルを削除し、法務承認済みの値へ置き換えます。")
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            }
            .navigationTitle("法務・ライセンス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityLabel("法務・ライセンス画面を閉じる")
                }
            }
        }
    }
}

// MARK: - Sample data only
// Replace every value below with legal-approved records before release.
private struct LegalSample: Identifiable {
    let id: String
    let title: String
    let version: String
    let effectiveDate: String
    let author: String
    let work: String
    let license: String
    let linkStatus: String

    static let editableSamples: [LegalSample] = [
        .init(
            id: "sample-terms",
            title: "利用規約（サンプル・公開前）",
            version: "v0.0-sample",
            effectiveDate: "YYYY-MM-DD に置き換え",
            author: "法務承認後の事業者名に置き換え",
            work: "正式な利用規約",
            license: "該当する公開条件に置き換え",
            linkStatus: "正式URL: 未公開（この行はリンクではありません）"
        ),
        .init(
            id: "sample-privacy",
            title: "プライバシー（サンプル・公開前）",
            version: "v0.0-sample",
            effectiveDate: "YYYY-MM-DD に置き換え",
            author: "個人情報取扱責任者に置き換え",
            work: "正式なプライバシーポリシー",
            license: "公開条件に置き換え",
            linkStatus: "正式URL: 未公開（この行はリンクではありません）"
        ),
        .init(
            id: "sample-license",
            title: "ライセンス（サンプル・公開前）",
            version: "v0.0-sample",
            effectiveDate: "YYYY-MM-DD に置き換え",
            author: "コンテンツ提供者名に置き換え",
            work: "デッキまたはアセット名に置き換え",
            license: "ライセンス名と条件に置き換え",
            linkStatus: "ライセンスURL: 未公開（この行はリンクではありません）"
        ),
        .init(
            id: "sample-credit",
            title: "クレジット（サンプル・公開前）",
            version: "v0.0-sample",
            effectiveDate: "YYYY-MM-DD に置き換え",
            author: "著作者名に置き換え",
            work: "作品名・素材名に置き換え",
            license: "利用許諾またはライセンスに置き換え",
            linkStatus: "出典URL: 未公開（この行はリンクではありません）"
        )
    ]
}

private struct LegalSampleRow: View {
    let sample: LegalSample

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sample.title)
                .font(.headline)
                .foregroundStyle(AppStyle.ink)
            Text("版: \(sample.version) ・施行日: \(sample.effectiveDate)")
                .font(.footnote)
                .foregroundStyle(AppStyle.muted)
            Text("著作者・提供者: \(sample.author)")
            Text("作品・対象: \(sample.work)")
            Text("ライセンス: \(sample.license)")
            Text(sample.linkStatus)
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileTile: View {
    let title: String
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
        }
        .modifier(ProfileWidgetTileStyle())
    }
}

private struct ProfileWidgetTileStyle: ViewModifier {
    func body(content: Content) -> some View {
        AppStyle.profileWidgetTile {
            content
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
        .modifier(ProfileWidgetTileStyle())
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
    @EnvironmentObject private var appState: AppState
    @State private var nickname: String
    @State private var isManagingAccount = false
    let signOut: () -> Void
    let save: (String) async -> Void

    init(nickname: String, signOut: @escaping () -> Void, save: @escaping (String) async -> Void) {
        _nickname = State(initialValue: nickname)
        self.signOut = signOut
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ユーザー名") {
                    TextField("ユーザー名", text: $nickname)
                        .textInputAutocapitalization(.never)
                }
                Section("アカウント") {
                    Button("メールアドレス・パスワードを変更") {
                        isManagingAccount = true
                    }
                }
                Section {
                    Button(role: .destructive) {
                        signOut()
                        dismiss()
                    } label: {
                        Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
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
        .sheet(isPresented: $isManagingAccount) {
            AccountSecuritySheet()
                .environmentObject(appState)
        }
    }
}

private struct AccountSecuritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var passwordNonce = ""
    @State private var newEmail = ""
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("パスワードを変更") {
                    SecureField("今のパスワード", text: $currentPassword)
                    SecureField("新しいパスワード（8文字以上）", text: $newPassword)
                    Button("古いログインにも確認コードを送る") {
                        Task { await requestReauthentication() }
                    }
                    TextField("確認コード（届いたときだけ）", text: $passwordNonce)
                        .textInputAutocapitalization(.never)
                    Button("パスワードを変更") {
                        Task { await changePassword() }
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty)
                }

                Section("メールアドレスを変更") {
                    Text("現在: \(appState.session?.user.email ?? "未設定")")
                    TextField("新しいメールアドレス", text: $newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("今のパスワード", text: $currentPassword)
                    Button("メールアドレスを変更") {
                        Task { await changeEmail() }
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newEmail.isEmpty)
                    Text("今のメールと新しいメールの両方に届く確認メールを開くと、変更が完了します。")
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }

                if !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("アカウントの安全")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func requestReauthentication() async {
        guard let token = appState.session?.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService().reauthenticate(accessToken: token)
            message = "確認コードをメールに送りました。届いたときだけ入力してください。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func changePassword() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.updatePassword(newPassword, currentPassword: currentPassword, nonce: passwordNonce)
            message = "パスワードを変更しました。"
            newPassword = ""
            passwordNonce = ""
        } catch {
            message = error.localizedDescription
        }
    }

    private func changeEmail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.updateEmail(newEmail, currentPassword: currentPassword)
            message = "2つのメールアドレスに確認メールを送りました。両方を開いてください。"
            newEmail = ""
        } catch {
            message = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("Profile Dashboard") {
    ZStack {
        GridBackground()
        ProfileDashboardView()
    }
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
