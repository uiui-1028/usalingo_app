import Nuke
import XCTest
@testable import UsalingoIOS

final class CardImageCacheTests: XCTestCase {
    func testUsesBoundedDiskCache() {
        XCTAssertEqual(CardImageCache.diskCacheSizeLimit, 200 * 1024 * 1024)
    }

    func testRemovingCacheIsSafeWhenNoImagesHaveBeenLoaded() {
        CardImageCache.removeAll()
    }

    func testAudioCacheUsesBoundedDiskCache() {
        XCTAssertEqual(CardAudioCache.diskCacheSizeLimit, 100 * 1024 * 1024)
    }

    func testSecondAudioRequestIsServedWithoutNetwork() async throws {
        let storage = try makeAudioStorage()
        let counter = LoadCounter()
        let cache = CardAudioCache(storage: storage) { _ in
            await counter.increment()
            return Data("mp3".utf8)
        }
        let url = URL(string: "https://example.com/content-audio/word/000001.mp3")!

        let first = try await cache.data(for: url)
        let second = try await cache.data(for: url)

        XCTAssertEqual(first, Data("mp3".utf8))
        XCTAssertEqual(second, first)
        let loadCount = await counter.value
        XCTAssertEqual(loadCount, 1)
    }

    /// 次に起動したときも、通信できない状態で保存済みの音声を鳴らせる。
    func testSavedAudioIsAvailableOfflineAfterRelaunch() async throws {
        let storage = try makeAudioStorage()
        let url = URL(string: "https://example.com/content-audio/example/000001.mp3")!
        let online = CardAudioCache(storage: storage) { _ in Data("saved".utf8) }
        _ = try await online.data(for: url)
        storage.flush()

        let relaunchedStorage = try DataCache(path: storage.path)
        let offline = CardAudioCache(storage: relaunchedStorage) { _ in
            throw URLError(.notConnectedToInternet)
        }

        let data = try await offline.data(for: url)
        XCTAssertEqual(data, Data("saved".utf8))
    }

    func testFailedAudioDownloadIsNotSaved() async throws {
        let storage = try makeAudioStorage()
        let url = URL(string: "https://example.com/content-audio/word/000002.mp3")!
        let failing = CardAudioCache(storage: storage) { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await failing.data(for: url)
            XCTFail("取得に失敗した音声を返してはいけない")
        } catch {}

        storage.flush()
        XCTAssertFalse(storage.containsData(for: url.absoluteString))
    }

    func testRemovingAudioCacheForcesDownloadAgain() async throws {
        let storage = try makeAudioStorage()
        let counter = LoadCounter()
        let cache = CardAudioCache(storage: storage) { _ in
            await counter.increment()
            return Data("mp3".utf8)
        }
        let url = URL(string: "https://example.com/content-audio/word/000003.mp3")!

        _ = try await cache.data(for: url)
        await cache.removeAll()
        _ = try await cache.data(for: url)

        let loadCount = await counter.value
        XCTAssertEqual(loadCount, 2)
    }

    private func makeAudioStorage() throws -> DataCache {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("usalingo-audio-cache-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try DataCache(path: directory)
    }
}

private actor LoadCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
