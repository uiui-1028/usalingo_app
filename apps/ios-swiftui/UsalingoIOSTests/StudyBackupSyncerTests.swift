import XCTest
@testable import UsalingoIOS

@MainActor
final class StudyBackupSyncerTests: XCTestCase {
    private var directoryURL: URL!

    private var session: AuthSession {
        AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: nil,
            user: AuthUser(id: "user-1", email: "user@example.com")
        )
    }

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyBackupSyncerTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    /// 端末に学習記録がないときは、預けてある控えを黙って書き戻す。
    func testStartRestoresWhenDeviceHasNoRecord() async throws {
        let local = makeDataSource()
        let stored = try makeBackupSnapshot(deckKey: "restored")
        let service = FakeBackupService(stored: GuestStudyBackup(snapshot: stored, deviceName: "iPhone", updatedAt: nil))
        let syncer = StudyBackupSyncer(service: service, localStudy: local, uploadDelay: .zero, deviceName: { "iPhone" })

        var didMarkChanged = false
        await syncer.start(session: session) { didMarkChanged = true }

        XCTAssertTrue(didMarkChanged)
        XCTAssertTrue(local.decks().contains { $0.key == "restored" })
        XCTAssertEqual(service.saveCount, 0)
    }

    /// 端末に学習記録があるときは、端末の内容を正として預け直す。
    func testStartUploadsWhenDeviceHasRecord() async throws {
        let local = makeDataSource()
        try await recordAnswer(on: local)
        let service = FakeBackupService(stored: GuestStudyBackup(snapshot: try makeBackupSnapshot(deckKey: "restored"), deviceName: nil, updatedAt: nil))
        let syncer = StudyBackupSyncer(service: service, localStudy: local, uploadDelay: .zero, deviceName: { "iPhone" })

        await syncer.start(session: session) { XCTFail("端末に記録があるときは書き戻さない") }

        XCTAssertEqual(service.saveCount, 1)
        XCTAssertFalse(local.decks().contains { $0.key == "restored" })
    }

    /// 通信に失敗しても、利用者に見える形では何も起きない。
    func testStartIgnoresFailure() async throws {
        let local = makeDataSource()
        let service = FakeBackupService(stored: nil, failure: URLError(.notConnectedToInternet))
        let syncer = StudyBackupSyncer(service: service, localStudy: local, uploadDelay: .zero, deviceName: { nil })

        await syncer.start(session: session) { XCTFail("失敗時は書き戻さない") }

        XCTAssertEqual(service.saveCount, 0)
    }

    /// 背面へ回るときの flush は、待たずに1回だけ預ける。
    func testFlushUploadsImmediately() async throws {
        let local = makeDataSource()
        let service = FakeBackupService(stored: nil)
        let syncer = StudyBackupSyncer(service: service, localStudy: local, uploadDelay: .seconds(60), deviceName: { "iPhone" })

        syncer.scheduleUpload(session: session)
        await syncer.flush(session: session)

        XCTAssertEqual(service.saveCount, 1)
    }

    private func makeDataSource() -> LocalStudyDataSource {
        LocalStudyDataSource(directoryURL: directoryURL, bundle: Bundle(for: Self.self))
    }

    /// 学習記録を1件だけ作る。`hasStudyRecord` を true にするためだけに使う。
    private func recordAnswer(on dataSource: LocalStudyDataSource) async throws {
        let deck = try dataSource.importDeck(from: sampleDeckData(deckKey: "device"))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)
        _ = try await dataSource.saveAnswer(card: card, isCorrect: true)
    }

    /// サーバに預けてある想定のスナップショット。別のディレクトリで組み立てる。
    private func makeBackupSnapshot(deckKey: String) throws -> LocalStudySnapshot {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyBackupSyncerTests-source-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = LocalStudyDataSource(directoryURL: directory, bundle: Bundle(for: Self.self))
        _ = try source.importDeck(from: sampleDeckData(deckKey: deckKey))
        return try source.snapshot()
    }

    private func sampleDeckData(deckKey: String) -> Data {
        let json = """
        {
            "formatVersion": 1,
            "deckId": "\(deckKey)",
            "deckName": "テストデッキ",
            "description": null,
            "cards": [
                {
                    "id": 1,
                    "text": "word-1",
                    "meaning": "意味1",
                    "partOfSpeech": null,
                    "sentenceEnglish": null,
                    "sentenceJapanese": null,
                    "imageAssetPath": null,
                    "audioAssetPath": null,
                    "tags": null
                }
            ]
        }
        """
        return Data(json.utf8)
    }
}

/// 通信をしないバックアップ置き場。保存回数だけ数える。
private final class FakeBackupService: GuestStudyBackupServicing {
    private(set) var saveCount = 0
    private var stored: GuestStudyBackup?
    private let failure: Error?

    init(stored: GuestStudyBackup?, failure: Error? = nil) {
        self.stored = stored
        self.failure = failure
    }

    func fetch(session: AuthSession) async throws -> GuestStudyBackup? {
        if let failure { throw failure }
        return stored
    }

    @discardableResult
    func save(_ snapshot: LocalStudySnapshot, deviceName: String?, session: AuthSession) async throws -> GuestStudyBackup {
        if let failure { throw failure }
        saveCount += 1
        let backup = GuestStudyBackup(snapshot: snapshot, deviceName: deviceName, updatedAt: nil)
        stored = backup
        return backup
    }

    func delete(session: AuthSession) async throws {
        stored = nil
    }
}
