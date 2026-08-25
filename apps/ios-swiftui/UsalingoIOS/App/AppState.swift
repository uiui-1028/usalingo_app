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
    @Published private(set) var initialLearningProfile: InitialLearningProfile?
    @Published private(set) var isSwipeTutorialPresented: Bool
    @Published var authMessage = ""
    @Published private(set) var studyDataVersion = 0

    let designSettings = DesignSettings()

    private let authService = AuthService()
    private let initialLearningProfileStore: any InitialLearningProfileStoring
    private let defaults: UserDefaults

    init(
        restoresSession: Bool = true,
        initialLearningProfileStore: any InitialLearningProfileStoring = InitialLearningProfileStore(),
        defaults: UserDefaults = .standard
    ) {
        self.initialLearningProfileStore = initialLearningProfileStore
        self.defaults = defaults
        initialLearningProfile = initialLearningProfileStore.load()
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

    func completeInitialLearningProfile(_ profile: InitialLearningProfile) throws {
        try initialLearningProfileStore.save(profile)
        initialLearningProfile = profile
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
}

#if DEBUG
extension AppState {
    static var preview: AppState {
        AppState(restoresSession: false)
    }
}
#endif
