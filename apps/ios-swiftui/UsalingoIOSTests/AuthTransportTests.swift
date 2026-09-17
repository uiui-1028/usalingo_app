import XCTest
@testable import UsalingoIOS

final class AuthTransportTests: XCTestCase {
    func testRestoreSessionKeepsSavedSessionWhenNetworkIsUnavailable() async {
        let saved = AuthSession(
            accessToken: "saved-access",
            refreshToken: "saved-refresh",
            expiresAt: 123,
            user: AuthUser(id: "user-1", email: "learner@example.com")
        )
        let store = FakeSessionStore(savedSession: saved)
        let service = AuthService(
            sessionStore: store,
            client: FakeAuthSupabaseClient(),
            session: OfflineNetworkSession()
        )

        do {
            _ = try await service.restoreSession()
            XCTFail("Expected offline refresh to fail")
        } catch is URLError {
            XCTAssertEqual(store.savedSession?.accessToken, saved.accessToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRestoreSessionClearsSavedSessionWhenServerRejectsRefresh() async {
        let store = FakeSessionStore(savedSession: AuthSession(
            accessToken: "expired-access",
            refreshToken: "invalid-refresh",
            expiresAt: 123,
            user: AuthUser(id: "user-1", email: "learner@example.com")
        ))
        let service = AuthService(
            sessionStore: store,
            client: FakeAuthSupabaseClient(),
            session: StubNetworkSession(data: Data(), statusCode: 401)
        )

        do {
            _ = try await service.restoreSession()
            XCTFail("Expected rejected refresh to fail")
        } catch is SupabaseError {
            XCTAssertNil(store.savedSession)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignInSucceedsWithoutNetworkAndSavesSession() async throws {
        let transport = StubNetworkSession(
            data: Data("""
            {"access_token":"test-access","refresh_token":"test-refresh","expires_at":123,"user":{"id":"user-1","email":"learner@example.com"}}
            """.utf8),
            statusCode: 200
        )
        let store = FakeSessionStore()
        let client = FakeAuthSupabaseClient()
        let service = AuthService(sessionStore: store, client: client, session: transport)

        let result = try await service.signIn(email: "learner@example.com", password: "not-a-secret")

        XCTAssertEqual(result.user.id, "user-1")
        XCTAssertEqual(store.savedSession?.accessToken, "test-access")
        XCTAssertEqual(client.executedPaths, ["rpc/ensure_current_user_row"])
        XCTAssertEqual(transport.requests.first?.url?.query, "grant_type=password")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
    }

    func testSignInTreatsMissingSessionAsEmailConfirmationRequired() async {
        let service = AuthService(
            sessionStore: FakeSessionStore(),
            client: FakeAuthSupabaseClient(),
            session: StubNetworkSession(data: Data("{}".utf8), statusCode: 200)
        )

        do {
            _ = try await service.signIn(email: "learner@example.com", password: "not-a-secret")
            XCTFail("Expected email confirmation error")
        } catch AuthError.emailConfirmationRequired {
            // Expected: Supabase accepts sign-up before email verification returns a session.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testReauthenticateUsesSupabaseGetEndpoint() async throws {
        let transport = StubNetworkSession(data: Data("{}".utf8), statusCode: 200)
        let service = AuthService(
            sessionStore: FakeSessionStore(),
            client: FakeAuthSupabaseClient(),
            session: transport
        )

        try await service.reauthenticate(accessToken: "test-access")

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.url?.path, "/auth/v1/reauthenticate")
        XCTAssertEqual(transport.requests.first?.httpMethod, "GET")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
    }

    func testPasswordRecoverySendsAppRedirectAsQueryItem() async throws {
        let transport = StubNetworkSession(data: Data("{}".utf8), statusCode: 200)
        let service = AuthService(
            sessionStore: FakeSessionStore(),
            client: FakeAuthSupabaseClient(),
            session: transport
        )

        try await service.requestPasswordRecovery(email: "learner@example.com")

        let request = try XCTUnwrap(transport.requests.first)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "redirect_to", value: "usalingo://auth/recovery")])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String],
            ["email": "learner@example.com"]
        )
    }

    func testSupabaseClientReportsUnauthorizedResponseWithoutNetwork() async {
        let client = SupabaseClient(session: StubNetworkSession(data: Data("expired token".utf8), statusCode: 401))

        do {
            let _: [String] = try await client.request(path: "user_card_progress", accessToken: "expired-token")
            XCTFail("Expected unauthorized response")
        } catch let SupabaseError.badResponse(message) {
            XCTAssertEqual(message, "expired token")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnswerRetryReusesExactProgressAfterLostResponse() async throws {
        let client = LostAnswerResponseClient()
        let session = AuthSession(accessToken: "test", refreshToken: nil, expiresAt: nil, user: AuthUser(id: "user-1", email: nil))
        let source: any StudyDataSource = RemoteStudyDataSource(service: StudyService(client: client), session: session)
        let card = WordCard(id: 1, cardId: 7, text: "word", meaning: "意味", partOfSpeech: nil,
                            sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                            audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        let attempt = AnswerSaveAttempt()
        do {
            _ = try await source.saveAnswerWithUndo(card: card, isCorrect: false, attempt: attempt)
            XCTFail("Expected lost response")
        } catch is URLError {}
        let saved = try await source.saveAnswerWithUndo(card: card, isCorrect: false, attempt: attempt)
        XCTAssertEqual(saved.progress.incorrectCount, 1)
        XCTAssertNil(saved.previousProgress)
        XCTAssertEqual(client.readCount, 1)
        XCTAssertEqual(client.writes.count, 2)
        XCTAssertEqual(client.writes.first, client.writes.last)
        try await source.restoreLearningProgress(cardId: 7, previousProgress: saved.previousProgress)
        XCTAssertNil(client.stored)
    }

    func testStudyServicePropagatesMalformedOrUnauthorizedResponseWithoutNetwork() async {
        let service = StudyService(client: FailingStudySupabaseClient())
        let session = AuthSession(accessToken: "expired-token", refreshToken: nil, expiresAt: nil, user: AuthUser(id: "user-1", email: nil))

        do {
            _ = try await service.fetchStudyStats(session: session)
            XCTFail("Expected study request failure")
        } catch let SupabaseError.badResponse(message) {
            XCTAssertEqual(message, "Unauthorized")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class LostAnswerResponseClient: SupabaseRequesting {
    var stored: LearningProgress?
    var writes: [Data] = []
    var readCount = 0

    func request<T: Decodable>(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws -> T {
        if let progress = body as? LearningProgress {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            writes.append(try encoder.encode(progress))
            stored = progress
            if writes.count == 1 { throw URLError(.networkConnectionLost) }
        } else {
            readCount += 1
        }
        return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(stored.map { [$0] } ?? []))
    }

    func execute(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws {
        stored = nil
    }
}

private final class StubNetworkSession: NetworkSession {
    private let data: Data
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let url = request.url ?? URL(string: "https://example.invalid")!
        return (data, HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private final class OfflineNetworkSession: NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

private final class FakeSessionStore: SessionStoring {
    private(set) var savedSession: AuthSession?

    init(savedSession: AuthSession? = nil) {
        self.savedSession = savedSession
    }

    func save(_ session: AuthSession) throws { savedSession = session }
    func load() throws -> AuthSession? { savedSession }
    func clear() throws { savedSession = nil }
}

private final class FakeAuthSupabaseClient: SupabaseRequesting {
    private(set) var executedPaths: [String] = []

    func request<T: Decodable>(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws -> T {
        throw SupabaseError.badResponse("Unexpected auth test request")
    }

    func execute(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws {
        executedPaths.append(path)
    }
}

private final class FailingStudySupabaseClient: SupabaseRequesting {
    func request<T: Decodable>(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws -> T {
        throw SupabaseError.badResponse("Unauthorized")
    }

    func execute(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws {
        throw SupabaseError.badResponse("Unauthorized")
    }
}
