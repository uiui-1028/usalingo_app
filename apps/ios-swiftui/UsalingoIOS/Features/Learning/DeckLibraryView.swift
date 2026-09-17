import SwiftUI
import UniformTypeIdentifiers

/// デッキJSONの書き出しに使う入れ物。書き出しに必要な最小限だけを実装する。
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

/// ジャンル → 詳細から公式デッキを選んで、学習タブへ追加するギャラリー。
/// 一覧はサーバーの公式デッキを毎回読む。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState
    let onChanged: () -> Void
    @State private var decks: [OfficialDeck] = []
    @State private var isLoading = true
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let message {
                    VStack(spacing: 12) {
                        Text(message).font(.footnote).multilineTextAlignment(.center)
                        Button("もう一度読み込む") { Task { await reload() } }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("galleryLoadMessage")
                } else {
                    ForEach(GalleryDeck.genres, id: \.self) { genre in
                        genreSection(genre)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("ギャラリー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await reload() }
    }

    private func genreSection(_ genre: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(genre).font(.title2.bold())
                Spacer()
                Text("\(decks.count)デッキ")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(decks) { official in
                NavigationLink {
                    GalleryDeckDetail(official: official, onChanged: {
                        onChanged()
                        Task { await reload() }
                    })
                } label: {
                    HStack(spacing: 16) {
                        GalleryDeckCover(size: 76)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(official.deck.deckName).font(.headline).foregroundStyle(.primary)
                            if let description = official.deck.description {
                                Text(description)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            if official.isAdded {
                                Text("追加済み").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.background, in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reload() async {
        if decks.isEmpty { isLoading = true }
        defer { isLoading = false }
        do {
            decks = try await appState.fetchOfficialDecks()
            message = nil
        } catch {
            message = UserFacingError.message(for: error)
        }
    }
}

private enum GalleryDeck {
    // ponytail: 公式デッキは今は受験向けだけなので、ジャンルは1つに固定する。
    // ジャンルが増えたら、decks にジャンルの列を足してここを置き換える。
    static let genres = ["受験"]
    static let tint = Color.orange
    static let symbol = "graduationcap.fill"
}

private struct GalleryDeckCover: View {
    let size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23)
            .fill(GalleryDeck.tint.gradient)
            .overlay {
                Image(systemName: GalleryDeck.symbol)
                    .font(.system(size: size * 0.36, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct GalleryDeckDetail: View {
    @EnvironmentObject private var appState: AppState
    let official: OfficialDeck
    let onChanged: () -> Void
    @State private var words: [WordCard] = []
    @State private var isLoadingWords = true
    @State private var isDownloading = false
    @State private var isInstalled: Bool
    @State private var message: String?

    init(official: OfficialDeck, onChanged: @escaping () -> Void) {
        self.official = official
        self.onChanged = onChanged
        _isInstalled = State(initialValue: official.isAdded)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 18) {
                            GalleryDeckCover(size: 94)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(official.deck.deckName).font(.title2.bold())
                                Text("Usalingo · 公式デッキ")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button(action: download) {
                                    HStack(spacing: 6) {
                                        if isDownloading { ProgressView().tint(.white) }
                                        Image(systemName: isInstalled ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                        Text(isInstalled ? "ダウンロード済み" : isDownloading ? "追加中…" : "ダウンロード")
                                    }.font(.subheadline.bold())
                                }
                                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                                .disabled(isDownloading || isInstalled)
                                if let message {
                                    Text(message).font(.footnote).accessibilityIdentifier("galleryDownloadMessage")
                                }
                            }
                        }
                        HStack(spacing: 0) {
                            metric("収録単語", isLoadingWords ? "—" : "\(words.count)語")
                            metric("ジャンル", GalleryDeck.genres[0])
                        }
                        if let description = official.deck.description {
                            Divider()
                            Text("このデッキについて").font(.headline)
                            Text(description).font(.subheadline)
                        }
                    }.padding(20)
                }
                .frame(height: proxy.size.height * 0.48)

                VStack(spacing: 0) {
                    HStack {
                        Text("収録単語").font(.headline)
                        Spacer()
                        if !isLoadingWords {
                            Text("\(words.count)語").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                    if isLoadingWords {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        WordListView(previewWords: words, sheetOnly: true)
                    }
                }
                .background(WireColor.surface)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .strokeBorder(WireColor.ink.opacity(0.15), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("デッキ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: official.id) {
            isLoadingWords = true
            defer { isLoadingWords = false }
            do {
                words = try await appState.fetchOfficialDeckCards(deckId: official.id)
            } catch {
                message = UserFacingError.message(for: error)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }.frame(maxWidth: .infinity)
    }

    private func download() {
        guard !isDownloading, !isInstalled else { return }
        isDownloading = true
        message = nil
        Task { @MainActor in
            defer { isDownloading = false }
            do {
                try await appState.addOfficialDeck(id: official.id)
                isInstalled = true
                message = "学習タブに追加しました。"
                onChanged()
            } catch {
                message = UserFacingError.message(for: error)
            }
        }
    }
}
