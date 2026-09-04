import Foundation
import UIKit

/// 学習記録のバックアップを、アプリが裏側で自動的に行う（G-3）。
///
/// 学習の正は端末側のまま（G-D1）で、サーバは復元用の控えを1件だけ持つ（G-D2）。
/// 利用者は1端末しか使わない前提のため、どちらを採るかを尋ねる画面は置かない。
/// 失敗しても知らせず、次の機会に取り直す。記録も残さない。
@MainActor
final class StudyBackupSyncer {
    private let service: any GuestStudyBackupServicing
    private let localStudy: LocalStudyDataSource
    private let deviceName: () -> String?

    /// 学習の変化をまとめて1回の保存にするための待ち時間。
    private let uploadDelay: Duration

    private var pendingUpload: Task<Void, Never>?
    /// 復元の書き戻しで起きた変化を、そのまま預け直さないための目印。
    private var isRestoring = false

    init(
        service: any GuestStudyBackupServicing = GuestStudyBackupService(),
        localStudy: LocalStudyDataSource,
        uploadDelay: Duration = .seconds(5),
        deviceName: @escaping () -> String? = { UIDevice.current.model }
    ) {
        self.service = service
        self.localStudy = localStudy
        self.uploadDelay = uploadDelay
        self.deviceName = deviceName
    }

    /// ログイン直後とセッション復元直後に一度だけ呼ぶ。
    /// 端末に学習記録がなく、サーバに控えがあるときだけ書き戻す。
    /// それ以外は端末の内容を正として預け直す。
    func start(session: AuthSession, markStudyDataChanged: @escaping () -> Void) async {
        cancelPendingUpload()
        do {
            let backup = try await service.fetch(session: session)
            if let backup, !localStudy.hasStudyRecord {
                isRestoring = true
                defer { isRestoring = false }
                try localStudy.restore(backup.snapshot)
                markStudyDataChanged()
                return
            }
            try await upload(session: session)
        } catch {
            // 次の機会に取り直す。利用者には知らせない。
        }
    }

    /// 学習内容が変わったときに呼ぶ。連続した変化はまとめて1回だけ預ける。
    func scheduleUpload(session: AuthSession) {
        guard !isRestoring else { return }
        pendingUpload?.cancel()
        pendingUpload = Task { [uploadDelay] in
            try? await Task.sleep(for: uploadDelay)
            guard !Task.isCancelled else { return }
            try? await upload(session: session)
        }
    }

    /// アプリが背面へ回るときなど、待たずに預けたい場面で呼ぶ。
    func flush(session: AuthSession) async {
        pendingUpload?.cancel()
        pendingUpload = nil
        try? await upload(session: session)
    }

    /// ログアウトしたときに呼ぶ。待機中の保存を取り消すだけで、預けた控えは消さない。
    func stop() {
        cancelPendingUpload()
    }

    private func cancelPendingUpload() {
        pendingUpload?.cancel()
        pendingUpload = nil
    }

    private func upload(session: AuthSession) async throws {
        let snapshot = try localStudy.snapshot()
        try await service.save(snapshot, deviceName: deviceName(), session: session)
    }
}
