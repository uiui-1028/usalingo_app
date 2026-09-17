import XCTest
@testable import UsalingoIOS

final class AuthConfirmationTests: XCTestCase {
    func testSignUpWithoutSessionReturnsConfirmationRequired() async throws {
        let service = AuthService(sessionStore: ConfirmationStore(), client: ConfirmationClient(), session: ConfirmationTransport(data: Data("{\"user\":{\"id\":\"learner\"}}".utf8)))

        let result = try await service.signUp(email: "learner@example.com", password: "test-password")

        guard case .confirmationRequired = result else {
            return XCTFail("Expected confirmation-required result")
        }
    }

    func testSignUpAndResendSendRedirectToAsQuery() async throws {
        let transport = ConfirmationTransport(data: Data("{\"user\":{\"id\":\"learner\"}}".utf8))
        let service = AuthService(sessionStore: ConfirmationStore(), client: ConfirmationClient(), session: transport)

        _ = try await service.signUp(email: "learner@example.com", password: "test-password")
        try await service.resendSignUpConfirmation(email: "learner@example.com")

        XCTAssertEqual(transport.requests.count, 2)
        for request in transport.requests {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query, [URLQueryItem(name: "redirect_to", value: "com.usalingo.ios://auth-callback")])
        }
    }

    func testExpiredCallbackIsReportedWithoutSendingTokens() async {
        let transport = ConfirmationTransport(data: Data())
        let service = AuthService(sessionStore: ConfirmationStore(), client: ConfirmationClient(), session: transport)

        do {
            _ = try await service.sessionFromConfirmationCallback(url: URL(string: "com.usalingo.ios://auth-callback#error_code=otp_expired")!)
            XCTFail("Expected expired link error")
        } catch AuthError.expiredConfirmationLink {
            XCTAssertTrue(transport.requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class ConfirmationTransport: NetworkSession {
    let data: Data
    private(set) var requests: [URLRequest] = []

    init(data: Data) { self.data = data }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class ConfirmationStore: SessionStoring {
    func save(_ session: AuthSession) throws {}
    func load() throws -> AuthSession? { nil }
    func clear() throws {}
}

private final class ConfirmationClient: SupabaseRequesting {
    func request<T>(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws -> T where T: Decodable { throw SupabaseError.badResponse("Unexpected request") }
    func execute(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws {}
}
