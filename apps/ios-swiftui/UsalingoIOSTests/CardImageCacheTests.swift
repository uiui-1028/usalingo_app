import XCTest
@testable import UsalingoIOS

final class CardImageCacheTests: XCTestCase {
    func testUsesBoundedDiskCache() {
        XCTAssertEqual(CardImageCache.diskCacheSizeLimit, 200 * 1024 * 1024)
    }

    func testRemovingCacheIsSafeWhenNoImagesHaveBeenLoaded() {
        CardImageCache.removeAll()
    }
}
