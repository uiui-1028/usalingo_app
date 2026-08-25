import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var isRequestingRecovery = false
    @State private var pendingConfirmationEmail: String?
    @State private var resendAvailableAt = Date.distantPast

    private let authService = AuthService()

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Usalingo")
                .font(.largeTitle.bold())
            Text("イラスト付き英単語帳")
                .foregroundStyle(AppStyle.muted)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Sign In") {
                Task { await submit(signUp: false) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Button("Create Account") {
                Task { await submit(signUp: true) }
            }
            .disabled(isLoading)

            Button("パスワードを忘れた場合") {
                Task { await requestRecovery() }
            }
            .disabled(isLoading || email.isEmpty)

            Button("操作ガイドをもう一度見る") {
                appState.showSwipeTutorial()
            }
            .font(.footnote.weight(.semibold))
            .disabled(isLoading)

            if let pendingConfirmationEmail {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let canResend = context.date >= resendAvailableAt
                    VStack(spacing: 6) {
                        Button(canResend ? "確認メールを再送" : "再送まで \(secondsUntilResend(from: context.date))秒") {
                            Task { await resendConfirmation(to: pendingConfirmationEmail) }
                        }
                        .disabled(isLoading || !canResend)

                        Text("\(pendingConfirmationEmail) に送ったメールを開くと、このアプリへ戻ります。")
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            if !displayMessage.isEmpty {
                Text(displayMessage)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
            }
            Spacer()
        }
        .padding(24)
        .background(AppStyle.background)
    }

    private var displayMessage: String {
        appState.authMessage.isEmpty ? message : appState.authMessage
    }

    private func submit(signUp: Bool) async {
        isLoading = true
        message = ""
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
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func requestRecovery() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.requestPasswordRecovery(email: email)
            message = "メールを確認してください。リンクを開くと、新しいパスワードを設定できます。"
        } catch {
            message = error.localizedDescription
        }
    }

    private func resendConfirmation(to email: String) async {
        isLoading = true
        message = ""
        do {
            try await authService.resendSignUpConfirmation(email: email)
            resendAvailableAt = Date().addingTimeInterval(60)
            message = "確認メールを再送しました。"
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func secondsUntilResend(from date: Date) -> Int {
        max(1, Int(ceil(resendAvailableAt.timeIntervalSince(date))))
    }
}
