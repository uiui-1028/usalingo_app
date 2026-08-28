import XCTest
@testable import UsalingoIOS

final class GuestStudyBackupServiceTests: XCTestCase {
    private var session: AuthSession {
        AuthSession(accessToken: "access", refreshToken: "refresh", expiresAt: nil, user: AuthUser(id: "user-1", email: "user@example.com"))
    }

    func testSaveThenFetchRoundTripsSnapshot() async throws {
        let client = InMemoryBackupSupabaseClient()
        let service = GuestStudyBackupService(client: client)
        let snapshot = try makeSnapshot()

        let saved = try await service.save(snapshot, deviceName: "iPhone", session: session)
        XCTAssertEqual(saved.deviceName, "iPhone")
        XCTAssertEqual(saved.snapshot.schemaVersion, snapshot.schemaVersion)

        let fetched = try await service.fetch(session: session)
        let unwrapped = try XCTUnwrap(fetched)
        XCTAssertEqual(unwrapped.deviceName, "iPhone")
        XCTAssertEqual(unwrapped.snapshot.library.decks.map(\.key), snapshot.library.decks.map(\.key))
        XCTAssertEqual(unwrapped.snapshot.progress.count, snapshot.progress.count)
    }

    func testSecondSaveReplacesFirst() async throws {
        let client = InMemoryBackupSupabaseClient()
        let service = GuestStudyBackupService(client: client)

        _ = try await service.save(try makeSnapshot(deckKey: "first"), deviceName: "iPhone", session: session)
        _ = try await service.save(try makeSnapshot(deckKey: "second"), deviceName: "iPad", session: session)

        let fetched = try await service.fetch(session: session)
        let unwrapped = try XCTUnwrap(fetched)
        // 1ユーザー1件。あとから保存した内容だけが残る（G-D2）。
        XCTAssertEqual(unwrapped.deviceName, "iPad")
        XCTAssertEqual(unwrapped.snapshot.library.decks.map(\.key), ["second"])
        XCTAssertEqual(client.savedRowCount, 1)
    }

    func testFetchReturnsNilWhenNothingSaved() async throws {
        let client = InMemoryBackupSupabaseClient()
        let service = GuestStudyBackupService(client: client)

        let fetched = try await service.fetch(session: session)
        XCTAssertNil(fetched)
    }

    func testDeleteRemovesBackup() async throws {
        let client = InMemoryBackupSupabaseClient()
        let service = GuestStudyBackupService(client: client)
        _ = try await service.save(try makeSnapshot(), deviceName: nil, session: session)

        try await service.delete(session: session)

        let fetched = try await service.fetch(session: session)
        XCTAssertNil(fetched)
    }

    private func makeSnapshot(deckKey: String = "sample") throws -> LocalStudySnapshot {
        let deck = LocalDeck(id: 1, key: deckKey, name: "テストデッキ", description: nil, isBundled: false)
        let progress = LearningProgress.initial(userId: "guest", cardId: 1)
        return LocalStudySnapshot(
            schemaVersion: LocalStudySnapshot.currentSchemaVersion,
            library: LocalStudyLibrary(decks: [deck], removedBundledKeys: [], nextDeckId: 2, nextCardId: 2, cardIds: ["\(deckKey)#1": 1]),
            progress: ["1": progress],
            tags: [:],
            overrides: [:],
            importedDecks: [:],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

/// user_id を主キーとする実サーバの `on_conflict=user_id` upsert を
/// メモリ上で再現する fake。実際の往復（JSONエンコード→デコード）を確かめるため、
/// 生の Data を経由させる。
private final class InMemoryBackupSupabaseClient: SupabaseRequesting {
    private var rowsByUserId: [String: Data] = [:]

    var savedRowCount: Int { rowsByUserId.count }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws -> T {
        switch method {
        case .get:
            guard let userId = userId(from: queryItems), let data = rowsByUserId[userId] else {
                let empty = try JSONSerialization.data(withJSONObject: [Any]())
                return try JSONDecoder().decode(T.self, from: empty)
            }
            let arrayData = try wrapAsArray(data)
            return try JSONDecoder().decode(T.self, from: arrayData)
        case .post:
            guard let body else { throw SupabaseError.badResponse("Missing body") }
            let data = try JSONEncoder().encode(AnyEncodable(body))
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let userId = object["user_id"] as? String else {
                throw SupabaseError.badResponse("Missing user_id")
            }
            rowsByUserId[userId] = data
            let arrayData = try wrapAsArray(data)
            return try JSONDecoder().decode(T.self, from: arrayData)
        case .delete:
            throw SupabaseError.badResponse("Unexpected delete via request")
        }
    }

    func execute(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws {
        guard method == .delete, let userId = userId(from: queryItems) else {
            throw SupabaseError.badResponse("Unexpected execute call")
        }
        rowsByUserId.removeValue(forKey: userId)
    }

    private func userId(from queryItems: [URLQueryItem]) -> String? {
        queryItems.first { $0.name == "user_id" }?.value?.replacingOccurrences(of: "eq.", with: "")
    }

    private func wrapAsArray(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        let arrayData = try JSONSerialization.data(withJSONObject: [object])
        return arrayData
    }
}

private struct AnyEncodable: Encodable {
    private let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
