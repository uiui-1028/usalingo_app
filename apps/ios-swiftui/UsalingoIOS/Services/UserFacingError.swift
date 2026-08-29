import Foundation

/// 画面へ出すエラー文言を1か所へ集める。
///
/// これまでは各画面が `error.localizedDescription` をそのまま表示していたため、
/// サーバーが返した英語のJSONや `Keychain error: -25300` のような内部文字列が
/// 利用者へ見えていた。ここで「何が起きたか」と「次にどうすればよいか」を
/// 日本語で言い切り、原因の詳細は画面へ出さない。
///
/// 入口は2つある。
/// - `message(for:)`: 画面側が何も言わない場合。失敗したことも含めて全部言う。
/// - `advice(for:)`: 画面側が「〜できませんでした。」と先に言う場合。
///   原因と次の行動だけを返し、「〜できませんでした。」を重ねない。
///
/// アプリ自身が日本語で説明できるエラー型（`AuthError` など）は、その文言を
/// そのまま使う。型を明示して分岐しているのは、日本語かどうかを推測せず、
/// 新しいエラー型を足したときに「定型文へ落ちる」ことを気づけるようにするため。
enum UserFacingError {
    /// 画面側が前置きを持たない場合の文言。
    static func message(for error: Error) -> String {
        known(error) ?? "うまくいきませんでした。\(retryAdvice)"
    }

    /// 画面側が「〜できませんでした。」と先に言う場合に続ける文言。
    static func advice(for error: Error) -> String {
        known(error) ?? retryAdvice
    }

    private static let retryAdvice = "時間をおいて、もう一度お試しください。"

    /// 原因を説明できるものだけを返す。説明できない場合は nil。
    private static func known(_ error: Error) -> String? {
        switch error {
        // アプリが日本語で説明済みのもの。
        case let error as AuthError:
            return error.localizedDescription
        case let error as DeckFileError:
            return error.localizedDescription
        case let error as LocalStudyError:
            return error.localizedDescription
        case let error as AccountDeletionClientError:
            return error.localizedDescription

        // 内部文字列を持つもの。中身は出さない。
        case is SupabaseError:
            return "サーバーとやり取りできませんでした。\(retryAdvice)"
        case is KeychainError:
            return "この端末へ安全に保存できませんでした。アプリを開き直して、もう一度お試しください。"
        case is DecodingError:
            return "受け取ったデータの形式が想定と違いました。アプリを更新してから、もう一度お試しください。"

        case let error as URLError:
            return networkMessage(for: error)

        default:
            return nil
        }
    }

    private static func networkMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .dataNotAllowed:
            return "インターネットにつながっていません。接続を確認して、もう一度お試しください。"
        case .timedOut:
            return "通信が時間切れになりました。接続を確認して、もう一度お試しください。"
        case .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "通信が途中で切れました。接続を確認して、もう一度お試しください。"
        case .cancelled:
            return "通信を取り消しました。もう一度お試しください。"
        default:
            return "通信できませんでした。接続を確認して、もう一度お試しください。"
        }
    }
}
