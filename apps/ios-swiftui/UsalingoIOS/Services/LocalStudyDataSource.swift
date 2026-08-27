import Foundation

/// 端末に保存しているデッキ。同梱JSONと読み込みJSONの両方をこの形で登録する。
struct LocalDeck: Identifiable, Codable, Equatable {
    /// アプリ内で割り当てた番号。既存の `Deck.id` と互換にするため Int を使う。
    let id: Int
    /// デッキJSONの `deckId`。同梱ファイル名・保存ファイル名にもこの値を使う。
    let key: String
    var name: String
    var description: String?
    var isBundled: Bool

    var deck: Deck {
        Deck(id: id, deckName: name, description: description)
    }
}

/// デッキごとの「新規 n ・ 復習 m」カウンタ。
struct LocalDeckCounts: Equatable {
    let newCount: Int
    let dueCount: Int
}

enum LocalStudyError: LocalizedError, Equatable {
    case deckNotFound
    case deckFileMissing(String)
    case missingCardId
    case duplicateDeckKey(String)

    var errorDescription: String? {
        switch self {
        case .deckNotFound:
            return "デッキが見つかりませんでした。"
        case .deckFileMissing(let key):
            return "デッキ「\(key)」のデータファイルを読み込めませんでした。"
        case .missingCardId:
            return "カードIDがないため進捗を保存できませんでした。"
        case .duplicateDeckKey(let key):
            return "同じ deckId「\(key)」のデッキが既に登録されています。"
        }
    }
}

/// ローカル同梱データ方針（D-1）の実装。単語は同梱JSONから読み、進捗は端末のファイルへ保存する。
/// キューの組み立ては既存 StudyService の limitedStudyQueue / isDue /
/// sortByNextReviewDateThenId をそのまま移植したもので、SM-2 の計算は
/// `LearningProgress.marking(isCorrect:)` に委ねる。
final class LocalStudyDataSource: StudyDataSource {
    static let guestUserId = "guest"

    /// 「全単語」を表す既存の擬似デッキID。ローカルでは登録済みの全デッキを対象にする。
    static let allDecksId = -1

    private struct Library: Codable {
        var decks: [LocalDeck] = []
        var removedBundledKeys: [String] = []
        var nextDeckId = 1
        var nextCardId = 1
        /// "デッキkey#JSON内カードid" → アプリ全体で一意なカードID。
        /// デッキの中身を差し替えても既存IDが動かないよう、初見時に採番して保存する。
        var cardIds: [String: Int] = [:]
    }

    private enum FileName {
        static let library = "library.json"
        static let progress = "progress.json"
        static let tags = "tags.json"
        static let overrides = "overrides.json"
        static let importedDirectory = "imported"
    }

    // StudyService と同じ上限を移植する。
    private enum QueueLimit {
        static let review = 20
        static let new = 10
        static let futureReview = 20
        static let weak = 20
    }

    private let fileManager: FileManager
    private let directoryURL: URL
    private let bundle: Bundle

    private var library: Library
    private var progressByCardId: [String: LearningProgress]
    private var tagsByWordId: [String: [String]]
    private var overridesByWordId: [String: UserWordOverride]

    init(directoryURL: URL? = nil, bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        library = Self.loadJSON(Library.self, from: self.directoryURL.appendingPathComponent(FileName.library)) ?? Library()
        progressByCardId = Self.loadJSON([String: LearningProgress].self, from: self.directoryURL.appendingPathComponent(FileName.progress)) ?? [:]
        tagsByWordId = Self.loadJSON([String: [String]].self, from: self.directoryURL.appendingPathComponent(FileName.tags)) ?? [:]
        overridesByWordId = Self.loadJSON([String: UserWordOverride].self, from: self.directoryURL.appendingPathComponent(FileName.overrides)) ?? [:]
        syncBundledDecks()
    }

    // MARK: - デッキ一覧（学習タブ用）

    func decks() -> [LocalDeck] {
        library.decks
    }

    func deck(id: Int) -> LocalDeck? {
        library.decks.first { $0.id == id }
    }

    func counts(deckId: Int) throws -> LocalDeckCounts {
        let cards = try loadCards(deckId: deckId)
        let now = Date()
        return LocalDeckCounts(
            newCount: cards.filter { $0.learning == nil }.count,
            dueCount: cards.filter { isDue($0, now: now) }.count
        )
    }

    func moveDecks(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        library.decks.move(fromOffsets: source, toOffset: destination)
        try persistLibrary()
    }

    func removeDecks(atOffsets offsets: IndexSet) throws {
        for index in offsets {
            guard library.decks.indices.contains(index) else { continue }
            let deck = library.decks[index]
            if deck.isBundled {
                library.removedBundledKeys.append(deck.key)
            } else {
                try? fileManager.removeItem(at: importedFileURL(key: deck.key))
            }
        }
        library.decks.remove(atOffsets: offsets)
        try persistLibrary()
    }

    // MARK: - デッキ入出力（デッキライブラリ用）

    /// 同梱サンプルデッキのうち、まだ一覧に入っていないもの。
    func availableBundledDecks() -> [DeckFile] {
        let installedKeys = Set(library.decks.map(\.key))
        return bundledDeckFiles().filter { !installedKeys.contains($0.deckId) }
    }

    @discardableResult
    func installBundledDeck(key: String) throws -> LocalDeck {
        guard let file = bundledDeckFiles().first(where: { $0.deckId == key }) else {
            throw LocalStudyError.deckFileMissing(key)
        }
        guard !library.decks.contains(where: { $0.key == key }) else {
            throw LocalStudyError.duplicateDeckKey(key)
        }
        library.removedBundledKeys.removeAll { $0 == key }
        let deck = registerDeck(from: file, isBundled: true)
        try persistLibrary()
        return deck
    }

    @discardableResult
    func importDeck(from data: Data) throws -> LocalDeck {
        let file = try DeckFile.decode(from: data)
        guard !library.decks.contains(where: { $0.key == file.deckId }) else {
            throw LocalStudyError.duplicateDeckKey(file.deckId)
        }
        try ensureDirectory(importedDirectoryURL())
        try file.encoded().write(to: importedFileURL(key: file.deckId), options: .atomic)
        let deck = registerDeck(from: file, isBundled: false)
        try persistLibrary()
        return deck
    }

    func exportData(deckId: Int) throws -> Data {
        guard let deck = deck(id: deckId) else { throw LocalStudyError.deckNotFound }
        return try deckFile(for: deck).encoded()
    }

    // MARK: - StudyDataSource

    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] {
        let cards = try loadCards(deckId: deckId)
        let now = Date()
        switch mode {
        case .newOnly:
            return Array(
                cards.filter { $0.learning == nil }
                    .sorted { $0.id < $1.id }
                    .prefix(QueueLimit.new)
            )
        case .reviewOnly:
            return Array(
                cards.filter { isDue($0, now: now) }
                    .sorted(by: sortByNextReviewDateThenId)
                    .prefix(QueueLimit.review)
            )
        case .all:
            return limitedStudyQueue(cards)
        case .weakOnly:
            return Array(
                cards.filter { $0.learning?.isWeak == true }
                    .sorted {
                        if $0.learning?.incorrectCount != $1.learning?.incorrectCount {
                            return ($0.learning?.incorrectCount ?? 0) > ($1.learning?.incorrectCount ?? 0)
                        }
                        return $0.id < $1.id
                    }
                    .prefix(QueueLimit.weak)
            )
        }
    }

    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress {
        try await saveAnswerWithUndo(card: card, isCorrect: isCorrect).progress
    }

    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer {
        guard let cardId = card.cardId else { throw LocalStudyError.missingCardId }
        let previousProgress = progressByCardId[String(cardId)]
        let current = previousProgress
            ?? LearningProgress.initial(userId: Self.guestUserId, cardId: cardId)
        let progress = current.marking(isCorrect: isCorrect)
        progressByCardId[String(cardId)] = progress
        try persist(progressByCardId, to: FileName.progress)
        return SavedAnswer(progress: progress, previousProgress: previousProgress)
    }

    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {
        if let previousProgress {
            progressByCardId[String(cardId)] = previousProgress
        } else {
            progressByCardId.removeValue(forKey: String(cardId))
        }
        try persist(progressByCardId, to: FileName.progress)
    }

    func fetchTags(wordId: Int) async throws -> [String]? {
        tagsByWordId[String(wordId)]
    }

    func saveTags(_ tags: Set<String>, wordId: Int) async throws {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        tagsByWordId[String(wordId)] = cleaned
        try persist(tagsByWordId, to: FileName.tags)
    }

    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard {
        let override = UserWordOverride(
            userId: Self.guestUserId,
            wordId: payload.wordId,
            wordText: payload.wordText,
            definitionJapanese: payload.definitionJapanese,
            sentenceEnglish: payload.sentenceEnglish,
            sentenceJapanese: payload.sentenceJapanese,
            imageAssetPath: payload.imageAssetPath
        )
        overridesByWordId[String(payload.wordId)] = override
        try persist(overridesByWordId, to: FileName.overrides)

        let allCards = try loadCards(deckId: Self.allDecksId)
        guard let card = allCards.first(where: { $0.wordId == payload.wordId }) else {
            throw LocalStudyError.deckNotFound
        }
        return card
    }

    // MARK: - カードの読み込み

    private func loadCards(deckId: Int) throws -> [WordCard] {
        let targets: [LocalDeck]
        if deckId == Self.allDecksId {
            targets = library.decks
        } else if let deck = deck(id: deckId) {
            targets = [deck]
        } else {
            throw LocalStudyError.deckNotFound
        }

        var cards: [WordCard] = []
        var identityChanged = false
        for deck in targets {
            let file = try deckFile(for: deck)
            for fileCard in file.cards {
                let globalId = cardId(deckKey: deck.key, fileCardId: fileCard.id, assignedNew: &identityChanged)
                cards.append(makeCard(globalId: globalId, fileCard: fileCard))
            }
        }
        if identityChanged {
            try persistLibrary()
        }
        return cards
    }

    private func makeCard(globalId: Int, fileCard: DeckFileCard) -> WordCard {
        let progress = progressByCardId[String(globalId)]
        let base = WordCard(
            id: globalId,
            cardId: globalId,
            text: fileCard.text,
            meaning: fileCard.meaning,
            partOfSpeech: fileCard.partOfSpeech,
            sentenceEnglish: fileCard.sentenceEnglish,
            sentenceJapanese: fileCard.sentenceJapanese,
            imageAssetPath: fileCard.imageAssetPath,
            audioAssetPath: fileCard.audioAssetPath,
            tags: tagsByWordId[String(globalId)] ?? fileCard.tags ?? [],
            learningStatus: nil,
            learning: nil
        )
        let edited = overridesByWordId[String(globalId)].map { base.applying($0) } ?? base
        return edited.withLearningProgress(progress)
    }

    private func cardId(deckKey: String, fileCardId: Int, assignedNew: inout Bool) -> Int {
        let key = "\(deckKey)#\(fileCardId)"
        if let existing = library.cardIds[key] {
            return existing
        }
        let assigned = library.nextCardId
        library.nextCardId += 1
        library.cardIds[key] = assigned
        assignedNew = true
        return assigned
    }

    // MARK: - デッキ登録

    private func registerDeck(from file: DeckFile, isBundled: Bool) -> LocalDeck {
        let deck = LocalDeck(
            id: library.nextDeckId,
            key: file.deckId,
            name: file.deckName,
            description: file.description,
            isBundled: isBundled
        )
        library.nextDeckId += 1
        library.decks.append(deck)
        return deck
    }

    /// 同梱サンプルデッキを一覧へ自動登録する。ユーザーが消したものは再登録しない。
    /// 同梱JSONの差し替えでデッキ名が変わった場合も、ここで追従する。
    private func syncBundledDecks() {
        var changed = false
        let removed = Set(library.removedBundledKeys)
        for file in bundledDeckFiles() {
            if let index = library.decks.firstIndex(where: { $0.key == file.deckId }) {
                if library.decks[index].name != file.deckName || library.decks[index].description != file.description {
                    library.decks[index].name = file.deckName
                    library.decks[index].description = file.description
                    changed = true
                }
            } else if !removed.contains(file.deckId) {
                _ = registerDeck(from: file, isBundled: true)
                changed = true
            }
        }
        if changed {
            try? persistLibrary()
        }
    }

    private func bundledDeckFiles() -> [DeckFile] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "SampleDecks") ?? []
        return urls
            .compactMap { url -> DeckFile? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? DeckFile.decode(from: data)
            }
            .sorted { $0.deckId < $1.deckId }
    }

    private func deckFile(for deck: LocalDeck) throws -> DeckFile {
        if deck.isBundled {
            guard let file = bundledDeckFiles().first(where: { $0.deckId == deck.key }) else {
                throw LocalStudyError.deckFileMissing(deck.key)
            }
            return file
        }
        guard let data = try? Data(contentsOf: importedFileURL(key: deck.key)) else {
            throw LocalStudyError.deckFileMissing(deck.key)
        }
        return try DeckFile.decode(from: data)
    }

    // MARK: - キュー組み立て（StudyService から移植）

    private func limitedStudyQueue(_ cards: [WordCard]) -> [WordCard] {
        let now = Date()
        let dueCards = Array(
            cards.filter { isDue($0, now: now) }
                .sorted(by: sortByNextReviewDateThenId)
                .prefix(QueueLimit.review)
        )
        let newCards = Array(
            cards.filter { $0.learning == nil }
                .sorted { $0.id < $1.id }
                .prefix(QueueLimit.new)
        )
        let futureReviewCards = Array(
            cards.filter { card in
                guard card.learning != nil else { return false }
                return !isDue(card, now: now)
            }
            .sorted(by: sortByNextReviewDateThenId)
            .prefix(QueueLimit.futureReview)
        )

        return dueCards + newCards + futureReviewCards
    }

    private func nextReviewDate(for card: WordCard) -> Date? {
        guard let value = card.learning?.nextReviewDate else { return nil }
        return Self.parseDate(value)
    }

    private func isDue(_ card: WordCard, now: Date) -> Bool {
        guard let dueDate = nextReviewDate(for: card) else { return false }
        return dueDate <= now
    }

    private func sortByNextReviewDateThenId(_ left: WordCard, _ right: WordCard) -> Bool {
        let leftDate = nextReviewDate(for: left)
        let rightDate = nextReviewDate(for: right)
        switch (leftDate, rightDate) {
        case let (leftDate?, rightDate?):
            if leftDate != rightDate { return leftDate < rightDate }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return left.id < right.id
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    // MARK: - 永続化

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("GuestStudy", isDirectory: true)
    }

    private func importedDirectoryURL() -> URL {
        directoryURL.appendingPathComponent(FileName.importedDirectory, isDirectory: true)
    }

    private func importedFileURL(key: String) -> URL {
        importedDirectoryURL().appendingPathComponent("\(key).json")
    }

    private func ensureDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func persistLibrary() throws {
        try persist(library, to: FileName.library)
    }

    private func persist(_ value: some Encodable, to fileName: String) throws {
        try ensureDirectory(directoryURL)
        let data = try JSONEncoder().encode(value)
        try data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
