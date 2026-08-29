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

/// 「＋ デッキを追加」から開くデッキライブラリ。同梱サンプルデッキの追加と、
/// JSONファイルの読み込みができる（D-7）。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState

    let onChanged: () -> Void

    @State private var bundledDecks: [DeckFile] = []
    @State private var isImporting = false
    @State private var message: String?

    var body: some View {
        List {
            Section("同梱デッキ") {
                if bundledDecks.isEmpty {
                    Text("追加できる同梱デッキはありません。")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                } else {
                    ForEach(bundledDecks, id: \.deckId) { file in
                        bundledRow(file)
                    }
                }
            }

            Section("ファイルから追加") {
                Button {
                    message = nil
                    isImporting = true
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("JSONを読み込む")
                            .font(.headline)
                            .foregroundStyle(AppStyle.ink)
                        Text("書き出したデッキJSONを選ぶと、デッキとして追加します。")
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("デッキを追加")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .task { reload() }
    }

    private func bundledRow(_ file: DeckFile) -> some View {
        Button {
            add(file)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(file.deckName)
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                Text(file.description ?? "\(file.cards.count) 語")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        bundledDecks = appState.localStudy.availableBundledDecks()
    }

    private func add(_ file: DeckFile) {
        do {
            let deck = try appState.localStudy.installBundledDeck(key: file.deckId)
            message = "「\(deck.name)」を追加しました。"
            reload()
            onChanged()
        } catch {
            message = UserFacingError.message(for: error)
        }
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
            reload()
            onChanged()
        } catch let error as DeckFileError {
            message = UserFacingError.message(for: error)
        } catch let error as LocalStudyError {
            message = UserFacingError.message(for: error)
        } catch {
            message = "ファイルを読み込めませんでした。\(UserFacingError.advice(for: error))"
        }
    }
}
