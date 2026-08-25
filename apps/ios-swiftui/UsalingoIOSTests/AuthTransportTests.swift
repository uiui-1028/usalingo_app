import XCTest
@testable import UsalingoIOS

final class AuthTransportTests: XCTestCase {
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

private final class FakeSessionStore: SessionStoring {
    private(set) var savedSession: AuthSession?

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
