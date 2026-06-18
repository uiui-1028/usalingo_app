import Foundation

struct AuthSession: Decodable {
    let accessToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

struct AuthUser: Decodable {
    let id: String
    let email: String?
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

final class AuthService {
    func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await authRequest(path: "token", query: [URLQueryItem(name: "grant_type", value: "password")], email: email, password: password)
        try await ensureCurrentUserRow(session: session)
        return session
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let session = try await authRequest(path: "signup", query: [], email: email, password: password)
        try await ensureCurrentUserRow(session: session)
        return session
    }

    private func authRequest(path: String, query: [URLQueryItem], email: String, password: String) async throws -> AuthSession {
        var components = URLComponents(url: SupabaseConfig.authURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Auth failed")
        }
        let responseBody = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let accessToken = responseBody.accessToken, let user = responseBody.user else {
            throw AuthError.emailConfirmationRequired
        }
        return AuthSession(accessToken: accessToken, user: user)
    }

    private func ensureCurrentUserRow(session: AuthSession) async throws {
        try await SupabaseClient.shared.execute(
            path: "rpc/ensure_current_user_row",
            accessToken: session.accessToken
        )
    }
}

enum AuthError: LocalizedError {
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "確認メールを開いたあと、Sign Inしてください。"
        }
    }
}
