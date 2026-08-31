import XCTest
import SwiftUI
import UIKit
@testable import UsalingoIOS

final class WordCardTests: XCTestCase {
    @MainActor
    func testAppStateSwitchesBetweenGuestAndAuthenticatedStudySources() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("usalingo-source-selection-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = LocalStudyDataSource(directoryURL: directory)
        let remote = SelectionStudyDataSource()
        var receivedSession: AuthSession?
        let state = AppState(
            restoresSession: false,
            localStudy: local,
            makeRemoteStudy: { session in
                receivedSession = session
                return remote
            }
        )

        XCTAssertTrue((state.studyDataSource as AnyObject) === local)

        let session = AuthSession(
            accessToken: "test-access",
            refreshToken: nil,
            expiresAt: nil,
            user: AuthUser(id: "user-293", email: "learner@example.com")
        )
        state.setSession(session)

        XCTAssertTrue((state.studyDataSource as AnyObject) === remote)
        XCTAssertEqual(receivedSession?.user.id, "user-293")

        state.signOut()
        XCTAssertTrue((state.studyDataSource as AnyObject) === local)
    }

    @MainActor
    func testSwipeTutorialCompletionIsSavedAndCanBeShownAgain() {
        let suiteName = "usalingo-swipe-tutorial-tests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(restoresSession: false, defaults: defaults)
        XCTAssertTrue(state.isSwipeTutorialPresented)

        state.dismissSwipeTutorial()
        XCTAssertFalse(state.isSwipeTutorialPresented)

        state.showSwipeTutorial()
        state.completeSwipeTutorial()
        XCTAssertFalse(state.isSwipeTutorialPresented)

        let restoredState = AppState(restoresSession: false, defaults: defaults)
        XCTAssertFalse(restoredState.isSwipeTutorialPresented)
        restoredState.showSwipeTutorial()
        XCTAssertTrue(restoredState.isSwipeTutorialPresented)
    }

    func testWordRecordMapsOperatorProvidedAudioAsset() throws {
        let json = """
        {
          "id": 42,
          "word_text": "apple",
          "word_meanings": [
            {
              "id": 10,
              "priority": 1,
              "part_of_speech_en": "noun",
              "definition_jp": "りんご",
              "example_contents": [
                {
                  "id": 100,
                  "sentence_en": "This is an apple.",
                  "sentence_jp": "これはりんごです。",
                  "image_asset_path": "content-images/simple/0000-0499/100.webp",
                  "audio_asset_path": "content-audio/example/simple/0000-0499/100.mp3"
                }
              ]
            }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.wordId, 42)
        XCTAssertNil(card.cardId)
        XCTAssertEqual(card.audioAssetPath, "content-audio/example/simple/0000-0499/100.mp3")
    }

    func testStudyCardRecordMapsCardAndWordIdentifiersSeparately() throws {
        let json = """
        {
          "id": 420,
          "word_id": 42,
          "sort_order": 7,
          "word": {
            "id": 42,
            "word_text": "apple",
            "word_meanings": [
              {
                "id": 10,
                "priority": 1,
                "part_of_speech_en": "noun",
                "definition_jp": "りんご",
                "example_contents": []
              }
            ]
          }
        }
        """

        let record = try JSONDecoder().decode(StudyCardRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.id, 420)
        XCTAssertEqual(card.cardId, 420)
        XCTAssertEqual(card.wordId, 42)
        XCTAssertEqual(card.text, "apple")
    }

    func testAbsoluteAudioURLIsUsedWithoutModification() {
        let expectedURL = URL(string: "https://media.example.com/apple.mp3")!
        let card = WordCard(
            id: 42,
            text: "apple",
            meaning: "りんご",
            partOfSpeech: "noun",
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: expectedURL.absoluteString,
            tags: [],
            learningStatus: nil,
            learning: nil
        )

        XCTAssertEqual(card.audioURL, expectedURL)
    }

    func testRelativeAssetPathsUsePublicStorageURL() throws {
        let card = WordCard(
            id: 100,
            text: "apple",
            meaning: "りんご",
            partOfSpeech: "noun",
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: "content-images/simple/0000-0499/100.webp",
            audioAssetPath: "content-audio/example/simple/0000-0499/100.mp3",
            tags: [],
            learningStatus: nil,
            learning: nil
        )

        let imageURL = try XCTUnwrap(card.illustrationURL)
        let audioURL = try XCTUnwrap(card.audioURL)

        XCTAssertTrue(imageURL.absoluteString.hasSuffix(
            "/storage/v1/object/public/content-images/simple/0000-0499/100.webp"
        ))
        XCTAssertTrue(audioURL.absoluteString.hasSuffix(
            "/storage/v1/object/public/content-audio/example/simple/0000-0499/100.mp3"
        ))
    }

    func testMissingImageAssetDisablesIllustrationURL() {
        let card = WordCard(
            id: 42,
            text: "apple",
            meaning: "りんご",
            partOfSpeech: "noun",
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )

        XCTAssertNil(card.illustrationURL)
    }

    func testMissingAudioAssetDisablesAudioURL() {
        let card = WordCard(
            id: 42,
            text: "apple",
            meaning: "りんご",
            partOfSpeech: "noun",
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )

        XCTAssertNil(card.audioURL)
    }

    @MainActor
    func testWordListSwitchesToTwoColumnCardsAndRendersMissingImage() throws {
        let words = [
            WordCard(
                id: 1,
                text: "apple",
                meaning: "りんご",
                partOfSpeech: "noun",
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil,
                audioAssetPath: nil,
                tags: [],
                learningStatus: nil,
                learning: nil
            ),
            WordCard(
                id: 2,
                text: "banana",
                meaning: "バナナ",
                partOfSpeech: "noun",
                sentenceEnglish: nil,
                sentenceJapanese: nil,
                imageAssetPath: nil,
                audioAssetPath: nil,
                tags: [],
                learningStatus: nil,
                learning: nil
            )
        ]
        // 表示形式の切り替えはワイヤーフレーム化でセグメントからピルの並びに変わった。
        // 実装の見た目に依存しないよう、初期表示形式を指定した2つの画面を描き比べる。
        let listImage = try renderedWordList(words: words, displayMode: .list)
        let cardImage = try renderedWordList(words: words, displayMode: .cards)

        XCTAssertNotEqual(listImage.pngData(), cardImage.pngData())
        XCTAssertGreaterThan(cardImage.size.width, 0)
        XCTAssertGreaterThan(cardImage.size.height, 0)

        let attachment = XCTAttachment(image: cardImage)
        attachment.name = "USL-239 two-column cards with missing-image fallback"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func renderedImage(of view: UIView) -> UIImage {
        UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    /// 指定した表示形式で単語リストを描画する。
    @MainActor
    private func renderedWordList(
        words: [WordCard],
        displayMode: WordListDisplayMode
    ) throws -> UIImage {
        let appState = AppState(restoresSession: false)
        let rootView = NavigationStack {
            WordListView(previewWords: words, displayMode: displayMode)
        }
        .environmentObject(appState)
        .environmentObject(appState.designSettings)
        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        return renderedImage(of: controller.view)
    }
}

private final class SelectionStudyDataSource: StudyDataSource {
    func fetchDecks() async throws -> [Deck] { [] }
    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts { StudyDeckCounts(newCount: 0, dueCount: 0) }
    func fetchCards(deckId: Int) async throws -> [WordCard] { [] }
    func fetchWordList() async throws -> [WordCard] { [] }
    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] { [] }
    func fetchStudyStats() async throws -> StudyStats { .empty }
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress { throw LocalStudyError.missingCardId }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer { throw LocalStudyError.missingCardId }
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {}
    func fetchTags(wordId: Int) async throws -> [String]? { nil }
    func saveTags(_ tags: Set<String>, wordId: Int) async throws {}
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard { throw LocalStudyError.deckNotFound }
}
