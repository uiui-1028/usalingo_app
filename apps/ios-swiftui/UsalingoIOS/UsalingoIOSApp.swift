import SwiftUI

@main
struct UsalingoIOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.session == nil {
                AuthView()
            } else {
                AppShellView()
            }
        }
    }
}
