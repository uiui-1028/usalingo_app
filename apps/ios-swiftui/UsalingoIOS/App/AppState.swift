import Foundation

@MainActor
final class AppState: ObservableObject {
    private enum TutorialKey {
        static let hasCompletedSwipeTutorial = "hasCompletedSwipeTutorial"
    }

    @Published var session: AuthSession?
    @Published var isRestoringSession = true
    @Published var isResettingPassword = false
    @Published var isShellChromeHidden = false
    @Published private(set) var isSwipeTutorialPresented: Bool
    @Published var authMessage = ""
    @Published private(set) var studyDataVersion = 0
    @Published private(set) var isDeletingAccount = false
    @Published var accountDeletionNotice: String?

    let designSettings: DesignSettings

    private let authService: AuthService
    private let accountDeletionService: any AccountDeletionServicing
    private let defaults: UserDefaults

    var isGuest: Bool {
        session == nil
    }

    init(
        restoresSession: Bool = true,
        defaults: UserDefaults = .standard,
        authService: AuthService = AuthService(),
        accountDeletionService: any AccountDeletionServicing = AccountDeletionService()
    ) {
        self.defaults = defaults
        self.authService = authService
        self.accountDeletionService = accountDeletionService
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
                authMessage = error.localizedDescription
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

    func updateEmail(_ email: String, currentPassword: String) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updateEmail(email, currentEmail: session.user.email ?? "", currentPassword: currentPassword, accessToken: session.accessToken)
    }

    func deleteAccount(password: String, confirmation: String, requestID: UUID) async throws {
        guard !isDeletingAccount else { throw AccountDeletionClientError.alreadyInProgress }
        guard confirmation == "退会" else { throw AccountDeletionClientError.invalidConfirmation }
        guard let session else { throw AuthError.sessionRestoreFailed }

        isDeletingAccount = true
        defer { isDeletingAccount = false }
        let receipt = try await accountDeletionService.withdraw(
            password: password,
            confirmation: confirmation,
            requestID: requestID,
            accessToken: session.accessToken
        )

        var resetError: Error?
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
        accountDeletionNotice = "退会手続きが完了しました。\(formattedRestorationNotice(receipt.restorableUntil))"

        if resetError != nil {
            throw AccountDeletionClientError.localResetFailed
        }
    }

    func clearAccountDeletionNotice() {
        accountDeletionNotice = nil
    }

    func handleAuthCallback(_ url: URL) async {
        do {
            session = try await authService.sessionFromConfirmationCallback(url: url)
            authMessage = "メール確認が完了しました。"
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func markStudyDataChanged() {
        studyDataVersion += 1
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
        defer { isRestoringSession = false }
        do {
            session = try await authService.restoreSession()
        } catch {
            session = nil
        }
    }

    private func formattedRestorationNotice(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else {
            return "365日以内は本人確認後に復元できます。"
        }
        let display = DateFormatter()
        display.locale = Locale(identifier: "ja_JP")
        display.dateFormat = "yyyy年M月d日"
        return "\(display.string(from: date))までは本人確認後に復元できます。"
    }
}

#if DEBUG
extension AppState {
    static var preview: AppState {
        AppState(restoresSession: false)
    }
}
#endif
