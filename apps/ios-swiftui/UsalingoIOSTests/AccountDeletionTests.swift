import XCTest
import SwiftUI
import UIKit
@testable import UsalingoIOS

final class AccountDeletionTests: XCTestCase {
    func testServiceSendsAuthenticatedRequestWithoutUserID() async throws {
        let transport = CapturingDeletionNetworkSession(
            data: Data(#"{"status":"deleted","deleted_at":"2026-09-04T00:00:00Z"}"#.utf8),
            statusCode: 200
        )
        let service = AccountDeletionService(
            session: transport,
            functionsURL: URL(string: "https://example.supabase.co/functions/v1")!,
            apiKey: "public-test-key"
        )

        let receipt = try await service.withdraw(
            password: "correct horse battery staple",
            confirmation: "退会",
            accessToken: "user-access-token"
        )

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/functions/v1/delete-user-account")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user-access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-test-key")
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object["confirmation"], "退会")
        XCTAssertNil(object["user_id"])
        XCTAssertEqual(receipt.status, "deleted")
        XCTAssertEqual(receipt.deletedAt, "2026-09-04T00:00:00Z")
    }

    @MainActor
    func testSuccessfulDeletionClearsSessionAndLocalState() async throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let sessionStore = DeletionSessionStore()
        let authService = AuthService(
            sessionStore: sessionStore,
            client: DeletionSupabaseClient(),
            session: CapturingDeletionNetworkSession(data: Data(), statusCode: 200)
        )
        let appState = AppState(
            restoresSession: false,
            defaults: defaults,
            authService: authService,
            accountDeletionService: SuccessfulDeletionService()
        )
        let session = testSession
        try sessionStore.save(session)
        appState.setSession(session)
        appState.completeSwipeTutorial()
        appState.designSettings.accentName = "orange"
        appState.designSettings.cardCornerRadius = 30

        try await appState.deleteAccount(
            password: "password123",
            confirmation: "退会",
        )

        XCTAssertNil(appState.session)
        XCTAssertNil(sessionStore.savedSession)
        XCTAssertTrue(appState.isSwipeTutorialPresented)
        XCTAssertEqual(appState.designSettings.accentName, "green")
        XCTAssertEqual(appState.designSettings.cardCornerRadius, 18)
        XCTAssertNotNil(appState.accountDeletionNotice)
    }

    @MainActor
    func testFailureAndTimeoutKeepSessionAndLocalState() async throws {
        for expectedError in [AccountDeletionClientError.unavailable, .timedOut] {
            let defaults = try makeDefaults(suffix: String(describing: expectedError))
            defer { defaults.removePersistentDomain(forName: suiteName(suffix: String(describing: expectedError))) }
            let store = DeletionSessionStore()
            let auth = AuthService(
                sessionStore: store,
                client: DeletionSupabaseClient(),
                session: CapturingDeletionNetworkSession(data: Data(), statusCode: 200)
            )
            let appState = AppState(
                restoresSession: false,
                defaults: defaults,
                authService: auth,
                accountDeletionService: FailingDeletionService(error: expectedError)
            )
            try store.save(testSession)
            appState.setSession(testSession)

            do {
                try await appState.deleteAccount(password: "password123", confirmation: "退会")
                XCTFail("Expected deletion failure")
            } catch let error as AccountDeletionClientError {
                XCTAssertEqual(error, expectedError)
            }
            XCTAssertNotNil(appState.session)
            XCTAssertNotNil(store.savedSession)
        }
    }

    @MainActor
    func testSecondTapIsRejectedWhileFirstRequestIsRunning() async throws {
        let defaults = try makeDefaults(suffix: "duplicate")
        defer { defaults.removePersistentDomain(forName: suiteName(suffix: "duplicate")) }
        let service = SlowDeletionService()
        let store = DeletionSessionStore()
        let auth = AuthService(
            sessionStore: store,
            client: DeletionSupabaseClient(),
            session: CapturingDeletionNetworkSession(data: Data(), statusCode: 200)
        )
        let appState = AppState(
            restoresSession: false,
            defaults: defaults,
            authService: auth,
            accountDeletionService: service
        )
        try store.save(testSession)
        appState.setSession(testSession)

        let first = Task {
            try await appState.deleteAccount(password: "password123", confirmation: "退会")
        }
        try await Task.sleep(nanoseconds: 20_000_000)

        do {
            try await appState.deleteAccount(password: "password123", confirmation: "退会")
            XCTFail("Expected duplicate submission rejection")
        } catch let error as AccountDeletionClientError {
            XCTAssertEqual(error, .alreadyInProgress)
        }
        _ = try await first.value
        XCTAssertEqual(service.callCount, 1)
    }

    @MainActor
    func testDeletionSheetRendersAtLargestAccessibilityTextSize() {
        let view = AccountDeletionSheet()
            .environmentObject(AppState(restoresSession: false))
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        XCTAssertEqual(image.size, window.bounds.size)
        XCTAssertNotNil(image.pngData())
        let attachment = XCTAttachment(image: image)
        attachment.name = "USL-259 account deletion accessibility text size"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var testSession: AuthSession {
        AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: nil, user: AuthUser(id: "user-1", email: "user@example.com"))
    }

    private var defaultsSuiteName: String { suiteName(suffix: "default") }
    private func suiteName(suffix: String) -> String { "AccountDeletionTests.\(name).\(suffix)" }
    private func makeDefaults(suffix: String = "default") throws -> UserDefaults {
        let name = suiteName(suffix: suffix)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private final class CapturingDeletionNetworkSession: NetworkSession {
    let data: Data
    let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private final class DeletionSessionStore: SessionStoring {
    private(set) var savedSession: AuthSession?
    func save(_ session: AuthSession) throws { savedSession = session }
    func load() throws -> AuthSession? { savedSession }
    func clear() throws { savedSession = nil }
}

private final class DeletionSupabaseClient: SupabaseRequesting {
    func request<T: Decodable>(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws -> T {
        throw SupabaseError.badResponse("Unexpected request")
    }
    func execute(path: String, method: HTTPMethod, queryItems: [URLQueryItem], accessToken: String?, body: Encodable?, prefer: String?) async throws {}
}

private struct SuccessfulDeletionService: AccountDeletionServicing {
    func withdraw(password: String, confirmation: String, accessToken: String) async throws -> AccountDeletionReceipt {
        AccountDeletionReceipt(status: "deleted", deletedAt: "2026-09-04T00:00:00Z")
    }
}

private struct FailingDeletionService: AccountDeletionServicing {
    let error: AccountDeletionClientError
    func withdraw(password: String, confirmation: String, accessToken: String) async throws -> AccountDeletionReceipt {
        throw error
    }
}

private final class SlowDeletionService: AccountDeletionServicing {
    private(set) var callCount = 0
    func withdraw(password: String, confirmation: String, accessToken: String) async throws -> AccountDeletionReceipt {
        callCount += 1
        try await Task.sleep(nanoseconds: 100_000_000)
        return AccountDeletionReceipt(status: "deleted", deletedAt: "2026-09-04T00:00:00Z")
    }
}
