import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false

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

    private func submit(signUp: Bool) async {
        isLoading = true
        message = ""
        do {
            let session = try await (signUp
                ? authService.signUp(email: email, password: password)
                : authService.signIn(email: email, password: password))
            appState.setSession(session)
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }
}
