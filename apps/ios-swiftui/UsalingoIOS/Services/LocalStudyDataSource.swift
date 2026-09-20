import Foundation
import CryptoKit

/// 端末に保存しているデッキ。読み込んだJSONをこの形で登録する。
struct LocalDeck: Identifiable, Codable, Equatable {
    /// アプリ内で割り当てた番号。既存の `Deck.id` と互換にするため Int を使う。
    let id: Int
    /// デッキJSONの `deckId`。同梱ファイル名・保存ファイル名にもこの値を使う。
    let key: String
    var name: String
    var description: String?
    /// 同梱デッキを配っていた頃の名残。古い保存データとバックアップを読み書きするために残す。
    /// 端末は起動時に true の行を一覧から外す。
    var isBundled: Bool

    var deck: Deck {
        Deck(id: id, deckName: name, description: description)
    }
}

/// デッキごとの「新規 n ・ 復習 m」カウンタ。
typealias LocalDeckCounts = StudyDeckCounts

/// 端末に保存しているデッキ一覧とカードIDの対応表。
/// バックアップへそのまま入れるため、内部だけの型にしない。
struct LocalStudyLibrary: Codable {
    var decks: [LocalDeck] = []
    /// 同梱デッキを配っていた頃の名残。古いバックアップとの互換のためだけに残す。
    var removedBundledKeys: [String] = []
    var nextDeckId = 1
    var nextCardId = 1
    /// "デッキkey#JSON内カードid" → アプリ全体で一意なカードID。
    /// デッキの中身を差し替えても既存IDが動かないよう、初見時に採番して保存する。
    var cardIds: [String: Int] = [:]
}

/// 端末の学習記録をまるごと1つにまとめたもの（G-1）。
/// サーバへはこの形のまま預け、復元時にそのまま書き戻す。
struct LocalStudySnapshot: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let library: LocalStudyLibrary
    let progress: [String: LearningProgress]
    let tags: [String: [String]]
    let overrides: [String: UserWordOverride]
    /// 読み込みで追加したデッキの中身。
    let importedDecks: [String: DeckFile]
    let createdAt: String
}

/// サーバーから最後に正常取得できた教材。表示情報を落とさず端末に保存する。
private struct CachedRemoteDeck: Codable {
    let deck: Deck
    let cards: [WordCard]
}

/// アプリに同梱した最初のデッキ（サーバーの `is_starter`）。
/// サーバーの応答と同じ形で持ち、通信前でも同じカードで学習を始められるようにする。
private struct StarterDeckFile: Decodable {
    let deck: Deck
    let cards: [StudyCardRecord]

    var cached: CachedRemoteDeck? {
        let cards = cards.compactMap { $0.toCard() }
        guard !cards.isEmpty else { return nil }
        return CachedRemoteDeck(deck: deck, cards: cards)
    }
}

enum LocalStudyError: LocalizedError, Equatable {
    case deckNotFound
    case deckFileMissing(String)
    case missingCardId
    case duplicateDeckKey(String)
    case unsupportedSnapshotVersion(Int)
    case snapshotUnreadable

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
        case .unsupportedSnapshotVersion(let version):
            return "このアプリが対応していないバックアップ形式です（版 \(version)、対応している版は \(LocalStudySnapshot.currentSchemaVersion)）。アプリを更新してください。"
        case .snapshotUnreadable:
            return "バックアップの形式が正しくありません。"
        }
    }
}

/// 端末側の学習データ。公式デッキはサーバーから読んだ控え、個人のデッキは読み込んだJSONを使い、
/// 進捗は端末のファイルへ保存する。
/// キューの組み立ては既存 StudyService の limitedStudyQueue / isDue /
/// sortByNextReviewDateThenId をそのまま移植したもので、SM-2 の計算は
/// `LearningProgress.marking(isCorrect:)` に委ねる。
final class LocalStudyDataSource: StudyDataSource {
    static let guestUserId = "guest"

    /// 「全単語」を表す既存の擬似デッキID。ローカルでは登録済みの全デッキを対象にする。
    static let allDecksId = -1

    private enum FileName {
        static let library = "library.json"
        static let progress = "progress.json"
        static let tags = "tags.json"
        static let overrides = "overrides.json"
        static let remoteDecks = "remote-decks.json"
        static let importedDirectory = "imported"
        static let pendingGuestHandoff = "pending-guest-handoff"
    }

    // StudyService と同じ上限を移植する。
    private enum QueueLimit {
        // ponytail: 一時的に実質無制限。元は review 20 / new 10 / futureReview 20 / weak 20。
        static let review = 9999
        static let new = 9999
        static let futureReview = 9999
        static let weak = 9999
    }

    private let fileManager: FileManager
    private let bundle: Bundle
    private let rootDirectoryURL: URL
    private var directoryURL: URL

    /// 同梱している最初のデッキ。読み込めないときは nil のまま進める。
    private let starterDeck: CachedRemoteDeck?
    /// いま棚にある公式デッキが同梱分だけか。端末に控えが無いのと同じ扱いにする判断に使う。
    private var isStarterDeckOnly = false

    private var library: LocalStudyLibrary
    private var progressByCardId: [String: LearningProgress]
    private var tagsByWordId: [String: [String]]
    private var overridesByWordId: [String: UserWordOverride]
    private var cachedRemoteDecks: [CachedRemoteDeck]

    init(directoryURL: URL? = nil, accountId: String? = nil, fileManager: FileManager = .default, bundle: Bundle = .main) {
        self.fileManager = fileManager
        self.bundle = bundle
        starterDeck = Self.loadStarterDeck(from: bundle)
        self.rootDirectoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.directoryURL = Self.accountDirectory(root: rootDirectoryURL, id: accountId)
        library = Self.loadJSON(LocalStudyLibrary.self, from: self.directoryURL.appendingPathComponent(FileName.library)) ?? LocalStudyLibrary()
        progressByCardId = Self.loadJSON([String: LearningProgress].self, from: self.directoryURL.appendingPathComponent(FileName.progress)) ?? [:]
        tagsByWordId = Self.loadJSON([String: [String]].self, from: self.directoryURL.appendingPathComponent(FileName.tags)) ?? [:]
        overridesByWordId = Self.loadJSON([String: UserWordOverride].self, from: self.directoryURL.appendingPathComponent(FileName.overrides)) ?? [:]
        cachedRemoteDecks = Self.loadJSON([CachedRemoteDeck].self, from: self.directoryURL.appendingPathComponent(FileName.remoteDecks)) ?? []
        dropBundledDecks()
        seedStarterDeckIfNeeded()
    }

    /// 古い画面が持つデータ層を変えず、新しいアカウント用の実体を作る。
    func forAccount(id: String?) -> LocalStudyDataSource {
        LocalStudyDataSource(directoryURL: rootDirectoryURL, accountId: id, fileManager: fileManager, bundle: bundle)
    }

    var hasPendingGuestHandoff: Bool {
        fileManager.fileExists(atPath: rootDirectoryURL.appendingPathComponent(FileName.pendingGuestHandoff).path)
    }

    /// 新規の未接続利用だけを後で匿名アカウントへ引き継ぐ。以前の共通保存先に
    /// 記録がある場合は、その持ち主を特定できないので自動取得しない。
    func beginGuestHandoffIfPristine() throws {
        guard !hasPendingGuestHandoff,
              progressByCardId.isEmpty, tagsByWordId.isEmpty, overridesByWordId.isEmpty,
              library.decks.allSatisfy(\.isBundled), library.removedBundledKeys.isEmpty,
              cachedRemoteDecks.isEmpty || isStarterDeckOnly else { return }
        try ensureDirectory(rootDirectoryURL)
        try Data().write(to: rootDirectoryURL.appendingPathComponent(FileName.pendingGuestHandoff), options: .atomic)
    }

    /// コピーがすべて終わるまで元データを残す。途中終了後の再試行では、
    /// コピー済みの同一ファイルだけを認め、別の内容を上書きしない。
    func adoptPendingGuestStudy(for accountId: String) throws {
        guard hasPendingGuestHandoff else { return }
        let destination = Self.accountDirectory(root: rootDirectoryURL, id: accountId)
        try ensureDirectory(destination)
        let names = [FileName.library, FileName.progress, FileName.tags, FileName.overrides, FileName.remoteDecks]
        for name in names {
            try copyGuestFileIfNeeded(from: rootDirectoryURL.appendingPathComponent(name),
                                      to: destination.appendingPathComponent(name))
        }
        let imported = rootDirectoryURL.appendingPathComponent(FileName.importedDirectory, isDirectory: true)
        if fileManager.fileExists(atPath: imported.path) {
            let destinationImported = destination.appendingPathComponent(FileName.importedDirectory, isDirectory: true)
            try ensureDirectory(destinationImported)
            for name in try fileManager.contentsOfDirectory(atPath: imported.path) {
                try copyGuestFileIfNeeded(from: imported.appendingPathComponent(name),
                                          to: destinationImported.appendingPathComponent(name))
            }
        }
        for name in names {
            let source = rootDirectoryURL.appendingPathComponent(name)
            if fileManager.fileExists(atPath: source.path) { try fileManager.removeItem(at: source) }
        }
        if fileManager.fileExists(atPath: imported.path) { try fileManager.removeItem(at: imported) }
        try fileManager.removeItem(at: rootDirectoryURL.appendingPathComponent(FileName.pendingGuestHandoff))
    }

    func cancelPendingGuestHandoff() throws {
        let marker = rootDirectoryURL.appendingPathComponent(FileName.pendingGuestHandoff)
        if fileManager.fileExists(atPath: marker.path) { try fileManager.removeItem(at: marker) }
    }

    private func copyGuestFileIfNeeded(from source: URL, to destination: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        if fileManager.fileExists(atPath: destination.path) {
            guard try Data(contentsOf: source) == Data(contentsOf: destination) else {
                throw LocalStudyError.snapshotUnreadable
            }
        } else {
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    /// アカウントの教材・記録を端末上でも分ける。未接続時は保存済みセッションのIDを選ぶ。
    func selectAccount(id: String?) {
        directoryURL = Self.accountDirectory(root: rootDirectoryURL, id: id)
        library = Self.loadJSON(LocalStudyLibrary.self, from: directoryURL.appendingPathComponent(FileName.library)) ?? LocalStudyLibrary()
        progressByCardId = Self.loadJSON([String: LearningProgress].self, from: directoryURL.appendingPathComponent(FileName.progress)) ?? [:]
        tagsByWordId = Self.loadJSON([String: [String]].self, from: directoryURL.appendingPathComponent(FileName.tags)) ?? [:]
        overridesByWordId = Self.loadJSON([String: UserWordOverride].self, from: directoryURL.appendingPathComponent(FileName.overrides)) ?? [:]
        cachedRemoteDecks = Self.loadJSON([CachedRemoteDeck].self, from: directoryURL.appendingPathComponent(FileName.remoteDecks)) ?? []
        dropBundledDecks()
        seedStarterDeckIfNeeded()
    }

    /// 端末に控えが無いときだけ、同梱デッキを棚へ出す。控えではないのでファイルには書かない。
    private func seedStarterDeckIfNeeded() {
        guard cachedRemoteDecks.isEmpty, let starterDeck else {
            isStarterDeckOnly = false
            return
        }
        cachedRemoteDecks = [starterDeck]
        isStarterDeckOnly = true
    }

    private static func loadStarterDeck(from bundle: Bundle) -> CachedRemoteDeck? {
        guard let url = bundle.url(forResource: "StarterDeck", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StarterDeckFile.self, from: data) else { return nil }
        return file.cached
    }

    /// 全件取得が成功してから更新。通信失敗時は前回の端末版を残す。
    func cacheRemoteDecks(_ decks: [Deck], cardsByDeck: [Int: [WordCard]], progress: [LearningProgress], userId: String) throws {
        guard decks.allSatisfy({ $0.id > 0 && cardsByDeck[$0.id] != nil }) else {
            throw LocalStudyError.deckNotFound
        }
        let updated = try decks.map { deck -> CachedRemoteDeck in
            let cards = cardsByDeck[deck.id] ?? []
            guard cards.allSatisfy({ ($0.cardId ?? 0) > 0 && $0.wordId > 0 }) else {
                throw LocalStudyError.missingCardId
            }
            return CachedRemoteDeck(deck: deck, cards: cards)
        }
        var mergedProgress = progressByCardId
        for row in progress where row.userId == userId && row.cardId > 0 {
            let localCardId = -row.cardId
            let key = String(localCardId)
            guard mergedProgress[key] == nil else { continue } // 端末で回答済みなら端末を優先する。
            mergedProgress[key] = LearningProgress(
                userId: Self.guestUserId,
                cardId: localCardId,
                status: row.status,
                lastReviewedAt: row.lastReviewedAt,
                nextReviewDate: row.nextReviewDate,
                srsLevel: row.srsLevel,
                easinessFactor: row.easinessFactor,
                repetitions: row.repetitions,
                incorrectCount: row.incorrectCount,
                intervalDays: row.intervalDays,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
        try persist(mergedProgress, to: FileName.progress)
        try persist(updated, to: FileName.remoteDecks)
        progressByCardId = mergedProgress
        cachedRemoteDecks = updated
        isStarterDeckOnly = false
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
            try? fileManager.removeItem(at: importedFileURL(key: library.decks[index].key))
        }
        library.decks.remove(atOffsets: offsets)
        try persistLibrary()
    }

    // MARK: - デッキ入出力（デッキライブラリ用）

    @discardableResult
    func importDeck(from data: Data) throws -> LocalDeck {
        let file = try DeckFile.decode(from: data)
        guard !library.decks.contains(where: { $0.key == file.deckId }) else {
            throw LocalStudyError.duplicateDeckKey(file.deckId)
        }
        try ensureDirectory(importedDirectoryURL())
        try file.encoded().write(to: importedFileURL(key: file.deckId), options: .atomic)
        let deck = registerDeck(from: file)
        try persistLibrary()
        return deck
    }

    func exportData(deckId: Int) throws -> Data {
        guard let deck = deck(id: deckId) else { throw LocalStudyError.deckNotFound }
        return try deckFile(for: deck).encoded()
    }

    // MARK: - StudyDataSource

    func fetchDecks() async throws -> [Deck] {
        cachedRemoteDecks.map { cached in
            Deck(id: -cached.deck.id - 1, deckName: cached.deck.deckName,
                 description: cached.deck.description, ownerId: cached.deck.ownerId)
        } + decks().map(\.deck)
    }

    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts {
        try counts(deckId: deckId)
    }

    func fetchCards(deckId: Int) async throws -> [WordCard] {
        try loadCards(deckId: deckId)
    }

    func fetchWordList() async throws -> [WordCard] {
        try loadCards(deckId: Self.allDecksId)
    }

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

    func fetchStudyStats() async throws -> StudyStats {
        let rows = Array(progressByCardId.values)
        let now = Date()
        let reviewedDates = rows.compactMap { progress in
            progress.lastReviewedAt.flatMap(Self.parseDate)
        }
        let reviewedDays = Array(Set(reviewedDates.map { Calendar.current.startOfDay(for: $0) })).sorted()
        return StudyStats(
            studiedCount: rows.count,
            dueCount: rows.filter { Self.parseDate($0.nextReviewDate).map { $0 <= now } ?? false }.count,
            masteredCount: rows.filter { $0.status == "mastered" }.count,
            currentStreak: Self.currentStreak(from: reviewedDates),
            totalReviews: rows.reduce(0) { $0 + $1.repetitions },
            reviewedDays: reviewedDays
        )
    }

    @discardableResult
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress {
        try await saveAnswerWithUndo(card: card, isCorrect: isCorrect).progress
    }

    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer {
        try await saveAnswerWithUndo(card: card, isCorrect: isCorrect, attempt: AnswerSaveAttempt())
    }

    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool, attempt: AnswerSaveAttempt) async throws -> SavedAnswer {
        guard let cardId = card.cardId else { throw LocalStudyError.missingCardId }
        let prepared: SavedAnswer
        if let cached = attempt.prepared {
            guard cached.progress.cardId == cardId, cached.progress.userId == Self.guestUserId else {
                throw LocalStudyError.missingCardId
            }
            prepared = cached
        } else {
            let previous = progressByCardId[String(cardId)]
            let current = previous ?? LearningProgress.initial(userId: Self.guestUserId, cardId: cardId)
            prepared = SavedAnswer(progress: current.marking(isCorrect: isCorrect), previousProgress: previous)
            attempt.prepared = prepared
        }
        progressByCardId[String(cardId)] = prepared.progress
        try persist(progressByCardId, to: FileName.progress)
        return prepared
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

    // MARK: - デッキの管理

    /// サーバーから読んだ教材はキャッシュであり、オフラインでは編集・削除しない。
    func canManage(_ deck: Deck) -> Bool { deck.id > 0 }

    var supportsDeckReordering: Bool { cachedRemoteDecks.isEmpty || isStarterDeckOnly }

    var supportsDeckFileTransfer: Bool { true }

    func deleteDeck(id: Int) async throws {
        guard let index = library.decks.firstIndex(where: { $0.id == id }) else {
            throw LocalStudyError.deckNotFound
        }
        try removeDecks(atOffsets: IndexSet(integer: index))
    }

    // MARK: - バックアップ（G-1）

    /// 学習記録が1件でもあるか。自動バックアップが書き戻すかどうかの判断に使う（G-D4）。
    var hasStudyRecord: Bool {
        !progressByCardId.isEmpty
    }

    func snapshot(now: Date = Date()) throws -> LocalStudySnapshot {
        var importedDecks: [String: DeckFile] = [:]
        for deck in library.decks {
            importedDecks[deck.key] = try deckFile(for: deck)
        }
        return LocalStudySnapshot(
            schemaVersion: LocalStudySnapshot.currentSchemaVersion,
            library: library,
            progress: progressByCardId,
            tags: tagsByWordId,
            overrides: overridesByWordId,
            importedDecks: importedDecks,
            createdAt: ISO8601DateFormatter().string(from: now)
        )
    }

    /// 端末の内容をスナップショットで**全置き換え**する。
    /// 置き換え前の状態は戻せないため、端末に学習記録がないときだけ呼ぶ（G-D4）。
    func restore(_ snapshot: LocalStudySnapshot) throws {
        guard snapshot.schemaVersion == LocalStudySnapshot.currentSchemaVersion else {
            throw LocalStudyError.unsupportedSnapshotVersion(snapshot.schemaVersion)
        }

        let importedDirectory = importedDirectoryURL()
        if fileManager.fileExists(atPath: importedDirectory.path) {
            try fileManager.removeItem(at: importedDirectory)
        }
        if !snapshot.importedDecks.isEmpty {
            try ensureDirectory(importedDirectory)
            for (key, file) in snapshot.importedDecks {
                try file.encoded().write(to: importedFileURL(key: key), options: .atomic)
            }
        }

        library = snapshot.library
        progressByCardId = snapshot.progress
        tagsByWordId = snapshot.tags
        overridesByWordId = snapshot.overrides

        try persistLibrary()
        try persist(progressByCardId, to: FileName.progress)
        try persist(tagsByWordId, to: FileName.tags)
        try persist(overridesByWordId, to: FileName.overrides)

        // 古いバックアップに残る同梱デッキの行を外す。
        dropBundledDecks()
    }

    func encodedSnapshot(now: Date = Date()) throws -> Data {
        try JSONEncoder().encode(try snapshot(now: now))
    }

    static func decodeSnapshot(from data: Data) throws -> LocalStudySnapshot {
        do {
            return try JSONDecoder().decode(LocalStudySnapshot.self, from: data)
        } catch {
            throw LocalStudyError.snapshotUnreadable
        }
    }

    /// 退会完了後、このアプリが作った学習ファイルだけを消す。
    func reset() throws {
        let targets = [FileName.library, FileName.progress, FileName.tags, FileName.overrides, FileName.remoteDecks]
            .map { directoryURL.appendingPathComponent($0) } + [importedDirectoryURL()]
        for target in targets where fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        library = LocalStudyLibrary()
        progressByCardId = [:]
        tagsByWordId = [:]
        overridesByWordId = [:]
        cachedRemoteDecks = []
        dropBundledDecks()
        seedStarterDeckIfNeeded()
        try persistLibrary()
    }

    // MARK: - カードの読み込み

    private func loadCards(deckId: Int) throws -> [WordCard] {
        if deckId < Self.allDecksId {
            guard let cached = cachedRemoteDecks.first(where: { -$0.deck.id - 1 == deckId }) else {
                throw LocalStudyError.deckNotFound
            }
            return try cached.cards.map(makeCachedCard)
        }
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
        if deckId == Self.allDecksId {
            cards += try cachedRemoteDecks.flatMap { try $0.cards.map(makeCachedCard) }
        }
        return cards
    }

    private func makeCachedCard(_ card: WordCard) throws -> WordCard {
        guard let remoteCardId = card.cardId, remoteCardId > 0, card.wordId > 0 else {
            throw LocalStudyError.missingCardId
        }
        let cardId = -remoteCardId
        let wordId = -card.wordId
        var result = card.withCardId(cardId).withWordId(wordId)
        if let tags = tagsByWordId[String(wordId)] {
            result = result.withTags(tags)
        }
        if let override = overridesByWordId[String(wordId)] {
            result = result.applying(override)
        }
        if let progress = progressByCardId[String(cardId)] {
            result = result.withLearningProgress(progress)
        }
        return result
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

    private func registerDeck(from file: DeckFile) -> LocalDeck {
        let deck = LocalDeck(
            id: library.nextDeckId,
            key: file.deckId,
            name: file.deckName,
            description: file.description,
            isBundled: false
        )
        library.nextDeckId += 1
        library.decks.append(deck)
        return deck
    }

    /// 同梱デッキはアプリから外した。古い保存データに残る行は、中身を読めないので一覧から外す。
    private func dropBundledDecks() {
        guard library.decks.contains(where: \.isBundled) else { return }
        library.decks.removeAll(where: \.isBundled)
        try? persistLibrary()
    }

    private func deckFile(for deck: LocalDeck) throws -> DeckFile {
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

    private static func currentStreak(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let reviewedDays = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: Date())
        var streak = 0
        while reviewedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - 永続化

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("GuestStudy", isDirectory: true)
    }

    private static func accountDirectory(root: URL, id: String?) -> URL {
        guard let id else { return root }
        let digest = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(digest, isDirectory: true)
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
