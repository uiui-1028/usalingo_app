import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var session: AuthSession?
    @Published var isRestoringSession = true
    @Published var isResettingPassword = false
    @Published var isShellChromeHidden = false
    @Published private(set) var initialLearningProfile: InitialLearningProfile?
    @Published private(set) var studyDataVersion = 0

    let designSettings = DesignSettings()

    private let authService = AuthService()
    private let initialLearningProfileStore: any InitialLearningProfileStoring

    init(
        restoresSession: Bool = true,
        initialLearningProfileStore: any InitialLearningProfileStoring = InitialLearningProfileStore()
    ) {
        self.initialLearningProfileStore = initialLearningProfileStore
        initialLearningProfile = initialLearningProfileStore.load()
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
                guard let recovered = try await authService.recoverSession(from: url) else { return }
                session = recovered
                isResettingPassword = true
            } catch {
                session = nil
                isResettingPassword = false
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

    func markStudyDataChanged() {
        studyDataVersion += 1
    }

    func completeInitialLearningProfile(_ profile: InitialLearningProfile) throws {
        try initialLearningProfileStore.save(profile)
        initialLearningProfile = profile
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
