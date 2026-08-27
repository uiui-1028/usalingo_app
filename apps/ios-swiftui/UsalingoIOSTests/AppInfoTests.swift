import XCTest
@testable import UsalingoIOS

final class AppInfoTests: XCTestCase {
    private let environment = AppInfo.Environment(
        shortVersion: "1.2.3",
        buildNumber: "45",
        systemName: "iOS",
        systemVersion: "17.4",
        deviceModel: "iPhone16,1"
    )

    func testVersionLabelShowsMarketingVersionAndBuild() {
        XCTAssertEqual(AppInfo.versionLabel(environment), "バージョン 1.2.3 (45)")
    }

    func testContactBodyCarriesVersionOSAndModel() {
        let body = AppInfo.contactBody(environment)

        XCTAssertTrue(body.contains("アプリ版: 1.2.3 (45)"))
        XCTAssertTrue(body.contains("OS: iOS 17.4"))
        XCTAssertTrue(body.contains("機種: iPhone16,1"))
    }

    func testContactMailURLTargetsSupportAddress() throws {
        let url = try XCTUnwrap(AppInfo.contactMailURL(environment))

        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertEqual(url.path, AppInfo.supportEmail)
    }

    /// 全角文字と改行が入っても URL が壊れないこと。手で組み立てると必ずここで壊れる。
    func testContactMailURLEncodesSubjectAndBody() throws {
        let url = try XCTUnwrap(AppInfo.contactMailURL(environment))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)

        let subject = try XCTUnwrap(items.first { $0.name == "subject" }?.value)
        let body = try XCTUnwrap(items.first { $0.name == "body" }?.value)

        XCTAssertEqual(subject, AppInfo.contactSubject(environment))
        XCTAssertEqual(body, AppInfo.contactBody(environment))

        let raw = url.absoluteString
        XCTAssertFalse(raw.contains("\n"), "改行が生のまま URL へ入っている")
        XCTAssertFalse(raw.contains(" "), "空白が生のまま URL へ入っている")
    }

    /// 差出人が本文を消して送っても届くよう、宛先は本文に依存しない。
    func testContactMailURLKeepsRecipientWhenBodyIsEmpty() throws {
        let empty = AppInfo.Environment(
            shortVersion: "",
            buildNumber: "",
            systemName: "",
            systemVersion: "",
            deviceModel: ""
        )
        let url = try XCTUnwrap(AppInfo.contactMailURL(empty))

        XCTAssertEqual(url.path, AppInfo.supportEmail)
    }
}
