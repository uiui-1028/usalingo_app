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
    func testRedSheetRendersOverMeaningColumnAtNarrowAndStandardWidths() throws {
        let words = (1...16).map { index in
            WordCard(id: index, text: index == 1 ? "accommodate" : "word \(index)",
                     meaning: "収容する、対応する", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
        for width: CGFloat in [320, 393] {
            let off = try renderedWordList(words: words, displayMode: .list, width: width)
            let on = try renderedWordList(words: words, displayMode: .list, width: width, redSheetEnabled: true)
            XCTAssertNotEqual(off.pngData(), on.pngData())
            // A broad, solid red area must cover the meaning column, never the English column.
            let right = try redPixelCount(in: on, rightHalf: true)
            let left = try redPixelCount(in: on, rightHalf: false)
            XCTAssertGreaterThan(right, 10_000)
            XCTAssertLessThan(left, 5_000)
            XCTAssertLessThan(try redPixelCount(in: off, rightHalf: true), 5_000)
            for (name, image) in [("off", off), ("on", on)] {
                let attachment = XCTAttachment(image: image)
                attachment.name = "Red sheet \(name) width \(Int(width))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testRedSheetStopsUseActualVariableHeightRowBoundaries() {
        let frames = [
            CGRect(x: 0, y: -30, width: 320, height: 80),
            CGRect(x: 0, y: 50, width: 320, height: 130),
            CGRect(x: 0, y: 180, width: 320, height: 90),
            CGRect(x: 0, y: 270, width: 320, height: 160),
            CGRect(x: 0, y: 430, width: 320, height: 80)
        ]
        let stops = WordListRowSnapping.sheetStops(frames: frames, availableHeight: 500)
        XCTAssertEqual(stops, [180, 270])
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: 230, stops: stops), 270)
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: -500, stops: stops), 180)
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: 900, stops: stops), 270)
    }

    func testRedSheetShortListsAndLargeTextNeverInventMidRowStops() {
        let singleRow = [CGRect(x: 0, y: 0, width: 320, height: 80)]
        XCTAssertEqual(WordListRowSnapping.sheetStops(frames: singleRow, availableHeight: 500), [0, 80])
        let tallRow = [CGRect(x: 0, y: 0, width: 320, height: 700)]
        XCTAssertEqual(WordListRowSnapping.sheetStops(frames: tallRow, availableHeight: 500), [0])
        XCTAssertEqual(WordListRowSnapping.sheetStops(frames: [], availableHeight: 0), [0])
    }

    func testRedSheetAccessibilityMovesExactlyOneBoundaryAndClampsAtEnds() {
        let stops: [CGFloat] = [120, 200, 330]
        XCTAssertEqual(WordListRowSnapping.adjacentStop(to: 120, stops: stops, movingDown: true), 200)
        XCTAssertEqual(WordListRowSnapping.adjacentStop(to: 330, stops: stops, movingDown: false), 200)
        XCTAssertEqual(WordListRowSnapping.adjacentStop(to: 120, stops: stops, movingDown: false), 120)
        XCTAssertEqual(WordListRowSnapping.adjacentStop(to: 330, stops: stops, movingDown: true), 330)
    }

    func testBottomPaddingLetsLastRowReachViewportTop() {
        let viewport: CGFloat = 620
        let lastRow: CGFloat = 130
        let precedingRows: CGFloat = 800
        let padding = WordListRowSnapping.bottomPadding(viewportHeight: viewport, lastRowHeight: lastRow)
        let maximumOffset = precedingRows + lastRow + padding - viewport
        XCTAssertEqual(maximumOffset, precedingRows)
        XCTAssertEqual(WordListRowSnapping.bottomPadding(viewportHeight: 100, lastRowHeight: 300), 0)
    }

    @MainActor
    func testWordListDragTargetsSnapToRowsAtBothWidths() throws {
        let words = (1...30).map { index in
            WordCard(id: index, text: "word \(index)", meaning: "意味", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
        for width: CGFloat in [320, 393] {
            _ = try renderedWordList(words: words, displayMode: .list, width: width, redSheetEnabled: true) { root in
                let scroll = try XCTUnwrap(self.descendants(of: root).compactMap { $0 as? UIScrollView }
                    .first { $0.contentSize.height > $0.bounds.height && $0.contentSize.height > 1500 })
                XCTAssertTrue(try XCTUnwrap(scroll.delegate).responds(to:
                    #selector(UIScrollViewDelegate.scrollViewWillEndDragging(_:withVelocity:targetContentOffset:))))
                for proposedY: CGFloat in [113, 207, 357] {
                    var target = CGPoint(x: 0, y: proposedY)
                    scroll.delegate?.scrollViewWillEndDragging?(scroll, withVelocity: .zero, targetContentOffset: &target)
                    XCTAssertEqual(target.y.truncatingRemainder(dividingBy: 80), 0, accuracy: 0.5,
                                   "Expected a row boundary for proposed offset \(proposedY), got \(target.y)")
                    XCTAssertLessThanOrEqual(abs(target.y - proposedY), 40.5,
                                             "Must choose the nearest row, not jump back to the first row")
                }
                XCTAssertEqual(scroll.contentSize.height - scroll.bounds.height, 29 * 80, accuracy: 1)
                for offset: CGFloat in [320, 29 * 80] {
                    scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                    let snapshot = try self.settledRedSheetImage(in: root)
                    let sheetTop = try self.firstRedY(in: snapshot)
                    let viewportTop = scroll.convert(scroll.bounds.origin, to: root).y
                    let relativeTop = sheetTop - viewportTop
                    let remainder = relativeTop.truncatingRemainder(dividingBy: 80)
                    XCTAssertLessThanOrEqual(min(abs(remainder), abs(80 - remainder)), 1,
                                             "Red sheet must realign after scrolling, including the final row")
                    let attachment = XCTAttachment(image: snapshot)
                    attachment.name = "Row snapping width \(Int(width)) offset \(Int(offset))"
                    attachment.lifetime = .keepAlways
                    self.add(attachment)
                }
            }
        }
    }

    @MainActor
    private func descendants(of view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { descendants(of: $0) }
    }

    /// CIでは0.5秒後でも整列アニメーションの途中になることがある。
    /// 正解座標を待つのではなく、描画位置が安定してから従来の1pt精度で検査する。
    @MainActor
    private func settledRedSheetImage(in root: UIView) throws -> UIImage {
        let started = Date()
        var previousY: CGFloat?
        var stableSamples = 0
        var image = renderedImage(of: root)
        while Date().timeIntervalSince(started) < 4 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            root.layoutIfNeeded()
            image = renderedImage(of: root)
            let y = try firstRedY(in: image)
            stableSamples = previousY.map { abs($0 - y) < 0.25 } == true ? stableSamples + 1 : 0
            previousY = y
            if Date().timeIntervalSince(started) >= 0.6 && stableSamples >= 3 { return image }
        }
        XCTFail("Red sheet did not settle within 4 seconds")
        return image
    }

    private func firstRedY(in image: UIImage) throws -> CGFloat {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let x = width * 3 / 4
        let y = try XCTUnwrap((0..<height).first { y in
            let i = (y * width + x) * 4
            return pixels[i] > 230 && pixels[i + 1] < 90 && pixels[i + 2] < 100
        })
        return CGFloat(y) / image.scale
    }

    private func redPixelCount(in image: UIImage, rightHalf: Bool) throws -> Int {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let columns = rightHalf ? (width / 2..<width) : (0..<width / 2)
        var count = 0
        for y in 0..<height {
            for x in columns {
                let i = (y * width + x) * 4
                if pixels[i] > 230 && pixels[i + 1] < 90 && pixels[i + 2] < 100 { count += 1 }
            }
        }
        return Int(CGFloat(count) / (image.scale * image.scale))
    }

    /// 意味が2つある単語のカードを描き、両方の意味と両方の品詞が出ることを確かめる。
    @MainActor
    func testStudyCardShowsEveryMeaningAndEveryPartOfSpeech() throws {
        let card = WordCard(
            id: 8,
            text: "light",
            senses: [
                WordSense(meaning: "明かり", partOfSpeech: "noun"),
                WordSense(meaning: "軽い", partOfSpeech: "adjective")
            ],
            sentenceEnglish: "This bag is light.",
            sentenceJapanese: "このかばんは軽い。",
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )
        let content = WordCardContent(card: card)
        XCTAssertEqual(content.partsOfSpeech, [.noun, .adjective])
        XCTAssertEqual(card.meaning, "明かり／軽い")

        let appState = AppState(restoresSession: false)
        let rootView = StudyCardView(card: card, showAnswer: true)
            .padding()
            .environmentObject(appState)
            .environmentObject(appState.designSettings)
        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 620))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }

        let image = renderedImage(of: controller.view)
        XCTAssertGreaterThan(image.size.width, 0)

        let attachment = XCTAttachment(image: image)
        attachment.name = "USL-297 multiple meanings on one card"
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
        displayMode: WordListDisplayMode,
        width: CGFloat = 393,
        redSheetEnabled: Bool = false,
        inspect: ((UIView) throws -> Void)? = nil
    ) throws -> UIImage {
        let appState = AppState(restoresSession: false)
        let rootView = NavigationStack {
            WordListView(previewWords: words, displayMode: displayMode, previewRedSheetEnabled: redSheetEnabled)
        }
        .environmentObject(appState)
        .environmentObject(appState.designSettings)
        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }
        try inspect?(controller.view)
        let image = renderedImage(of: controller.view)
        return image
    }

    func testWordRecordUsesExampleFromLowerPriorityMeaning() throws {
        let json = """
        {
          "id": 7,
          "word_text": "run",
          "word_meanings": [
            {
              "id": 1,
              "priority": 1,
              "part_of_speech_en": "verb",
              "definition_jp": "経営する",
              "example_contents": []
            },
            {
              "id": 2,
              "priority": 2,
              "part_of_speech_en": "verb",
              "definition_jp": "走る",
              "example_contents": [
                {
                  "id": 200,
                  "sentence_en": "I run every morning.",
                  "sentence_jp": "私は毎朝走ります。",
                  "image_asset_path": "content-images/simple/0000-0499/200.webp",
                  "audio_asset_path": "content-audio/example/simple/0000-0499/200.mp3"
                }
              ]
            }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.sentenceEnglish, "I run every morning.")
        XCTAssertEqual(card.sentenceJapanese, "私は毎朝走ります。")
        XCTAssertEqual(card.imageAssetPath, "content-images/simple/0000-0499/200.webp")
        XCTAssertEqual(card.audioAssetPath, "content-audio/example/simple/0000-0499/200.mp3")
    }

    func testWordRecordListsEveryMeaningInPriorityOrder() throws {
        let json = """
        {
          "id": 8,
          "word_text": "light",
          "word_meanings": [
            {
              "id": 2,
              "priority": 2,
              "part_of_speech_en": "adjective",
              "definition_jp": "軽い",
              "example_contents": []
            },
            {
              "id": 1,
              "priority": 1,
              "part_of_speech_en": "noun",
              "definition_jp": "明かり",
              "example_contents": []
            }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.senses.map(\.meaning), ["明かり", "軽い"])
        XCTAssertEqual(card.meaning, "明かり／軽い")
        XCTAssertEqual(card.partsOfSpeech, ["noun", "adjective"])
        XCTAssertEqual(card.partOfSpeech, "noun")
    }

    func testSingleMeaningCardKeepsItsMeaningUnchanged() throws {
        let json = """
        {
          "id": 9,
          "word_text": "apple",
          "word_meanings": [
            {
              "id": 1,
              "priority": 1,
              "part_of_speech_en": "noun",
              "definition_jp": "りんご",
              "example_contents": []
            }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.meaning, "りんご")
        XCTAssertEqual(card.senses.count, 1)
    }

    func testOverrideReplacesEveryMeaningWithOneString() {
        let card = WordCard(
            id: 8,
            text: "light",
            senses: [
                WordSense(meaning: "明かり", partOfSpeech: "noun"),
                WordSense(meaning: "軽い", partOfSpeech: "adjective")
            ],
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )

        let override = UserWordOverride(
            userId: "user-8",
            wordId: 8,
            wordText: nil,
            definitionJapanese: "明かり・軽い",
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil
        )

        let overridden = card.applying(override)
        XCTAssertEqual(overridden.senses.map(\.meaning), ["明かり・軽い"])
        XCTAssertEqual(overridden.meaning, "明かり・軽い")

        let empty = UserWordOverride(
            userId: "user-8",
            wordId: 8,
            wordText: nil,
            definitionJapanese: nil,
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil
        )
        XCTAssertEqual(card.applying(empty).meaning, "明かり／軽い")
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
    func canManage(_ deck: Deck) -> Bool { false }
    var supportsDeckReordering: Bool { false }
    var supportsDeckFileTransfer: Bool { false }
    func installBundledDeck(_ file: DeckFile) async throws -> DeckInstallOutcome { throw LocalStudyError.deckNotFound }
    func deleteDeck(id: Int) async throws { throw LocalStudyError.deckNotFound }
}
