import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var session: AuthSession?
    @Published var isRestoringSession = true
    @Published var isShellChromeHidden = false
    @Published private(set) var studyDataVersion = 0

    let designSettings = DesignSettings()

    private let authService = AuthService()

    init(restoresSession: Bool = true) {
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
    }

    func markStudyDataChanged() {
        studyDataVersion += 1
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
