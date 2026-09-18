import XCTest
@testable import UsalingoIOS

/// 利用者のうっかりした打ち方を、送る前にどこまで許すかを守る。
final class EmailInputTests: XCTestCase {
    func testTrailingAndLeadingWhitespaceIsRemoved() throws {
        XCTAssertEqual(try EmailInput.validated("sample@gmail.com "), "sample@gmail.com")
        XCTAssertEqual(try EmailInput.validated("  sample@gmail.com\n"), "sample@gmail.com")
        XCTAssertEqual(try EmailInput.validated("sample@gmail.com\u{3000}"), "sample@gmail.com")
        XCTAssertEqual(try EmailInput.validated("\u{200B}sample@gmail.com"), "sample@gmail.com")
    }

    func testFullWidthCharactersBecomeHalfWidth() throws {
        XCTAssertEqual(try EmailInput.validated("ｓａｍｐｌｅ＠ｇｍａｉｌ．ｃｏｍ"), "sample@gmail.com")
        XCTAssertEqual(try EmailInput.validated("sample@gmail。com"), "sample@gmail.com")
    }

    func testUppercaseIsLowered() throws {
        XCTAssertEqual(try EmailInput.validated("Sample@Gmail.COM"), "sample@gmail.com")
    }

    func testProblemsThatCannotBeGuessedAreReported() {
        assertThrows("   ", AuthError.emailRequired)
        assertThrows("sample @gmail.com", AuthError.emailContainsSpace)
        assertThrows("sample.gmail.com", AuthError.emailInvalidFormat)
        assertThrows("a@b@gmail.com", AuthError.emailInvalidFormat)
        assertThrows("@gmail.com", AuthError.emailInvalidFormat)
        assertThrows("sample@gmail", AuthError.emailInvalidFormat)
        assertThrows("sample@gmail..com", AuthError.emailInvalidFormat)
    }

    func testCommonDomainTyposAreSuggestedNotFixed() {
        XCTAssertEqual(EmailInput.suggestion(for: "sample@gmail.con"), "sample@gmail.com")
        XCTAssertEqual(EmailInput.suggestion(for: "sample@gmial.com"), "sample@gmail.com")
        XCTAssertEqual(EmailInput.suggestion(for: "Sample@yahoo.co.jo "), "sample@yahoo.co.jp")
        XCTAssertEqual(EmailInput.suggestion(for: "sample@docomo.ne.pj"), "sample@docomo.ne.jp")
        // 正しいドメインや、よく知らないドメインには何も言わない。
        XCTAssertNil(EmailInput.suggestion(for: "sample@gmail.com"))
        XCTAssertNil(EmailInput.suggestion(for: "sample@me.com"))
        XCTAssertNil(EmailInput.suggestion(for: "sample@example.org"))
        XCTAssertNil(EmailInput.suggestion(for: "sample"))
        XCTAssertNil(EmailInput.suggestion(for: "sample@"))
        // 1文字違いでも、実在するよく使われるドメインは候補を出さない。
        XCTAssertNil(EmailInput.suggestion(for: "sample@mail.com"))
        // 短いドメインは2文字違いを別物とみなす。
        XCTAssertNil(EmailInput.suggestion(for: "sample@xy.com"))
    }

    func testServerReasonsAreExplainedInJapanese() {
        XCTAssertEqual(
            AuthError.fromServer(body: #"{"error":"invalid_grant","error_description":"Invalid login credentials"}"#, statusCode: 400),
            .invalidCredentials
        )
        XCTAssertEqual(
            AuthError.fromServer(body: #"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#, statusCode: 400),
            .invalidCredentials
        )
        XCTAssertEqual(AuthError.fromServer(body: #"{"error_code":"email_not_confirmed"}"#, statusCode: 400), .emailConfirmationRequired)
        XCTAssertEqual(AuthError.fromServer(body: #"{"error_code":"user_already_exists"}"#, statusCode: 422), .emailInUse)
        XCTAssertEqual(AuthError.fromServer(body: #"{"error_code":"email_address_invalid"}"#, statusCode: 400), .emailInvalidFormat)
        XCTAssertEqual(AuthError.fromServer(body: #"{"error_code":"over_email_send_rate_limit"}"#, statusCode: 429), .emailSendRateLimited)
        XCTAssertEqual(AuthError.fromServer(body: "", statusCode: 429), .tooManyRequests)
        // 期限切れのトークンなど、説明できないものは拾わない。
        XCTAssertNil(AuthError.fromServer(body: #"{"error":"invalid_grant","error_description":"Invalid Refresh Token"}"#, statusCode: 400))
    }

    private func assertThrows(_ raw: String, _ expected: AuthError, line: UInt = #line) {
        XCTAssertThrowsError(try EmailInput.validated(raw), line: line) { error in
            XCTAssertEqual(error as? AuthError, expected, line: line)
        }
    }
}
