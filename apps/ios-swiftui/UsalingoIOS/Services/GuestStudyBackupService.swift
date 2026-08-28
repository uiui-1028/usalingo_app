import Foundation

/// サーバに預けてある学習記録のバックアップ1件。
struct GuestStudyBackup {
    let snapshot: LocalStudySnapshot
    let deviceName: String?
    let updatedAt: String?

    /// 「2026年8月28日 15:04」の形にする。読めない値のときは nil を返して表示側で伏せる。
    var updatedAtText: String? {
        guard let updatedAt, let date = Self.parseDate(updatedAt) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

protocol GuestStudyBackupServicing {
    func fetch(session: AuthSession) async throws -> GuestStudyBackup?
    @discardableResult
    func save(_ snapshot: LocalStudySnapshot, deviceName: String?, session: AuthSession) async throws -> GuestStudyBackup
    func delete(session: AuthSession) async throws
}

/// 端末の学習記録をサーバへ預け、必要なときに取り戻す（G-3）。
/// 学習の正はあくまで端末側であり、ここではサーバの中身を解釈しない。
final class GuestStudyBackupService: GuestStudyBackupServicing {
    private enum Table {
        static let path = "user_local_study_backups"
        static let columns = "user_id,schema_version,device_name,payload,updated_at"
    }

    private let client: any SupabaseRequesting

    init(client: any SupabaseRequesting = SupabaseClient.shared) {
        self.client = client
    }

    func fetch(session: AuthSession) async throws -> GuestStudyBackup? {
        let rows: [BackupRow] = try await client.request(
            path: Table.path,
            method: .get,
            queryItems: [
                URLQueryItem(name: "select", value: Table.columns),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: session.accessToken,
            body: nil,
            prefer: nil
        )
        return rows.first.map {
            GuestStudyBackup(snapshot: $0.payload, deviceName: $0.deviceName, updatedAt: $0.updatedAt)
        }
    }

    @discardableResult
    func save(
        _ snapshot: LocalStudySnapshot,
        deviceName: String?,
        session: AuthSession
    ) async throws -> GuestStudyBackup {
        let row = BackupRow(
            userId: session.user.id,
            schemaVersion: snapshot.schemaVersion,
            deviceName: deviceName,
            payload: snapshot,
            updatedAt: nil
        )
        let saved: [BackupRow] = try await client.request(
            path: Table.path,
            method: .post,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id")],
            accessToken: session.accessToken,
            body: row,
            prefer: "resolution=merge-duplicates,return=representation"
        )
        let stored = saved.first
        return GuestStudyBackup(
            snapshot: stored?.payload ?? snapshot,
            deviceName: stored?.deviceName ?? deviceName,
            updatedAt: stored?.updatedAt
        )
    }

    func delete(session: AuthSession) async throws {
        try await client.execute(
            path: Table.path,
            method: .delete,
            queryItems: [URLQueryItem(name: "user_id", value: "eq.\(session.user.id)")],
            accessToken: session.accessToken,
            body: nil,
            prefer: nil
        )
    }

    /// 書き込みでは updated_at を送らない。サーバのトリガーが入れる。
    private struct BackupRow: Codable {
        let userId: String
        let schemaVersion: Int
        let deviceName: String?
        let payload: LocalStudySnapshot
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case schemaVersion = "schema_version"
            case deviceName = "device_name"
            case payload
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(userId, forKey: .userId)
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encodeIfPresent(deviceName, forKey: .deviceName)
            try container.encode(payload, forKey: .payload)
        }
    }
}
