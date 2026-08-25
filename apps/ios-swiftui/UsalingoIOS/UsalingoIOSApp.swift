import SwiftUI

@main
struct UsalingoIOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.designSettings)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            if appState.isRestoringSession {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppStyle.background)
            } else if appState.initialLearningProfile == nil {
                InitialLearningProfileView { profile in
                    try appState.completeInitialLearningProfile(profile)
                }
            } else if appState.session == nil {
                AuthView()
            } else if appState.isResettingPassword {
                PasswordResetView()
            } else {
                AppShellView()
            }

            if appState.isSwipeTutorialPresented, !appState.isRestoringSession {
                SwipeTutorialView(
                    complete: appState.completeSwipeTutorial,
                    dismiss: appState.dismissSwipeTutorial
                )
                .zIndex(1)
            }
        }
    }
}

private struct PasswordResetView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var message = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("新しいパスワード")
                .font(.title2.bold())
            Text("8文字以上で入力してください。")
                .foregroundStyle(AppStyle.muted)
            SecureField("新しいパスワード", text: $password)
                .textFieldStyle(.roundedBorder)
            SecureField("もう一度入力", text: $confirmation)
                .textFieldStyle(.roundedBorder)
            Button("パスワードを保存") {
                Task { await save() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer()
        }
        .padding(24)
        .background(AppStyle.background)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.setRecoveredPassword(password, confirmation: confirmation)
        } catch {
            message = error.localizedDescription
        }
    }
}
