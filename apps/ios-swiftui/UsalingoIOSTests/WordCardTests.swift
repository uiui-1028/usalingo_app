import XCTest
import SwiftUI
import UIKit
@testable import UsalingoIOS

final class WordCardTests: XCTestCase {
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
        let appState = AppState(restoresSession: false)
        let rootView = NavigationStack {
            WordListView(previewWords: words)
        }
        .environmentObject(appState)
        .environmentObject(appState.designSettings)
        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()

        // 表示形式の切り替えは、ワイヤーフレーム化でセグメントからピルの並びに変わった。
        // 見た目の実装に依存しないよう、読み上げラベル経由で操作する。
        XCTAssertNotNil(accessibilityElement(labeled: "リスト", in: controller.view))
        let cardButton = try XCTUnwrap(accessibilityElement(labeled: "カード", in: controller.view))

        let listImage = renderedImage(of: controller.view)
        XCTAssertTrue(cardButton.accessibilityActivate())
        controller.view.layoutIfNeeded()
        let cardImage = renderedImage(of: controller.view)

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

    @MainActor
    /// 読み上げラベルが一致する要素を、View 階層とアクセシビリティ要素の両方から探す。
    private func accessibilityElement(labeled label: String, in view: UIView) -> NSObject? {
        if view.accessibilityLabel == label, view.isAccessibilityElement {
            return view
        }
        for element in view.accessibilityElements ?? [] {
            if let element = element as? NSObject, element.accessibilityLabel == label {
                return element
            }
        }
        for subview in view.subviews {
            if let match = accessibilityElement(labeled: label, in: subview) {
                return match
            }
        }
        return nil
    }

    private func firstSubview<T: UIView>(of type: T.Type, in view: UIView) -> T? {
        if let matchingView = view as? T {
            return matchingView
        }
        for subview in view.subviews {
            if let matchingView = firstSubview(of: type, in: subview) {
                return matchingView
            }
        }
        return nil
    }
}
