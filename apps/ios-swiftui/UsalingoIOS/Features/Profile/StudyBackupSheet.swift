import SwiftUI
import UIKit

/// 学習記録のバックアップ画面（G-3）。
/// 学習の正は端末側なので、保存も復元もユーザーの操作でだけ行う（G-D3）。
struct StudyBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    private let service: any GuestStudyBackupServicing

    @State private var backup: GuestStudyBackup?
    @State private var isLoading = false
    @State private var isWorking = false
    @State private var isConfirmingRestore = false
    @State private var message: String?

    init(service: any GuestStudyBackupServicing = GuestStudyBackupService()) {
        self.service = service
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("この端末の学習記録を、ログイン中のアカウントへ預けます。学習そのものは端末の中で完結しており、預けた記録は復元のためだけに使います。")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                }

                if appState.isGuest {
                    Section("ログインが必要です") {
                        Text("バックアップにはログインが必要です。プロフィールのユーザー名をタップするとログインできます。")
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
                    }
                } else {
                    serverSection
                    actionSection
                }

                if let message {
                    Section("結果") {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppStyle.ink)
                    }
                }
            }
            .navigationTitle("学習記録のバックアップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .task { await load() }
            .confirmationDialog(
                "この端末の記録を、預けてある記録で置き換えます。",
                isPresented: $isConfirmingRestore,
                titleVisibility: .visible
            ) {
                Button("置き換える", role: .destructive) {
                    Task { await restore() }
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text(restoreWarning)
            }
        }
    }

    @ViewBuilder
    private var serverSection: some View {
        Section("預けてある記録") {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("確認しています")
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            } else if let backup {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.updatedAtText ?? "保存日時は不明です")
                        .foregroundStyle(AppStyle.ink)
                    Text(backupDetail(backup))
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            } else {
                Text("まだ預けていません。")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                Label("この端末の記録を預ける", systemImage: "arrow.up.doc")
            }
            .disabled(isWorking || isLoading)

            Button {
                isConfirmingRestore = true
            } label: {
                Label("預けてある記録で置き換える", systemImage: "arrow.down.doc")
            }
            .disabled(isWorking || isLoading || backup == nil)
        } footer: {
            Text("預けられる記録は1件です。預けるたびに前の記録は置き換わります。")
        }
    }

    /// 端末に学習履歴があるときは、消える側があることを先に伝える（G-D4）。
    private var restoreWarning: String {
        appState.localStudy.hasStudyRecord
            ? "この端末にも学習記録があります。置き換えると、いまの記録は戻せません。"
            : "この端末の学習記録はまだありません。置き換えても失うものはありません。"
    }

    private func backupDetail(_ backup: GuestStudyBackup) -> String {
        let deckCount = backup.snapshot.library.decks.count
        let studiedCount = backup.snapshot.progress.count
        let device = backup.deviceName.map { "\($0)から・" } ?? ""
        return "\(device)デッキ \(deckCount) ・ 学習済み \(studiedCount) 語"
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            backup = try await service.fetch(session: session)
        } catch {
            message = "預けてある記録を確認できませんでした。\(UserFacingError.advice(for: error))"
        }
    }

    private func save() async {
        guard let session = appState.session else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let snapshot = try appState.localStudy.snapshot()
            backup = try await service.save(
                snapshot,
                deviceName: UIDevice.current.model,
                session: session
            )
            message = "この端末の記録を預けました。"
        } catch {
            message = "預けられませんでした。\(UserFacingError.advice(for: error))"
        }
    }

    private func restore() async {
        guard let backup else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try appState.localStudy.restore(backup.snapshot)
            appState.markStudyDataChanged()
            message = "預けてある記録で置き換えました。"
        } catch {
            message = "置き換えられませんでした。\(UserFacingError.advice(for: error))"
        }
    }
}
