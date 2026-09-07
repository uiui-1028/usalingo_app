import SwiftUI
import UniformTypeIdentifiers

/// デッキJSONの書き出しに使う入れ物。読み込みは fileImporter で直接 Data を読むため、
/// ここでは書き出しに必要な最小限だけを実装する。
struct DeckDocument: FileDocument {
    static let readableContentTypes = [UTType.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 「デッキを追加」から開くデッキライブラリ。同梱サンプルデッキの追加と、
/// JSONファイルの読み込みができる（D-7）。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState

    let onChanged: () -> Void

    @State private var bundledDecks: [DeckFile] = []
    @State private var isImporting = false
    @State private var message: String?
    /// `message` が失敗を表すかどうか。破線枠（Section 3.2）の出し分けにだけ使う。
    @State private var isMessageError = false

    var body: some View {
        List {
            Section {
                if bundledDecks.isEmpty {
                    Text("追加できる同梱デッキはありません。")
                        .wireFont(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(WireMetrics.spacingL)
                        .outlineSurface(shadow: nil)
                        .wireListRow()
                } else {
                    ForEach(bundledDecks, id: \.deckId) { file in
                        bundledRow(file)
                            .wireListRow()
                    }
                }
            } header: {
                sectionHeader("同梱デッキ")
            }

            // JSONの取り込みは端末のデッキを作る操作なので、ゲストだけに出す。
            // ログイン中のデッキは配信中の単語だけで作る（公式の単語表は書き換えない）。
            Section {
                if appState.isGuest {
                    Button {
                        message = nil
                        isMessageError = false
                        isImporting = true
                    } label: {
                        card(
                            title: "JSONを読み込む",
                            detail: "書き出したデッキJSONを選ぶと、デッキとして追加します。"
                        )
                    }
                    .buttonStyle(.plain)
                    .wireListRow()
                } else {
                    WireframeNotice(
                        text: "ログイン中は、配信中の単語で作られたデッキだけを追加できます。"
                    )
                    .wireListRow()
                }
            } header: {
                sectionHeader("ファイルから追加")
            }

            if let message {
                Section {
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
                        .wireListRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(WireColor.background)
        .contentMargins(.top, WireMetrics.spacingM, for: .scrollContent)
        .navigationTitle("デッキを追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WireColor.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .task { reload() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .wireFont(.titleS)
            .textCase(nil)
            .wireListRow(vertical: WireMetrics.spacingXS)
    }

    private func bundledRow(_ file: DeckFile) -> some View {
        Button {
            add(file)
        } label: {
            card(
                title: file.deckName,
                detail: file.description ?? "\(file.cards.count) 語"
            )
        }
        .buttonStyle(.plain)
    }

    /// 一覧の 1 行。線で囲んだカードにする。
    private func card(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
            Text(title)
                .wireFont(.titleS)
            Text(detail)
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
    }

    private func reload() {
        // 同梱JSONの一覧は端末側の資産。ログイン中でも同じ一覧から選ぶ。
        bundledDecks = appState.isGuest
            ? appState.localStudy.availableBundledDecks()
            : appState.localStudy.allBundledDecks()
    }

    private func add(_ file: DeckFile) {
        Task {
            do {
                let outcome = try await appState.studyDataSource.installBundledDeck(file)
                message = Self.installMessage(for: outcome)
                isMessageError = false
                reload()
                onChanged()
            } catch {
                message = UserFacingError.message(for: error)
                isMessageError = true
            }
        }
    }

    /// 落とした単語を黙って捨てない。何枚入って何枚入らなかったかを必ず出す。
    private static func installMessage(for outcome: DeckInstallOutcome) -> String {
        let base = "「\(outcome.deck.deckName)」を追加しました。"
        guard outcome.skippedCardCount > 0 else { return base }
        return base + "\(outcome.addedCardCount)語を入れ、"
            + "\(outcome.skippedCardCount)語は配信中の単語に無いため入れていません。"
    }

    /// 読み込み失敗は黙って捨てず、理由をそのまま画面へ出す。
    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let needsScope = url.startAccessingSecurityScopedResource()
            defer {
                if needsScope { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let deck = try appState.localStudy.importDeck(from: data)
            message = "「\(deck.name)」を追加しました。"
            isMessageError = false
            reload()
            onChanged()
        } catch let error as DeckFileError {
            message = UserFacingError.message(for: error)
            isMessageError = true
        } catch let error as LocalStudyError {
            message = UserFacingError.message(for: error)
            isMessageError = true
        } catch {
            message = "ファイルを読み込めませんでした。\(UserFacingError.advice(for: error))"
            isMessageError = true
        }
    }
}
