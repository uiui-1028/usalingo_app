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
    /// `message` が失敗を表すかどうか。破線枠（Section 3.2）の出し分けにだけ使う。
    @State private var isMessageError = false

    init(service: any GuestStudyBackupServicing = GuestStudyBackupService()) {
        self.service = service
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    WireCard {
                        Text("この端末の学習記録を、ログイン中のアカウントへ預けます。学習そのものは端末の中で完結しており、預けた記録は復元のためだけに使います。")
                            .wireFont(.caption)
                    }

                    if appState.isGuest {
                        section("ログインが必要です") {
                            WireCard {
                                Text("バックアップにはログインが必要です。プロフィールのユーザー名をタップするとログインできます。")
                                    .wireFont(.caption)
                            }
                        }
                    } else {
                        serverSection
                        actionSection
                    }

                    if let message {
                        section("結果") {
                            // 色相を使わずに異常を示す（破線 + 文言）。
                            Text(message)
                                .wireFont(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(WireMetrics.spacingM)
                                .outlineSurface(
                                    radius: WireMetrics.radiusControl,
                                    shadow: nil,
                                    dashed: isMessageError
                                )
                        }
                    }
                }
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("学習記録のバックアップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WireColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる").wireFont(.label)
                    }
                    .disabled(isWorking)
                    .wireDisabled(isWorking)
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

    /// 見出し + 中身のひとかたまり。`Form` の Section に相当する。
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Text(title)
                .wireFont(.titleS)
            content()
        }
    }

    @ViewBuilder
    private var serverSection: some View {
        section("預けてある記録") {
            WireCard {
                if isLoading {
                    HStack(spacing: WireMetrics.spacingS) {
                        ProgressView()
                            .tint(WireColor.ink)
                        Text("確認しています")
                            .wireFont(.caption)
                    }
                } else if let backup {
                    VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                        Text(backup.updatedAtText ?? "保存日時は不明です")
                            .wireFont(.body)
                        Text(backupDetail(backup))
                            .wireFont(.caption)
                    }
                } else {
                    Text("まだ預けていません。")
                        .wireFont(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Button {
                Task { await save() }
            } label: {
                Label("この端末の記録を預ける", systemImage: "arrow.up.doc")
            }
            .buttonStyle(.wireSecondary)
            .disabled(isWorking || isLoading)

            // 端末の記録を上書きする破壊的操作。赤は使わず破線で示す。
            Button {
                isConfirmingRestore = true
            } label: {
                Label("預けてある記録で置き換える", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.wireDestructive)
            .disabled(isWorking || isLoading || backup == nil)

            Text("預けられる記録は1件です。預けるたびに前の記録は置き換わります。")
                .wireFont(.caption)
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
            isMessageError = true
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
            isMessageError = false
        } catch {
            message = "預けられませんでした。\(UserFacingError.advice(for: error))"
            isMessageError = true
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
            isMessageError = false
        } catch {
            message = "置き換えられませんでした。\(UserFacingError.advice(for: error))"
            isMessageError = true
        }
    }
}
