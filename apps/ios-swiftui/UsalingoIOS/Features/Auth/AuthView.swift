import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    /// `message` が失敗を表すかどうか。破線枠（Section 3.2）の出し分けにだけ使う。
    @State private var isLocalMessageError = false
    @State private var isLoading = false
    @State private var isRequestingRecovery = false
    @State private var pendingConfirmationEmail: String?
    @State private var resendAvailableAt = Date.distantPast

    private let authService = AuthService()

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(WireMetrics.screenPadding)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(WireColor.background)
    }

    private var content: some View {
        VStack(spacing: WireMetrics.spacingXL) {
            header
            fields
            primaryActions
            tertiaryActions

            if let pendingConfirmationEmail {
                resendSection(for: pendingConfirmationEmail)
            }

            if !displayMessage.isEmpty {
                messageBox
            }
        }
    }

    private var header: some View {
        VStack(spacing: WireMetrics.spacingS) {
            Text("Usalingo")
                .wireFont(.titleL)
            Text("イラスト付き英単語帳")
                .wireFont(.caption)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var fields: some View {
        VStack(spacing: WireMetrics.spacingM) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.wire)

            WireFieldBox {
                SecureField("Password", text: $password)
            }
        }
    }

    private var primaryActions: some View {
        VStack(spacing: WireMetrics.spacingM) {
            Button("Sign In") {
                Task { await submit(signUp: false) }
            }
            .buttonStyle(.wirePrimary)
            .disabled(isLoading)

            Button("Create Account") {
                Task { await submit(signUp: true) }
            }
            .buttonStyle(.wireSecondary)
            .disabled(isLoading)
        }
    }

    private var tertiaryActions: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            tertiaryButton("パスワードを忘れた場合", isDisabled: isLoading || email.isEmpty) {
                Task { await requestRecovery() }
            }

            tertiaryButton("操作ガイドをもう一度見る", isDisabled: isLoading) {
                appState.showSwipeTutorial()
            }
        }
    }

    /// 枠線を持たない三次アクション。`WireMenuItem` の未選択状態と同じ扱いにする。
    private func tertiaryButton(
        _ title: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .wireFont(.label)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, WireMetrics.spacingS)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .wireDisabled(isDisabled)
    }

    private func resendSection(for email: String) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let canResend = context.date >= resendAvailableAt
            VStack(spacing: WireMetrics.spacingS) {
                Button(canResend ? "確認メールを再送" : "再送まで \(secondsUntilResend(from: context.date))秒") {
                    Task { await resendConfirmation(to: email) }
                }
                .buttonStyle(.wireSecondary)
                .disabled(isLoading || !canResend)

                Text("\(email) に送ったメールを開くと、このアプリへ戻ります。")
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// 通知欄。失敗のときだけ破線にする（色相は使わない）。
    private var messageBox: some View {
        Text(displayMessage)
            .wireFont(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.spacingM)
            .outlineSurface(
                radius: WireMetrics.radiusControl,
                shadow: nil,
                dashed: isDisplayMessageError
            )
    }

    private var displayMessage: String {
        appState.authMessage.isEmpty ? message : appState.authMessage
    }

    /// `appState.authMessage` は成功と失敗を同じ文字列で運ぶため、
    /// 種別が分かるローカルの `message` のときだけ破線にする。
    private var isDisplayMessageError: Bool {
        appState.authMessage.isEmpty ? isLocalMessageError : false
    }

    private func submit(signUp: Bool) async {
        isLoading = true
        message = ""
        isLocalMessageError = false
        do {
            if signUp {
                switch try await authService.signUp(email: email, password: password) {
                case .authenticated(let session):
                    appState.setSession(session)
                case .confirmationRequired:
                    pendingConfirmationEmail = email
                    resendAvailableAt = Date().addingTimeInterval(60)
                    message = "確認メールを送りました。メールを開いて、このアプリへ戻ってください。"
                }
            } else {
                appState.setSession(try await authService.signIn(email: email, password: password))
            }
        } catch {
            message = UserFacingError.message(for: error)
            isLocalMessageError = true
        }
        isLoading = false
    }

    private func requestRecovery() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.requestPasswordRecovery(email: email)
            message = "メールを確認してください。リンクを開くと、新しいパスワードを設定できます。"
            isLocalMessageError = false
        } catch {
            message = UserFacingError.message(for: error)
            isLocalMessageError = true
        }
    }

    private func resendConfirmation(to email: String) async {
        isLoading = true
        message = ""
        isLocalMessageError = false
        do {
            try await authService.resendSignUpConfirmation(email: email)
            resendAvailableAt = Date().addingTimeInterval(60)
            message = "確認メールを再送しました。"
        } catch {
            message = UserFacingError.message(for: error)
            isLocalMessageError = true
        }
        isLoading = false
    }

    private func secondsUntilResend(from date: Date) -> Int {
        max(1, Int(ceil(resendAvailableAt.timeIntervalSince(date))))
    }
}

#if DEBUG
#Preview("Auth") {
    AuthView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
