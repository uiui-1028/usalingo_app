import XCTest
@testable import UsalingoIOS

final class AuthTransportTests: XCTestCase {
    @MainActor
    func testFirstOfflineAnswerSurvivesAnonymousSignIn() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineGuestHandoff-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = LocalStudyDataSource(directoryURL: directory, bundle: .main)
        try local.beginGuestHandoffIfPristine()
        let network = RecoveringAnonymousNetworkSession()
        let store = FakeSessionStore()
        let state = AppState(
            restoresSession: false,
            authService: AuthService(sessionStore: store, client: FakeAuthSupabaseClient(), session: network),
            remoteStudy: OfflineRemoteStudyImporter(),
            localStudy: local
        )
        await state.retryStartup()
        XCTAssertNil(state.session)

        let decks = try await state.studyDataSource.fetchDecks()
        let deck = try XCTUnwrap(decks.first)
        let cards = try await state.studyDataSource.fetchCards(deckId: deck.id)
        let card = try XCTUnwrap(cards.first)
        _ = try await state.studyDataSource.saveAnswer(card: card, isCorrect: true)
        network.isOnline = true
        await state.retryStartup()

        XCTAssertEqual(state.session?.user.id, "new-anonymous-account")
        let afterConnection = try await state.studyDataSource.fetchCards(deckId: deck.id)
        XCTAssertEqual(afterConnection.first?.learning?.repetitions, 1)
        XCTAssertFalse(local.hasPendingGuestHandoff)
    }

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

    // MARK: - メールアドレスの入力を整える

    func testSignInSendsTheCleanedAddressAndExplainsWrongPassword() async {
        let transport = StubNetworkSession(
            data: Data(#"{"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#.utf8),
            statusCode: 400
        )
        let service = AuthService(sessionStore: FakeSessionStore(), client: FakeAuthSupabaseClient(), session: transport)

        do {
            _ = try await service.signIn(email: "Sample@Gmail.com ", password: " pass word ")
            XCTFail("Expected wrong password to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }

        let body = try? JSONSerialization.jsonObject(with: transport.requests.first?.httpBody ?? Data()) as? [String: String]
        XCTAssertEqual(body?["email"], "sample@gmail.com")
        // パスワードの空白は削らない。
        XCTAssertEqual(body?["password"], " pass word ")
    }

    func testInvalidAddressIsRejectedBeforeAnyRequest() async {
        let transport = StubNetworkSession(data: Data(), statusCode: 200)
        let service = AuthService(sessionStore: FakeSessionStore(), client: FakeAuthSupabaseClient(), session: transport)

        do {
            try await service.requestPasswordRecovery(email: "sample @gmail.com")
            XCTFail("Expected invalid address to fail")
        } catch {
            XCTAssertEqual(error as? AuthError, .emailContainsSpace)
        }
        XCTAssertTrue(transport.requests.isEmpty)
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

private final class RecoveringAnonymousNetworkSession: NetworkSession {
    var isOnline = false

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard isOnline else { throw URLError(.notConnectedToInternet) }
        let data = Data("""
        {"access_token":"test","refresh_token":"refresh","user":{"id":"new-anonymous-account","email":null,"is_anonymous":true}}
        """.utf8)
        let url = request.url ?? URL(string: "https://example.invalid")!
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class OfflineRemoteStudyImporter: RemoteStudyImporting {
    func fetchDecks(session: AuthSession) async throws -> [Deck] { throw URLError(.notConnectedToInternet) }
    func fetchCards(deckId: Int, session: AuthSession) async throws -> [WordCard] { throw URLError(.notConnectedToInternet) }
    func fetchAllLearningProgress(session: AuthSession) async throws -> [LearningProgress] { throw URLError(.notConnectedToInternet) }
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
