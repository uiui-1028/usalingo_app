import SwiftUI

@main
struct UsalingoIOSApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.designSettings)
                .tint(WireColor.ink)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    // 背面へ回る前に、待機中の学習記録バックアップを出しきる。
                    guard phase != .active else { return }
                    Task { await appState.flushStudyBackup() }
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
                    .tint(WireColor.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WireColor.background)
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
        .alert("アカウントを削除しました", isPresented: Binding(
            get: { appState.accountDeletionNotice != nil },
            set: { if !$0 { appState.clearAccountDeletionNotice() } }
        )) {
            Button("確認") { appState.clearAccountDeletionNotice() }
        } message: {
            Text(appState.accountDeletionNotice ?? "")
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
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: WireMetrics.spacingXL) {
                    VStack(spacing: WireMetrics.spacingS) {
                        Text("新しいパスワード")
                            .wireFont(.titleL)
                        Text("8文字以上で入力してください。")
                            .wireFont(.caption)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                    VStack(spacing: WireMetrics.spacingM) {
                        WireFieldBox {
                            SecureField("新しいパスワード", text: $password)
                        }
                        WireFieldBox {
                            SecureField("もう一度入力", text: $confirmation)
                        }
                    }

                    Button("パスワードを保存") {
                        Task { await save() }
                    }
                    .buttonStyle(.wirePrimary)
                    .disabled(isSaving)

                    if !message.isEmpty {
                        // 色相を使わずに異常を示す（破線 + 文言）。
                        Text(message)
                            .wireFont(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(WireMetrics.spacingM)
                            .outlineSurface(
                                radius: WireMetrics.radiusControl,
                                shadow: nil,
                                dashed: true
                            )
                    }
                }
                .padding(WireMetrics.screenPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(WireColor.background)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.setRecoveredPassword(password, confirmation: confirmation)
        } catch {
            message = UserFacingError.message(for: error)
        }
    }
}
