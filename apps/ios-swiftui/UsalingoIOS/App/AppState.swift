import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum TutorialKey {
        static let hasCompletedSwipeTutorial = "hasCompletedSwipeTutorial"
    }

    @Published var session: AuthSession? {
        didSet {
            guard session?.user.id != oldValue?.user.id else { return }
            handleSessionChange()
        }
    }
    @Published var isRestoringSession = true
    @Published var isResettingPassword = false
    @Published var isShellChromeHidden = false
    @Published private(set) var isSwipeTutorialPresented: Bool
    @Published var authMessage = ""
    @Published private(set) var studyDataVersion = 0
    @Published private(set) var isDeletingAccount = false
    @Published var accountDeletionNotice: String?

    let designSettings: DesignSettings

    /// ローカル同梱データ層（D-1）。デッキ一覧・入出力はこの実体を直接使う。
    let localStudy: LocalStudyDataSource

    /// 学習画面が使うデータ層。通信状態や認証状態にかかわらず、回答を端末へ先に保存する。
    /// Supabase は認証や、既存の復元用バックアップにだけ使う。
    var studyDataSource: any StudyDataSource {
        localStudy
    }

    /// 学習記録のバックアップを裏側で行う係（G-3）。画面からは触らない。
    private lazy var backupSyncer = makeBackupSyncer(localStudy)

    private let authService: AuthService
    private let accountDeletionService: any AccountDeletionServicing
    private let defaults: UserDefaults
    private let makeBackupSyncer: @MainActor (LocalStudyDataSource) -> StudyBackupSyncer

    /// 「まだ登録していない人」。未接続中、または匿名アカウントを指す。
    /// 学習記録はどちらの場合も端末へ保存する。
    var isGuest: Bool {
        session?.user.isAnonymousAccount ?? true
    }

    init(
        restoresSession: Bool = true,
        defaults: UserDefaults = .standard,
        authService: AuthService = AuthService(),
        accountDeletionService: any AccountDeletionServicing = AccountDeletionService(),
        localStudy: LocalStudyDataSource = LocalStudyDataSource(),
        makeBackupSyncer: @escaping @MainActor (LocalStudyDataSource) -> StudyBackupSyncer = { StudyBackupSyncer(localStudy: $0) }
    ) {
        self.localStudy = localStudy
        self.defaults = defaults
        self.authService = authService
        self.accountDeletionService = accountDeletionService
        self.makeBackupSyncer = makeBackupSyncer
        designSettings = DesignSettings(defaults: defaults)
        isSwipeTutorialPresented = !defaults.bool(forKey: TutorialKey.hasCompletedSwipeTutorial)
        guard restoresSession else {
            isRestoringSession = false
            return
        }
        Task { await restoreSession() }
    }

    func setSession(_ session: AuthSession) {
        self.session = session
    }

    func signOut() {
        try? authService.signOut()
        session = nil
        isResettingPassword = false
        // サインアウト後も端末の学習は止めず、裏側で新しい匿名アカウントを作る。
        Task { await startAnonymousSession() }
    }

    func handleIncomingURL(_ url: URL) {
        Task {
            do {
                if let recovered = try await authService.recoverSession(from: url) {
                    session = recovered
                    isResettingPassword = true
                    return
                }
                session = try await authService.sessionFromConfirmationCallback(url: url)
                authMessage = "メール確認が完了しました。"
            } catch {
                authMessage = UserFacingError.message(for: error)
            }
        }
    }

    func setRecoveredPassword(_ password: String, confirmation: String) async throws {
        guard password == confirmation else { throw AuthError.passwordsDoNotMatch }
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updatePassword(password, currentPassword: nil, nonce: nil, accessToken: session.accessToken)
        isResettingPassword = false
    }

    func updatePassword(_ password: String, currentPassword: String, nonce: String? = nil) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updatePassword(password, currentPassword: currentPassword, nonce: nonce, accessToken: session.accessToken)
    }

    /// いまの匿名アカウントを会員登録へ育てる。端末の学習記録はそのまま残る。
    func linkAnonymousAccount(email: String, password: String) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        guard session.user.isAnonymousAccount else { throw AuthError.alreadyRegistered }
        try await authService.linkEmailAndPassword(
            email: email,
            password: password,
            accessToken: session.accessToken
        )
    }

    func updateEmail(_ email: String, currentPassword: String) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updateEmail(email, currentEmail: session.user.email ?? "", currentPassword: currentPassword, accessToken: session.accessToken)
    }

    func deleteAccount(password: String, confirmation: String) async throws {
        guard !isDeletingAccount else { throw AccountDeletionClientError.alreadyInProgress }
        guard confirmation == "退会" else { throw AccountDeletionClientError.invalidConfirmation }
        guard let session else { throw AuthError.sessionRestoreFailed }

        isDeletingAccount = true
        defer { isDeletingAccount = false }
        _ = try await accountDeletionService.withdraw(
            password: password,
            confirmation: confirmation,
            accessToken: session.accessToken
        )

        backupSyncer.stop()
        var resetError: Error?
        do {
            try localStudy.reset()
        } catch {
            resetError = error
        }
        do {
            try authService.signOut()
        } catch {
            resetError = error
        }
        defaults.removeObject(forKey: TutorialKey.hasCompletedSwipeTutorial)
        designSettings.reset()
        self.session = nil
        isSwipeTutorialPresented = true
        isResettingPassword = false
        isShellChromeHidden = false
        studyDataVersion = 0
        if resetError != nil {
            accountDeletionNotice = "アカウントは削除しましたが、端末の初期化を完了できませんでした。"
            throw AccountDeletionClientError.localResetFailed
        }
        accountDeletionNotice = "アカウントと学習記録を削除しました。この操作は取り消せません。"
    }

    func clearAccountDeletionNotice() {
        accountDeletionNotice = nil
    }

    func handleAuthCallback(_ url: URL) async {
        do {
            session = try await authService.sessionFromConfirmationCallback(url: url)
            authMessage = "メール確認が完了しました。"
        } catch {
            authMessage = UserFacingError.message(for: error)
        }
    }

    func markStudyDataChanged() {
        studyDataVersion += 1
        guard let session else { return }
        backupSyncer.scheduleUpload(session: session)
    }

    /// アプリが背面へ回るときに、待機中のバックアップを出しきる。
    func flushStudyBackup() async {
        guard let session else { return }
        await backupSyncer.flush(session: session)
    }

    /// ログイン・セッション復元で利用者が変わったときだけ、バックアップの同期をやり直す。
    private func handleSessionChange() {
        // 匿名アカウントへの端末スナップショット送信は、外部保存の範囲を
        // 広げないため従来どおり行わない。登録済みアカウントだけ既存の控えを使う。
        guard let session, !session.user.isAnonymousAccount else {
            backupSyncer.stop()
            return
        }
        Task { [weak self] in
            guard let self, self.session?.user.id == session.user.id else { return }
            await self.backupSyncer.start(session: session) { [weak self] in
                self?.studyDataVersion += 1
            }
        }
    }

    func showSwipeTutorial() {
        isSwipeTutorialPresented = true
    }

    func dismissSwipeTutorial() {
        isSwipeTutorialPresented = false
    }

    func completeSwipeTutorial() {
        defaults.set(true, forKey: TutorialKey.hasCompletedSwipeTutorial)
        isSwipeTutorialPresented = false
    }

    private func restoreSession() async {
        startupMessage = nil
        do {
            if let restored = try await authService.restoreSession() {
                session = restored
                isRestoringSession = false
                return
            }
        } catch {
            // 復元に失敗しても、下の匿名サインインでやり直す。
        }

        // 保存済みのセッションが無ければ、匿名アカウントで始める。
        // 登録していない利用者にも、会員と同じデッキと同じ記録の置き場所を渡す。
        await startAnonymousSession()
    }

    /// 新しい匿名アカウントを作って、そこから始める。
    /// 起動時と、サインアウトの直後に通る。
    private func startAnonymousSession() async {
        isRestoringSession = true
        startupMessage = nil
        defer { isRestoringSession = false }
        do {
            session = try await authService.signInAnonymously()
        } catch {
            // 端末側の学習経路へ黙って落とさない。始められない理由を出す。
            session = nil
            startupMessage = UserFacingError.message(for: error)
        }
    }

    /// 匿名サインインに失敗したときだけ入る。通信できず学習を始められない理由。
    @Published var startupMessage: String?

    /// 匿名サインインをやり直す。
    func retryStartup() async {
        guard !isRestoringSession, session == nil else { return }
        await restoreSession()
    }

}

#if DEBUG
extension AppState {
    static var preview: AppState {
        AppState(restoresSession: false)
    }
}
#endif
