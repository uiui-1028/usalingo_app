import XCTest
@testable import UsalingoIOS

/// 画面へ出す文言が日本語で、内部エラー文字列を含まないことを守る。
final class UserFacingErrorTests: XCTestCase {
    /// アプリが日本語で説明済みのエラーは、その文言をそのまま使う。
    func testAppErrorsKeepTheirJapaneseMessage() {
        XCTAssertEqual(
            UserFacingError.message(for: AuthError.weakPassword),
            AuthError.weakPassword.localizedDescription
        )
        XCTAssertEqual(
            UserFacingError.message(for: LocalStudyError.deckNotFound),
            "デッキが見つかりませんでした。"
        )
        XCTAssertEqual(
            UserFacingError.message(for: DeckFileError.emptyDeckId),
            "deckId が空です。"
        )
        XCTAssertEqual(
            UserFacingError.message(for: AccountDeletionClientError.invalidConfirmation),
            "確認欄に「退会」と入力してください。"
        )
    }

    /// サーバーが返した生の本文を画面へ出さない。ここが今回の本題。
    func testServerResponseBodyIsNeverShown() {
        let raw = #"{"error":"invalid_grant","error_description":"Invalid login credentials"}"#
        let message = UserFacingError.message(for: SupabaseError.badResponse(raw))

        XCTAssertFalse(message.contains("invalid_grant"))
        XCTAssertFalse(message.contains("Invalid login credentials"))
        XCTAssertFalse(message.contains("{"))
        XCTAssertEqual(message, "サーバーとやり取りできませんでした。時間をおいて、もう一度お試しください。")
    }

    /// Keychainの数値コードを画面へ出さない。
    func testKeychainStatusCodeIsNeverShown() {
        let message = UserFacingError.message(for: KeychainError.unhandled(-25300))

        XCTAssertFalse(message.contains("-25300"))
        XCTAssertFalse(message.lowercased().contains("keychain"))
    }

    /// 通信の失敗は、原因ごとに次の行動が変わる。
    func testNetworkFailuresExplainWhatToDoNext() {
        XCTAssertEqual(
            UserFacingError.message(for: URLError(.notConnectedToInternet)),
            "インターネットにつながっていません。接続を確認して、もう一度お試しください。"
        )
        XCTAssertEqual(
            UserFacingError.message(for: URLError(.timedOut)),
            "通信が時間切れになりました。接続を確認して、もう一度お試しください。"
        )
        XCTAssertNotEqual(
            UserFacingError.message(for: URLError(.notConnectedToInternet)),
            UserFacingError.message(for: URLError(.timedOut))
        )
    }

    /// 画面側が「〜できませんでした。」と先に言う場合、失敗の宣言を重ねない。
    func testAdviceDoesNotRepeatTheFailureStatement() {
        struct SomethingWeird: Error {}

        let advice = UserFacingError.advice(for: SomethingWeird())
        XCTAssertEqual(advice, "時間をおいて、もう一度お試しください。")
        XCTAssertFalse(advice.contains("うまくいきませんでした"))

        // 画面側の前置きと連結しても、二重の「〜できませんでした。」にならない。
        let shown = "デッキを書き出せませんでした。\(advice)"
        XCTAssertEqual(shown, "デッキを書き出せませんでした。時間をおいて、もう一度お試しください。")
    }

    /// 原因を説明できる場合は、message と advice が同じ説明を返す。
    func testAdviceKeepsTheCauseWhenItIsKnown() {
        let error = URLError(.notConnectedToInternet)

        XCTAssertEqual(
            UserFacingError.advice(for: error),
            UserFacingError.message(for: error)
        )
        XCTAssertEqual(
            UserFacingError.advice(for: SupabaseError.badResponse("Profile save failed")),
            "サーバーとやり取りできませんでした。時間をおいて、もう一度お試しください。"
        )
    }

    /// 想定していないエラーでも、英語や型名を見せずに日本語で終わる。
    func testUnknownErrorsFallBackToJapanese() {
        struct SomethingWeird: Error {}

        let message = UserFacingError.message(for: SomethingWeird())

        XCTAssertFalse(message.contains("SomethingWeird"))
        XCTAssertEqual(message, "うまくいきませんでした。時間をおいて、もう一度お試しください。")
    }

    /// どの経路でも、画面文言は日本語で終わり、次の行動が書いてある。
    func testEveryMessageIsJapaneseAndActionable() {
        let errors: [Error] = [
            AuthError.sessionRestoreFailed,
            LocalStudyError.snapshotUnreadable,
            DeckFileError.unreadable,
            AccountDeletionClientError.timedOut,
            SupabaseError.badResponse("Profile save failed"),
            KeychainError.unhandled(-25300),
            URLError(.networkConnectionLost),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad json"))
        ]

        for error in errors {
            let message = UserFacingError.message(for: error)

            XCTAssertTrue(message.hasSuffix("。"), "日本語の文で終わっていない: \(message)")
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(
                message.range(of: "\\p{Hiragana}|\\p{Katakana}|\\p{Han}", options: .regularExpression) != nil,
                "日本語が含まれていない: \(message)"
            )
            XCTAssertFalse(message.contains("bad json"), "内部の詳細が漏れている: \(message)")
        }
    }
}
