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

/// ジャンル → 詳細から同梱デッキを選ぶギャラリー。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState
    let onChanged: () -> Void
    @State private var bundledDecks: [DeckFile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(GalleryDeck.genres, id: \.self) { genre in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(genre).font(.title2.bold())
                            Spacer()
                            Text("\(decks(for: genre).count)デッキ")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(decks(for: genre), id: \.deckId) { file in
                            NavigationLink {
                                GalleryDeckDetail(file: file, onChanged: onChanged)
                            } label: {
                                HStack(spacing: 16) {
                                    GalleryDeckCover(file: file, size: 76)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(file.deckName).font(.headline).foregroundStyle(.primary)
                                        Text(file.description ?? "サンプルデッキ")
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        Text("\(file.cards.count)語 · サンプル")
                                            .font(.caption2).foregroundStyle(.secondary)
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
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("ギャラリー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { reload() }
    }

    private func reload() {
        bundledDecks = appState.localStudy.allBundledDecks().filter { $0.deckId.hasPrefix("gallery-") }
    }

    private func decks(for genre: String) -> [DeckFile] {
        bundledDecks.filter { GalleryDeck.genre($0) == genre }
    }
}

private enum GalleryDeck {
    static let genres = ["TOEIC", "日常", "受験"]
    static func language(_ file: DeckFile) -> String {
        file.deckId.hasPrefix("gallery-ja-") ? "日本語" : "英語"
    }
    static func genre(_ file: DeckFile) -> String {
        file.deckId.contains("-toeic-") ? "TOEIC" : file.deckId.contains("-daily-") ? "日常" : "受験"
    }
    static func tint(_ file: DeckFile) -> Color {
        switch genre(file) {
        case "TOEIC": .indigo
        case "日常": .teal
        default: .orange
        }
    }
    static func symbol(_ file: DeckFile) -> String {
        switch genre(file) {
        case "TOEIC": "briefcase.fill"
        case "日常": "bubble.left.and.bubble.right.fill"
        default: "graduationcap.fill"
        }
    }
}

private struct GalleryDeckCover: View {
    let file: DeckFile
    let size: CGFloat
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: size * 0.23)
                .fill(GalleryDeck.tint(file).gradient)
            Image(systemName: GalleryDeck.symbol(file))
                .font(.system(size: size * 0.36, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(GalleryDeck.language(file) == "日本語" ? "あ" : "Aa")
                .font(.system(size: size * 0.15, weight: .bold))
                .padding(size * 0.12)
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct GalleryDeckDetail: View {
    @EnvironmentObject private var appState: AppState
    let file: DeckFile
    let onChanged: () -> Void
    @State private var isDownloading = false
    @State private var isInstalled = false
    @State private var isCheckingInstallation = true
    @State private var message: String?

    private var words: [WordCard] {
        file.cards.map {
            WordCard(id: $0.id, text: $0.text, meaning: $0.meaning,
                     partOfSpeech: $0.partOfSpeech, sentenceEnglish: $0.sentenceEnglish,
                     sentenceJapanese: $0.sentenceJapanese, imageAssetPath: $0.imageAssetPath,
                     audioAssetPath: $0.audioAssetPath, tags: $0.tags ?? [], learningStatus: nil, learning: nil)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 18) {
                            GalleryDeckCover(file: file, size: 94)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(file.deckName).font(.title2.bold())
                                Text("Usalingo · サンプルデッキ")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button(action: download) {
                                    HStack(spacing: 6) {
                                        if isDownloading { ProgressView().tint(.white) }
                                        Image(systemName: isInstalled ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                        Text(isInstalled ? "ダウンロード済み" : isDownloading ? "追加中…" : "ダウンロード")
                                    }.font(.subheadline.bold())
                                }
                                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                                .disabled(isDownloading || isInstalled || isCheckingInstallation)
                                if let message {
                                    Text(message).font(.footnote).accessibilityIdentifier("galleryDownloadMessage")
                                }
                            }
                        }
                        HStack(spacing: 0) {
                            metric("収録単語", "\(file.cards.count)語")
                            metric("言語", GalleryDeck.language(file))
                            metric("ジャンル", GalleryDeck.genre(file))
                        }
                        Divider()
                        Text("このデッキについて").font(.headline)
                        Text(file.description ?? "毎日の学習にぴったりの単語を集めました。")
                            .font(.subheadline)
                        Text("1日3語から、自分のペースで。下のリストで収録語を確認してから追加できます。説明と教材は画面確認用のサンプルです。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(20)
                }
                .frame(height: proxy.size.height * 0.48)

                VStack(spacing: 0) {
                    HStack {
                        Text("収録単語").font(.headline)
                        Spacer()
                        Text("\(file.cards.count)語").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20).padding(.vertical, 12)
                    WordListView(previewWords: words, sheetOnly: true)
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
        .task(id: appState.session?.user.id ?? "guest") {
            isCheckingInstallation = true
            defer { isCheckingInstallation = false }
            if appState.studyDataSource.supportsDeckFileTransfer {
                isInstalled = appState.localStudy.decks().contains { $0.key == file.deckId }
            } else {
                do {
                    let decks = try await appState.studyDataSource.fetchDecks()
                    isInstalled = decks.contains { $0.deckName == file.deckName }
                } catch {
                    message = UserFacingError.message(for: error)
                }
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
                let outcome = try await appState.studyDataSource.installBundledDeck(file)
                isInstalled = true
                message = "学習タブに追加しました。"
                if outcome.skippedCardCount > 0 {
                    message = "\(outcome.addedCardCount)語を追加しました。\(outcome.skippedCardCount)語は配信中の単語に無いため追加していません。"
                }
                onChanged()
            } catch {
                message = UserFacingError.message(for: error)
            }
        }
    }
}
