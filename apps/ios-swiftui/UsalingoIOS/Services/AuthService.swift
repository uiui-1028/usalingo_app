import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Int?
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Int?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

final class AuthService {
    private let sessionStore = SessionStore()

    func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await authRequest(path: "token", query: [URLQueryItem(name: "grant_type", value: "password")], email: email, password: password)
        try await ensureCurrentUserRow(session: session)
        try sessionStore.save(session)
        return session
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        let session = try await authRequest(path: "signup", query: [], email: email, password: password)
        try await ensureCurrentUserRow(session: session)
        try sessionStore.save(session)
        return session
    }

    func restoreSession() async throws -> AuthSession? {
        guard let saved = try sessionStore.load() else { return nil }
        guard let refreshToken = saved.refreshToken else { return saved }

        do {
            let session = try await refreshSession(refreshToken: refreshToken)
            try await ensureCurrentUserRow(session: session)
            try sessionStore.save(session)
            return session
        } catch {
            try? sessionStore.clear()
            throw error
        }
    }

    func signOut() throws {
        try sessionStore.clear()
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
        return AuthSession(
            accessToken: accessToken,
            refreshToken: responseBody.refreshToken,
            expiresAt: responseBody.expiresAt,
            user: user
        )
    }

    private func ensureCurrentUserRow(session: AuthSession) async throws {
        try await SupabaseClient.shared.execute(
            path: "rpc/ensure_current_user_row",
            accessToken: session.accessToken
        )
    }

    private func refreshSession(refreshToken: String) async throws -> AuthSession {
        var components = URLComponents(url: SupabaseConfig.authURL.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Session refresh failed")
        }

        let responseBody = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let accessToken = responseBody.accessToken, let user = responseBody.user else {
            throw AuthError.sessionRestoreFailed
        }
        return AuthSession(
            accessToken: accessToken,
            refreshToken: responseBody.refreshToken ?? refreshToken,
            expiresAt: responseBody.expiresAt,
            user: user
        )
    }
}

enum AuthError: LocalizedError {
    case emailConfirmationRequired
    case sessionRestoreFailed

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "確認メールを開いたあと、Sign Inしてください。"
        case .sessionRestoreFailed:
            return "セッションの復元に失敗しました。もう一度Sign Inしてください。"
        }
    }
}
