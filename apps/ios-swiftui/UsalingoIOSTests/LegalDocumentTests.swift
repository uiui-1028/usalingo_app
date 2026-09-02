import XCTest
@testable import UsalingoIOS

/// 法務・ライセンス画面が「正式公開済みの文書だけ」を出すことを守るテスト。
/// ここが崩れると、草案や壊れたリンクを利用者へ見せてしまう。
final class LegalDocumentTests: XCTestCase {
    private let documents = LegalDocument.publishedDocuments

    func testPublishedDocumentsCoverTermsPrivacyAndCredits() {
        XCTAssertEqual(documents.map(\.kind), [.terms, .privacy, .credits])
    }

    /// ライセンスはアプリ内画面で出す。外部URLの行として混ぜない。
    func testLicensesIsNotAPublishedExternalDocument() {
        XCTAssertFalse(documents.contains { $0.kind == .licenses })
    }

    /// 草案や手元ファイルが正式文書として並ばないこと。
    /// 公開先のhostとhttpsを固定しておけば、file:// や localhost が混ざった時点で落ちる。
    func testEveryPublishedDocumentPointsAtTheApprovedPublicSite() throws {
        XCTAssertFalse(documents.isEmpty)

        for document in documents {
            let components = try XCTUnwrap(
                URLComponents(url: document.url, resolvingAgainstBaseURL: false),
                "URLを分解できない: \(document.url)"
            )

            XCTAssertEqual(components.scheme, "https", "\(document.title) がhttpsではない")
            XCTAssertEqual(components.host, "usalingo-app.vercel.app", "\(document.title) の公開先が違う")
            XCTAssertNil(components.query, "\(document.title) に想定外のクエリが付いている")
        }
    }

    func testPublishedDocumentsUseDistinctPaths() {
        let paths = documents.map(\.url.path)

        XCTAssertEqual(Set(paths).count, paths.count, "同じURLを複数の行が指している")
        XCTAssertEqual(paths, ["/terms", "/privacy", "/credits"])
    }

    /// 画面は「版 ・施行日 …」を出す。空文字だと区切りだけが残って意味不明になる。
    func testEveryPublishedDocumentShowsVersionAndEffectiveDate() {
        for document in documents {
            XCTAssertFalse(document.version.isEmpty, "\(document.title) の版が空")
            XCTAssertFalse(document.effectiveDate.isEmpty, "\(document.title) の施行日が空")
        }
    }

    /// `docs/legal/published/` の版・施行日と揃っていること。
    /// 文書側だけ改訂してコードを直し忘れると、ここで気づける。
    func testVersionAndEffectiveDateMatchThePublishedDocuments() {
        for document in documents {
            XCTAssertEqual(document.version, "第1.0版")
            XCTAssertEqual(document.effectiveDate, "2026年9月1日")
        }
    }

    func testEveryPublishedDocumentUsesItsKindTitle() {
        for document in documents {
            XCTAssertEqual(document.title, document.kind.title)
        }
    }

    /// 同じ種類の文書が2行並ぶと、利用者はどちらが正本か分からなくなる。
    func testPublishedDocumentsHaveNoDuplicateKinds() {
        XCTAssertEqual(Set(documents.map(\.kind)).count, documents.count)
    }

    func testKindTitlesAreFilled() {
        for kind in LegalDocument.Kind.allCases {
            XCTAssertFalse(kind.title.isEmpty, "\(kind) の見出しが空")
        }
    }
}

/// 同梱ライセンス一覧の読み込み。依存ゼロのあいだ一覧が無いのは正常な状態で、
/// そこで異常終了しないことを確かめる。
final class OpenSourceLicenseCatalogTests: XCTestCase {
    func testReturnsNilWhenTheBundleHasNoAcknowledgements() {
        let empty = Bundle(for: OpenSourceLicenseCatalogTests.self)

        XCTAssertNil(OpenSourceLicenseCatalog.load(bundle: empty))
    }

    /// アプリ本体のバンドルでも、読めても読めなくても落ちないこと。
    func testLoadingFromTheAppBundleDoesNotCrash() {
        let text = OpenSourceLicenseCatalog.load()

        if let text {
            XCTAssertFalse(text.isEmpty, "空の一覧を同梱している")
        }
    }
}
