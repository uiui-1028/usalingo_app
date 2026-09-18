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
                    if phase == .active {
                        Task {
                            await appState.retryStartup()
                            await appState.refreshOfficialContentIfConnected()
                        }
                        return
                    }
                    // 背面へ回る前に、待機中の学習記録バックアップを出しきる。
                    Task { await appState.flushStudyBackup() }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            if appState.isResettingPassword {
                PasswordResetView()
            } else {
                AppShellView()
                    .overlay(alignment: .top) {
                        if appState.session == nil, !appState.isRestoringSession {
                            OfflineStatusPill {
                                Task { await appState.retryStartup() }
                            }
                        }
                    }
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

/// 通信できなくても学習は止めず、ノッチの下に小さく状態だけ出す。タップで再接続する。
private struct OfflineStatusPill: View {
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            Text("offline-MODE")
                .wireFont(.caption)
                .foregroundStyle(WireColor.ink)
                .padding(.horizontal, WireMetrics.spacingL)
                .padding(.vertical, WireMetrics.spacingXS)
                .background(WireColor.groupL3, in: Capsule())
                .overlay(Capsule().stroke(WireColor.ink, lineWidth: WireMetrics.strokeHair))
        }
        .buttonStyle(.plain)
        .padding(.top, WireMetrics.spacingXS)
        .accessibilityLabel("オフライン。学習記録は端末に保存されます。")
        .accessibilityHint("ダブルタップで接続を試します。")
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
