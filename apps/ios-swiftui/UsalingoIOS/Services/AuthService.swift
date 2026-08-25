import Foundation

protocol NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

protocol SessionStoring {
    func save(_ session: AuthSession) throws
    func load() throws -> AuthSession?
    func clear() throws
}

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
    private let sessionStore: any SessionStoring
    private let client: any SupabaseRequesting
    private let session: any NetworkSession

    init(
        sessionStore: any SessionStoring = SessionStore(),
        client: any SupabaseRequesting = SupabaseClient.shared,
        session: any NetworkSession = URLSession.shared
    ) {
        self.sessionStore = sessionStore
        self.client = client
        self.session = session
    }

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

    func requestPasswordRecovery(email: String) async throws {
        try await executeAuthRequest(path: "recover", body: ["email": email, "redirect_to": "usalingo://auth/recovery"])
    }

    func recoverSession(from url: URL) async throws -> AuthSession? {
        guard url.scheme == "usalingo", url.host == "auth", url.path == "/recovery" else {
            return nil
        }
        let fragment = url.fragment.map { "?\($0)" } ?? ""
        let components = URLComponents(string: "usalingo://auth/recovery\(fragment)")
        guard let items = components?.queryItems,
              let accessToken = items.first(where: { $0.name == "access_token" })?.value,
              let refreshToken = items.first(where: { $0.name == "refresh_token" })?.value else {
            return nil
        }

        var request = URLRequest(url: SupabaseConfig.authURL.appendingPathComponent("user"))
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Recovery session failed")
        }
        let user = try JSONDecoder().decode(AuthUser.self, from: data)
        let recovered = AuthSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: nil, user: user)
        try sessionStore.save(recovered)
        return recovered
    }

    func reauthenticate(accessToken: String) async throws {
        try await executeAuthRequest(path: "reauthenticate", accessToken: accessToken, body: EmptyPayload())
    }

    func updatePassword(_ password: String, currentPassword: String?, nonce: String?, accessToken: String) async throws {
        try validatePassword(password)
        var body: [String: String] = ["password": password]
        if let currentPassword, !currentPassword.isEmpty { body["current_password"] = currentPassword }
        if let nonce, !nonce.isEmpty { body["nonce"] = nonce }
        try await executeAuthRequest(path: "user", method: "PUT", accessToken: accessToken, body: body)
    }

    func updateEmail(_ email: String, currentEmail: String, currentPassword: String, accessToken: String) async throws {
        guard !currentPassword.isEmpty else { throw AuthError.currentPasswordRequired }
        _ = try await authRequest(path: "token", query: [URLQueryItem(name: "grant_type", value: "password")], email: currentEmail, password: currentPassword, accessToken: accessToken)
        try await executeAuthRequest(path: "user", method: "PUT", accessToken: accessToken, body: ["email": email])
    }

    private func authRequest(path: String, query: [URLQueryItem], email: String, password: String, accessToken: String? = nil) async throws -> AuthSession {
        var components = URLComponents(url: SupabaseConfig.authURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
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
        try await client.execute(
            path: "rpc/ensure_current_user_row",
            method: .post,
            queryItems: [],
            accessToken: session.accessToken,
            body: EmptyPayload(),
            prefer: nil
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

        let (data, response) = try await session.data(for: request)
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

    private func executeAuthRequest(path: String, method: String = "POST", accessToken: String? = nil, body: Encodable) async throws {
        var request = URLRequest(url: SupabaseConfig.authURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Auth failed")
        }
    }

    private func validatePassword(_ password: String) throws {
        guard password.count >= 8 else { throw AuthError.weakPassword }
    }
}

enum AuthError: LocalizedError {
    case emailConfirmationRequired
    case sessionRestoreFailed
    case weakPassword
    case currentPasswordRequired
    case passwordsDoNotMatch

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "確認メールを開いたあと、Sign Inしてください。"
        case .sessionRestoreFailed:
            return "セッションの復元に失敗しました。もう一度Sign Inしてください。"
        case .weakPassword:
            return "パスワードは8文字以上にしてください。"
        case .currentPasswordRequired:
            return "現在のパスワードを入力してください。"
        case .passwordsDoNotMatch:
            return "新しいパスワードが一致しません。"
        }
    }
}
