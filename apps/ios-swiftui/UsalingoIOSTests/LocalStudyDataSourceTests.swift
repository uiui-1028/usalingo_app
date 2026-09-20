import XCTest
@testable import UsalingoIOS

final class LocalStudyDataSourceTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalStudyDataSourceTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testLeftoverBundledDeckRowsAreDroppedOnOpen() async throws {
        let bundled = LocalDeck(id: 1, key: "toeic-basic", name: "TOEIC 頻出単語", description: nil, isBundled: true)
        let library = LocalStudyLibrary(decks: [bundled], removedBundledKeys: [], nextDeckId: 2, nextCardId: 1, cardIds: [:])
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(library).write(to: directoryURL.appendingPathComponent("library.json"))

        let source = LocalStudyDataSource(directoryURL: directoryURL)

        XCTAssertTrue(source.decks().isEmpty)
        let words = try await source.fetchWordList()
        // 残るのは同梱デッキのカードだけ。控えのカードIDは負の値になる。
        XCTAssertTrue(words.allSatisfy { ($0.cardId ?? 0) < 0 })
        XCTAssertTrue(LocalStudyDataSource(directoryURL: directoryURL).decks().isEmpty)
    }

    func testStarterDeckIsReadyBeforeAnyServerContent() async throws {
        let source = makeDataSource()

        let decks = try await source.fetchDecks()
        let starter = try XCTUnwrap(decks.first)

        XCTAssertEqual(starter.deckName, "大学受験1000語A")
        XCTAssertFalse(source.canManage(starter))
        let cards = try await source.fetchCards(deckId: starter.id)
        XCTAssertEqual(cards.count, 100)
        XCTAssertFalse(try XCTUnwrap(cards.first).senses.isEmpty)
    }

    func testServerContentReplacesTheBundledStarterDeck() async throws {
        let source = makeDataSource()
        source.selectAccount(id: "account-a")
        let deck = Deck(id: 1, deckName: "大学受験1000語A", description: "配信版")

        try source.cacheRemoteDecks([deck], cardsByDeck: [1: [remoteCard()]], progress: [], userId: "account-a")

        let decks = try await source.fetchDecks()
        XCTAssertEqual(decks.map(\.deckName), ["大学受験1000語A"])
        XCTAssertEqual(decks.first?.description, "配信版")
    }

    @MainActor
    func testAddingOfficialDeckCachesItBeforeReturning() async throws {
        let remote = TestRemoteStudyImporter(
            deck: Deck(id: 42, deckName: "公式教材", description: nil),
            card: remoteCard(),
            progress: LearningProgress.initial(userId: "account-a", cardId: 50)
        )
        let state = AppState(
            restoresSession: false,
            authService: AuthService(sessionStore: TestStudySessionStore()),
            remoteStudy: remote,
            localStudy: makeDataSource()
        )
        state.setSession(testSession(userId: "account-a"))

        try await state.addOfficialDeck(id: 7)

        XCTAssertEqual(remote.addedDeckIds, [7])
        let decks = try await state.studyDataSource.fetchDecks()
        XCTAssertTrue(decks.contains { $0.id == -43 })
    }

    func testImportedDeckProvidesNewCardQueue() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))

        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)

        XCTAssertEqual(queue.count, 3)
        XCTAssertTrue(queue.allSatisfy { $0.learning == nil })
        XCTAssertEqual(queue.map(\.text), ["word-1", "word-2", "word-3"])
        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts, LocalDeckCounts(newCount: 3, dueCount: 0))
    }

    func testAnswerPersistsAcrossInstances() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        let saved = try await dataSource.saveAnswerWithUndo(card: card, isCorrect: true)
        XCTAssertNil(saved.previousProgress)
        XCTAssertEqual(saved.progress.repetitions, 1)
        XCTAssertEqual(saved.progress.userId, LocalStudyDataSource.guestUserId)

        // 再起動相当: 同じディレクトリから新しいインスタンスを作る。
        let reopened = makeDataSource()
        let counts = try reopened.counts(deckId: deck.id)
        XCTAssertEqual(counts.newCount, 2)
        let reloaded = try await reopened.fetchStudyQueue(deckId: deck.id, mode: .all)
        let studied = try XCTUnwrap(reloaded.first { $0.id == card.id })
        XCTAssertEqual(studied.learning?.repetitions, 1)
        XCTAssertEqual(studied.learning?.nextReviewDate, saved.progress.nextReviewDate)
    }

    func testFirstOfflineGuestAnswerMovesToAnonymousAccountOnce() async throws {
        let source = makeDataSource()
        try source.beginGuestHandoffIfPristine()
        XCTAssertTrue(source.hasPendingGuestHandoff)
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 2))
        let offlineCards = try await source.fetchCards(deckId: deck.id)
        let card = try XCTUnwrap(offlineCards.first)
        _ = try await source.saveAnswer(card: card, isCorrect: true)

        try source.adoptPendingGuestStudy(for: "new-anonymous-account")

        let account = makeDataSource().forAccount(id: "new-anonymous-account")
        let migrated = try await account.fetchCards(deckId: deck.id)
        XCTAssertEqual(migrated.first?.learning?.repetitions, 1)
        XCTAssertFalse(source.hasPendingGuestHandoff)
        XCTAssertFalse(makeDataSource().hasStudyRecord)
        XCTAssertFalse(makeDataSource().forAccount(id: "other-account").hasStudyRecord)
        try source.adoptPendingGuestStudy(for: "new-anonymous-account")
        let repeated = try await account.fetchCards(deckId: deck.id)
        XCTAssertEqual(repeated.first?.learning?.repetitions, 1)
    }

    func testGuestHandoffDoesNotOverwriteExistingAccountOrClaimLegacyData() async throws {
        let source = makeDataSource()
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 1))
        let legacyCards = try await source.fetchCards(deckId: deck.id)
        let card = try XCTUnwrap(legacyCards.first)
        _ = try await source.saveAnswer(card: card, isCorrect: true)
        try source.beginGuestHandoffIfPristine()
        XCTAssertFalse(source.hasPendingGuestHandoff) // 持ち主不明の古い記録は取得しない。

        let freshRoot = LocalStudyDataSource(directoryURL: directoryURL.appendingPathComponent("fresh"))
        try freshRoot.beginGuestHandoffIfPristine()
        let freshDeck = try freshRoot.importDeck(from: sampleDeckData(cardCount: 1))
        let freshCards = try await freshRoot.fetchCards(deckId: freshDeck.id)
        let freshCard = try XCTUnwrap(freshCards.first)
        _ = try await freshRoot.saveAnswer(card: freshCard, isCorrect: true)
        let destination = freshRoot.forAccount(id: "existing-account")
        let existingDeck = try destination.importDeck(from: sampleDeckData(cardCount: 1))
        let existingCards = try await destination.fetchCards(deckId: existingDeck.id)
        let existingCard = try XCTUnwrap(existingCards.first)
        _ = try await destination.saveAnswer(card: existingCard, isCorrect: false)

        XCTAssertThrowsError(try freshRoot.adoptPendingGuestStudy(for: "existing-account"))
        XCTAssertTrue(freshRoot.hasPendingGuestHandoff)
        XCTAssertTrue(makeDataSource().hasStudyRecord)
        let remaining = try await destination.fetchCards(deckId: existingDeck.id)
        XCTAssertEqual(remaining.first?.learning?.incorrectCount, 1)
    }

    @MainActor
    func testRestartFinishesHandoffAfterAnonymousSessionWasSaved() async throws {
        let source = makeDataSource()
        try source.beginGuestHandoffIfPristine()
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 1))
        let cards = try await source.fetchCards(deckId: deck.id)
        _ = try await source.saveAnswer(card: try XCTUnwrap(cards.first), isCorrect: true)
        let savedSession = AuthSession(
            accessToken: "test", refreshToken: nil, expiresAt: nil,
            user: AuthUser(id: "new-anonymous-account", email: nil, isAnonymous: true)
        )

        let restarted = AppState(
            restoresSession: false,
            authService: AuthService(sessionStore: TestStudySessionStore(stored: savedSession)),
            localStudy: makeDataSource()
        )

        let restored = try await restarted.studyDataSource.fetchCards(deckId: deck.id)
        XCTAssertEqual(restored.first?.learning?.repetitions, 1)
        XCTAssertFalse(makeDataSource().hasPendingGuestHandoff)
    }

    func testUndoRemovesFirstAnswer() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        let saved = try await dataSource.saveAnswerWithUndo(card: card, isCorrect: false)
        try await dataSource.restoreLearningProgress(
            cardId: try XCTUnwrap(card.cardId),
            previousProgress: saved.previousProgress
        )

        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts.newCount, 2)
    }

    @MainActor
    func testRedCheckSharesWeakAndReviewProgressAndUndo() async throws {
        let source = makeDataSource()
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 1))
        let cards = try await source.fetchCards(deckId: deck.id)
        var card = try XCTUnwrap(cards.first)
        for _ in 0..<2 {
            let progress = try await source.saveAnswer(card: card, isCorrect: false)
            card = card.withLearningProgress(progress)
        }
        let model = RedSheetCheckModel()
        model.start(words: [card], source: source) { _ in }
        model.isAnswerVisible = true
        model.submit(isCorrect: false)
        for _ in 0..<1000 where model.isSaving { await Task.yield() }
        XCTAssertFalse(model.isSaving)
        let reopened = makeDataSource()
        let weak = try await reopened.fetchStudyQueue(deckId: deck.id, mode: .weakOnly)
        XCTAssertEqual(weak.map(\.id), [card.id])
        XCTAssertEqual(weak.first?.learning?.incorrectCount, 3)
        XCTAssertNotNil(weak.first?.learning?.nextReviewDate)
        await model.undo()
        let afterUndo = try await makeDataSource().fetchCards(deckId: deck.id)
        XCTAssertEqual(afterUndo.first?.learning?.incorrectCount, 2)
        XCTAssertFalse(afterUndo.first?.learning?.isWeak ?? true)
    }

    func testResendingSameLocalAttemptDoesNotIncreaseCountTwice() async throws {
        let source = makeDataSource()
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 1))
        let cards = try await source.fetchCards(deckId: deck.id)
        let card = try XCTUnwrap(cards.first)
        let attempt = AnswerSaveAttempt()
        _ = try await source.saveAnswerWithUndo(card: card, isCorrect: false, attempt: attempt)
        let repeated = try await source.saveAnswerWithUndo(card: card, isCorrect: false, attempt: attempt)
        XCTAssertEqual(repeated.progress.incorrectCount, 1)
        XCTAssertNil(repeated.previousProgress)
    }

    func testDueCardComesFirstInQueue() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let lastCard = try XCTUnwrap(queue.last)
        let cardId = try XCTUnwrap(lastCard.cardId)

        // 期限切れの進捗を注入する。restoreLearningProgress は任意の進捗を書き戻せる。
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let overdue = LearningProgress
            .initial(userId: LocalStudyDataSource.guestUserId, cardId: cardId, now: threeDaysAgo)
            .marking(isCorrect: true, now: threeDaysAgo)
        try await dataSource.restoreLearningProgress(cardId: cardId, previousProgress: overdue)

        let reloaded = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        XCTAssertEqual(reloaded.first?.id, lastCard.id)
        let counts = try dataSource.counts(deckId: deck.id)
        XCTAssertEqual(counts, LocalDeckCounts(newCount: 2, dueCount: 1))

        let reviewOnly = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .reviewOnly)
        XCTAssertEqual(reviewOnly.map(\.id), [lastCard.id])
    }

    func testTagsAndWordOverridePersist() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 1))
        let queue = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)

        try await dataSource.saveTags(["重要", "苦手"], wordId: card.wordId)
        let edited = try await dataSource.saveWordOverride(
            WordOverridePayload(
                wordId: card.wordId,
                wordText: "edited",
                definitionJapanese: "編集済み",
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil
            )
        )
        XCTAssertEqual(edited.text, "edited")

        let reopened = makeDataSource()
        let tags = try await reopened.fetchTags(wordId: card.wordId)
        XCTAssertEqual(tags, ["苦手", "重要"])
        let reloaded = try await reopened.fetchStudyQueue(deckId: deck.id, mode: .all)
        XCTAssertEqual(reloaded.first?.text, "edited")
        XCTAssertEqual(reloaded.first?.meaning, "編集済み")
    }

    func testResetRemovesLocalStudyDataAndRestoresBundledDefault() async throws {
        let source = LocalStudyDataSource(directoryURL: directoryURL)
        let imported = try source.importDeck(from: sampleDeckData(cardCount: 1))
        let cards = try await source.fetchCards(deckId: imported.id)
        let card = try XCTUnwrap(cards.first)
        _ = try await source.saveAnswer(card: card, isCorrect: true)
        try await source.saveTags(["重要"], wordId: card.wordId)
        _ = try await source.saveWordOverride(
            WordOverridePayload(
                wordId: card.wordId,
                wordText: "edited",
                definitionJapanese: "編集済み",
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil
            )
        )
        let unrelatedFile = directoryURL.appendingPathComponent("unrelated.txt")
        try Data("keep".utf8).write(to: unrelatedFile)

        try source.reset()

        let reopened = LocalStudyDataSource(directoryURL: directoryURL)
        XCTAssertFalse(reopened.hasStudyRecord)
        let tags = try await reopened.fetchTags(wordId: card.wordId)
        XCTAssertNil(tags)
        XCTAssertFalse(reopened.decks().contains { $0.key == imported.key })
        XCTAssertTrue(reopened.decks().isEmpty)
        let remainingCards = try await reopened.fetchWordList()
        XCTAssertFalse(remainingCards.contains { $0.text == "edited" })
        let snapshot = try reopened.snapshot()
        XCTAssertTrue(snapshot.progress.isEmpty)
        XCTAssertTrue(snapshot.tags.isEmpty)
        XCTAssertTrue(snapshot.overrides.isEmpty)
        XCTAssertTrue(snapshot.importedDecks.isEmpty)
        XCTAssertEqual(try String(contentsOf: unrelatedFile, encoding: .utf8), "keep")
    }

    func testRemoteContentKeepsFullCardAndSeparatesAccounts() async throws {
        let source = makeDataSource()
        let deck = Deck(id: 42, deckName: "公式教材", description: "配信版")
        let card = remoteCard()
        let progress = LearningProgress.initial(userId: "account-a", cardId: 50).marking(isCorrect: true)
        source.selectAccount(id: "account-a")
        try source.cacheRemoteDecks([deck], cardsByDeck: [42: [card]], progress: [progress], userId: "account-a")

        let fetchedDecks = try await source.fetchDecks()
        let cachedDeck = try XCTUnwrap(fetchedDecks.first { $0.id == -43 })
        XCTAssertFalse(source.canManage(cachedDeck))
        let fetchedCards = try await source.fetchCards(deckId: cachedDeck.id)
        let cachedCard = try XCTUnwrap(fetchedCards.first)
        XCTAssertEqual(cachedCard.cardId, -50)
        XCTAssertEqual(cachedCard.wordId, -10)
        XCTAssertEqual(cachedCard.senses, card.senses)
        XCTAssertEqual(cachedCard.synonyms, card.synonyms)
        XCTAssertEqual(cachedCard.etymology, card.etymology)
        XCTAssertEqual(cachedCard.wordAudioAssetPath, card.wordAudioAssetPath)
        XCTAssertEqual(cachedCard.learning?.repetitions, 1)

        let reopened = makeDataSource()
        reopened.selectAccount(id: "account-a")
        let persisted = try await reopened.fetchCards(deckId: -43)
        XCTAssertEqual(persisted.first?.senses, card.senses)
        XCTAssertEqual(persisted.first?.learning?.repetitions, 1)
        reopened.selectAccount(id: "account-b")
        let otherAccountDecks = try await reopened.fetchDecks()
        XCTAssertFalse(otherAccountDecks.contains { $0.id == -43 })
        reopened.selectAccount(id: "account-a")
        let restoredCards = try await reopened.fetchCards(deckId: -43)
        XCTAssertEqual(restoredCards.first?.learning?.repetitions, 1)
    }

    func testRemoteRefreshKeepsLocalAnswerAndLastGoodContent() async throws {
        let source = makeDataSource()
        source.selectAccount(id: "account-a")
        let deck = Deck(id: 42, deckName: "公式教材", description: nil)
        let card = remoteCard()
        let serverProgress = LearningProgress.initial(userId: "account-a", cardId: 50).marking(isCorrect: true)
        try source.cacheRemoteDecks([deck], cardsByDeck: [42: [card]], progress: [serverProgress], userId: "account-a")
        let fetchedCards = try await source.fetchCards(deckId: -43)
        let localCard = try XCTUnwrap(fetchedCards.first)
        _ = try await source.saveAnswer(card: localCard, isCorrect: true)

        let newerServerProgress = serverProgress.marking(isCorrect: true).marking(isCorrect: true)
        try source.cacheRemoteDecks([deck], cardsByDeck: [42: [card]], progress: [newerServerProgress], userId: "account-a")
        let retained = try await source.fetchCards(deckId: -43)
        XCTAssertEqual(retained.first?.learning?.repetitions, 2)
        XCTAssertThrowsError(try source.cacheRemoteDecks([deck], cardsByDeck: [:], progress: [], userId: "account-a"))
        let afterFailure = try await source.fetchCards(deckId: -43)
        XCTAssertEqual(afterFailure.first?.senses, card.senses)
        XCTAssertEqual(afterFailure.first?.learning?.repetitions, 2)
    }

    @MainActor
    func testAppStateImportsExistingRemoteProgressAndKeepsOfflineAnswerAfterRefresh() async throws {
        let source = makeDataSource()
        let card = remoteCard()
        let remote = TestRemoteStudyImporter(
            deck: Deck(id: 42, deckName: "公式教材", description: nil),
            card: card,
            progress: LearningProgress.initial(userId: "account-a", cardId: 50).marking(isCorrect: true)
        )
        let state = AppState(
            restoresSession: false,
            authService: AuthService(sessionStore: TestStudySessionStore()),
            remoteStudy: remote,
            localStudy: source
        )
        state.setSession(AuthSession(
            accessToken: "test", refreshToken: nil, expiresAt: nil,
            user: AuthUser(id: "account-a", email: nil)
        ))
        await state.refreshOfficialContentIfConnected()

        let cachedCards = try await state.studyDataSource.fetchCards(deckId: -43)
        let cachedCard = try XCTUnwrap(cachedCards.first)
        XCTAssertEqual(cachedCard.learning?.repetitions, 1)
        _ = try await state.studyDataSource.saveAnswer(card: cachedCard, isCorrect: true)
        remote.progress = remote.progress.marking(isCorrect: true).marking(isCorrect: true)
        await state.refreshOfficialContentIfConnected()

        let refreshedCards = try await state.studyDataSource.fetchCards(deckId: -43)
        XCTAssertEqual(refreshedCards.first?.learning?.repetitions, 2)
        remote.shouldFail = true
        await state.refreshOfficialContentIfConnected()
        let offlineCards = try await state.studyDataSource.fetchCards(deckId: -43)
        XCTAssertEqual(offlineCards.first?.learning?.repetitions, 2)
    }

    @MainActor
    func testAccountSwitchDoesNotExposeOrOverwriteAnotherAccountsOfflineAnswer() async throws {
        let remote = TestRemoteStudyImporter(
            deck: Deck(id: 42, deckName: "公式教材", description: nil),
            card: remoteCard(),
            progress: LearningProgress.initial(userId: "account-a", cardId: 50)
        )
        let state = AppState(
            restoresSession: false,
            authService: AuthService(sessionStore: TestStudySessionStore()),
            remoteStudy: remote,
            localStudy: makeDataSource()
        )
        state.setSession(testSession(userId: "account-a"))
        await state.refreshOfficialContentIfConnected()
        let accountASource = state.studyDataSource
        let initialCards = try await accountASource.fetchCards(deckId: -43)
        let card = try XCTUnwrap(initialCards.first)
        _ = try await accountASource.saveAnswer(card: card, isCorrect: true)

        remote.shouldFail = true // B はオフラインで開く。A の教材を借りてはいけない。
        state.setSession(testSession(userId: "account-b"))
        let accountBDecks = try await state.studyDataSource.fetchDecks()
        XCTAssertFalse(accountBDecks.contains { $0.id == -43 })
        XCTAssertFalse(state.localStudy.hasStudyRecord)
        _ = try await accountASource.saveAnswer(card: card, isCorrect: true) // 古い画面からの遅い保存
        XCTAssertFalse(state.localStudy.hasStudyRecord)

        state.setSession(testSession(userId: "account-a"))
        let restored = try await state.studyDataSource.fetchCards(deckId: -43)
        XCTAssertEqual(restored.first?.learning?.repetitions, 2)
        let reopened = makeDataSource().forAccount(id: "account-a")
        let reopenedCards = try await reopened.fetchCards(deckId: -43)
        XCTAssertEqual(reopenedCards.first?.learning?.repetitions, 2)
    }

    private func testSession(userId: String) -> AuthSession {
        AuthSession(accessToken: "test", refreshToken: nil, expiresAt: nil,
                    user: AuthUser(id: userId, email: nil))
    }

    private func remoteCard() -> WordCard {
        WordCard(
            id: 10,
            cardId: 50,
            text: "acquire",
            senses: [WordSense(meaning: "得る", partOfSpeech: "動詞"), WordSense(meaning: "習得する")],
            sentenceEnglish: "Acquire a skill.",
            sentenceJapanese: "技術を習得する。",
            imageAssetPath: "image.png",
            audioAssetPath: "sentence.mp3",
            wordAudioAssetPath: "word.mp3",
            tags: ["重要"],
            learningStatus: nil,
            learning: nil,
            synonyms: [WordSynonym(word: "obtain", meaning: "得る")],
            etymology: "語源"
        )
    }

    func testCardIdsStayStableWhenDeckShrinks() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 3))
        let originalIds = try await dataSource.fetchStudyQueue(deckId: deck.id, mode: .all).map(\.id)

        // 語数を減らしたJSONへ差し替えても、残った単語のIDは変わらない。
        try dataSource.removeDecks(atOffsets: IndexSet(integer: 0))
        let replaced = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))
        let replacedIds = try await dataSource.fetchStudyQueue(deckId: replaced.id, mode: .all).map(\.id)

        XCTAssertEqual(replacedIds, Array(originalIds.prefix(2)))
    }

    func testImportRejectsInvalidDeckFiles() throws {
        let dataSource = makeDataSource()

        XCTAssertThrowsError(try dataSource.importDeck(from: Data("not json".utf8))) { error in
            XCTAssertEqual(error as? DeckFileError, .unreadable)
        }
        XCTAssertThrowsError(try dataSource.importDeck(from: sampleDeckData(formatVersion: 2))) { error in
            XCTAssertEqual(error as? DeckFileError, .unsupportedFormatVersion(2))
        }
        XCTAssertThrowsError(try dataSource.importDeck(from: duplicateCardIdDeckData())) { error in
            XCTAssertEqual(error as? DeckFileError, .duplicateCardIds([1]))
        }

        _ = try dataSource.importDeck(from: sampleDeckData())
        XCTAssertThrowsError(try dataSource.importDeck(from: sampleDeckData())) { error in
            XCTAssertEqual(error as? LocalStudyError, .duplicateDeckKey("sample"))
        }
    }

    func testExportedDeckRoundTrips() async throws {
        let dataSource = makeDataSource()
        let deck = try dataSource.importDeck(from: sampleDeckData(cardCount: 2))

        let exported = try dataSource.exportData(deckId: deck.id)
        let decoded = try DeckFile.decode(from: exported)

        XCTAssertEqual(decoded, try DeckFile.decode(from: sampleDeckData(cardCount: 2)))
    }

    // MARK: - Helpers

    private func makeDataSource() -> LocalStudyDataSource {
        LocalStudyDataSource(directoryURL: directoryURL)
    }

    private func sampleDeckData(cardCount: Int = 3, deckId: String = "sample", formatVersion: Int = 1) -> Data {
        let cards = (1...max(1, cardCount)).map { index in
            """
            {
                "id": \(index),
                "text": "word-\(index)",
                "meaning": "意味\(index)",
                "partOfSpeech": null,
                "sentenceEnglish": null,
                "sentenceJapanese": null,
                "imageAssetPath": null,
                "audioAssetPath": null,
                "tags": null
            }
            """
        }
        let json = """
        {
            "formatVersion": \(formatVersion),
            "deckId": "\(deckId)",
            "deckName": "テストデッキ",
            "description": "テスト用",
            "cards": [\(cards.joined(separator: ","))]
        }
        """
        return Data(json.utf8)
    }

    private func duplicateCardIdDeckData() -> Data {
        Data("""
        {
            "formatVersion": 1,
            "deckId": "duplicated",
            "deckName": "重複",
            "description": null,
            "cards": [
                {"id": 1, "text": "a", "meaning": "あ"},
                {"id": 1, "text": "b", "meaning": "い"}
            ]
        }
        """.utf8)
    }
}

private final class TestStudySessionStore: SessionStoring {
    private var stored: AuthSession?
    init(stored: AuthSession? = nil) { self.stored = stored }
    func save(_ session: AuthSession) throws { stored = session }
    func load() throws -> AuthSession? { stored }
    func clear() throws { stored = nil }
}

private final class TestRemoteStudyImporter: RemoteStudyImporting {
    let deck: Deck
    let card: WordCard
    var progress: LearningProgress
    var shouldFail = false
    private(set) var addedDeckIds: [Int] = []

    init(deck: Deck, card: WordCard, progress: LearningProgress) {
        self.deck = deck
        self.card = card
        self.progress = progress
    }

    func fetchDecks(session: AuthSession) async throws -> [Deck] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return [deck]
    }

    func fetchOfficialDecks(session: AuthSession) async throws -> [OfficialDeck] {
        [OfficialDeck(deck: deck, isAdded: true)]
    }

    func addOfficialDeck(id: Int, session: AuthSession) async throws {
        addedDeckIds.append(id)
    }

    func fetchCards(deckId: Int, session: AuthSession) async throws -> [WordCard] { [card] }
    func fetchAllLearningProgress(session: AuthSession) async throws -> [LearningProgress] { [progress] }
}

// MARK: - バックアップ（G-1）

extension LocalStudyDataSourceTests {
    func testSnapshotRoundTripsToAnotherDevice() async throws {
        let source = makeDataSource()
        let deck = try source.importDeck(from: sampleDeckData(cardCount: 3))
        let queue = try await source.fetchStudyQueue(deckId: deck.id, mode: .all)
        let card = try XCTUnwrap(queue.first)
        let saved = try await source.saveAnswerWithUndo(card: card, isCorrect: true)
        try await source.saveTags(["重要"], wordId: card.wordId)

        let data = try source.encodedSnapshot()

        // 別端末に相当する空のディレクトリへ取り込む。
        let otherDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalStudyDataSourceTests-other-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: otherDirectory) }
        let restored = LocalStudyDataSource(directoryURL: otherDirectory)
        XCTAssertFalse(restored.hasStudyRecord)

        try restored.restore(LocalStudyDataSource.decodeSnapshot(from: data))

        XCTAssertTrue(restored.hasStudyRecord)
        let restoredDeck = try XCTUnwrap(restored.decks().first { $0.key == deck.key })
        XCTAssertEqual(restoredDeck.name, deck.name)
        XCTAssertEqual(try restored.counts(deckId: restoredDeck.id), LocalDeckCounts(newCount: 2, dueCount: 0))
        let restoredCards = try await restored.fetchStudyQueue(deckId: restoredDeck.id, mode: .all)
        let studied = try XCTUnwrap(restoredCards.first { $0.id == card.id })
        XCTAssertEqual(studied.learning?.nextReviewDate, saved.progress.nextReviewDate)
        XCTAssertEqual(studied.learning?.repetitions, 1)
        let restoredTags = try await restored.fetchTags(wordId: card.wordId)
        XCTAssertEqual(restoredTags, ["重要"])
    }

    func testRestoreReplacesExistingContent() async throws {
        let source = makeDataSource()
        _ = try source.importDeck(from: sampleDeckData(cardCount: 2, deckId: "kept"))
        let snapshot = try source.snapshot()

        _ = try source.importDeck(from: sampleDeckData(cardCount: 1, deckId: "added-later"))
        XCTAssertEqual(source.decks().count, 2)

        try source.restore(snapshot)

        // 取り込みは全置き換え。あとから足したデッキは残らない。
        XCTAssertEqual(source.decks().map(\.key), ["kept"])
    }

    func testRestoreRejectsUnknownSchemaVersion() throws {
        let source = makeDataSource()
        let data = try source.encodedSnapshot()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["schemaVersion"] = LocalStudySnapshot.currentSchemaVersion + 1
        let futureData = try JSONSerialization.data(withJSONObject: object)

        let snapshot = try LocalStudyDataSource.decodeSnapshot(from: futureData)
        XCTAssertThrowsError(try source.restore(snapshot)) { error in
            XCTAssertEqual(
                error as? LocalStudyError,
                .unsupportedSnapshotVersion(LocalStudySnapshot.currentSchemaVersion + 1)
            )
        }
    }

    func testDecodeSnapshotRejectsBrokenData() {
        XCTAssertThrowsError(try LocalStudyDataSource.decodeSnapshot(from: Data("not json".utf8))) { error in
            XCTAssertEqual(error as? LocalStudyError, .snapshotUnreadable)
        }
    }
}
