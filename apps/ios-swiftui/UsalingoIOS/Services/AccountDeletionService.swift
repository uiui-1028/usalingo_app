import Foundation

struct AccountDeletionReceipt: Decodable, Equatable {
    let requestID: String
    let status: String
    let restorableUntil: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case status
        case restorableUntil = "restorable_until"
    }
}

protocol AccountDeletionServicing {
    func withdraw(
        password: String,
        confirmation: String,
        requestID: UUID,
        accessToken: String
    ) async throws -> AccountDeletionReceipt
}

private struct AccountDeletionRequest: Encodable {
    let requestID: String
    let confirmation: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case confirmation, password
    }
}

private struct AccountDeletionFailure: Decodable {
    let code: String?
}

final class AccountDeletionService: AccountDeletionServicing {
    private let session: any NetworkSession
    private let functionsURL: URL
    private let apiKey: String

    init(
        session: any NetworkSession = URLSession.shared,
        functionsURL: URL = SupabaseConfig.functionsURL,
        apiKey: String = SupabaseConfig.supabaseAnonKey
    ) {
        self.session = session
        self.functionsURL = functionsURL
        self.apiKey = apiKey
    }

    func withdraw(
        password: String,
        confirmation: String,
        requestID: UUID,
        accessToken: String
    ) async throws -> AccountDeletionReceipt {
        var request = URLRequest(
            url: functionsURL.appendingPathComponent("delete-user-account"),
            timeoutInterval: 30
        )
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AccountDeletionRequest(
                requestID: requestID.uuidString.lowercased(),
                confirmation: confirmation,
                password: password
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AccountDeletionClientError.unavailable
            }
            guard (200..<300).contains(http.statusCode) else {
                let code = try? JSONDecoder().decode(AccountDeletionFailure.self, from: data).code
                throw AccountDeletionClientError.server(code: code, status: http.statusCode)
            }
            return try JSONDecoder().decode(AccountDeletionReceipt.self, from: data)
        } catch let error as AccountDeletionClientError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw AccountDeletionClientError.timedOut
        } catch {
            throw AccountDeletionClientError.unavailable
        }
    }
}

enum AccountDeletionClientError: LocalizedError, Equatable {
    case alreadyInProgress
    case invalidConfirmation
    case timedOut
    case unavailable
    case server(code: String?, status: Int)
    case localResetFailed

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "退会手続きを処理しています。完了するまでお待ちください。"
        case .invalidConfirmation:
            return "確認欄に「退会」と入力してください。"
        case .timedOut:
            return "通信が時間切れになりました。接続を確認して、同じ画面からもう一度お試しください。"
        case .unavailable:
            return "退会手続きを開始できませんでした。時間をおいてもう一度お試しください。"
        case .server(let code, _):
            switch code {
            case "reauthentication_failed":
                return "本人確認ができませんでした。パスワードを確認してください。"
            case "withdrawal_in_progress":
                return "退会手続きを続けています。ログインは停止されています。"
            case "unauthorized":
                return "セッションの期限が切れています。もう一度Sign Inしてください。"
            default:
                return "退会手続きを完了できませんでした。安全のためセッションは保持しています。"
            }
        case .localResetFailed:
            return "退会は受け付けられましたが、端末の初期化を完了できませんでした。アプリを終了し、サポートへ連絡してください。"
        }
    }
}
