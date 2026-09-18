import XCTest
import SwiftUI
import UIKit
@testable import UsalingoIOS

final class WordCardTests: XCTestCase {
    @MainActor
    func testAppStateKeepsLocalStudySourceAfterAuthentication() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("usalingo-source-selection-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let local = LocalStudyDataSource(directoryURL: directory)
        let state = AppState(
            restoresSession: false,
            localStudy: local
        )

        XCTAssertTrue(state.studyDataSource is LocalStudyDataSource)

        let session = AuthSession(
            accessToken: "test-access",
            refreshToken: nil,
            expiresAt: nil,
            user: AuthUser(id: "user-293", email: "learner@example.com")
        )
        state.setSession(session)

        XCTAssertTrue(state.studyDataSource is LocalStudyDataSource)
        XCTAssertFalse((state.studyDataSource as AnyObject) === local)

        state.signOut()
        XCTAssertTrue(state.studyDataSource is LocalStudyDataSource)
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
        XCTAssertNil(card.wordAudioURL)
    }

    func testWordRecordUsesPrimaryPronunciationAudio() throws {
        let json = """
        {
          "id": 42,
          "word_text": "apple",
          "word_meanings": [
            { "id": 10, "priority": 1, "definition_jp": "りんご", "example_contents": [] }
          ],
          "word_pronunciations": [
            { "audio_asset_path": "content-audio/word/000002.mp3", "is_primary": false },
            { "audio_asset_path": "content-audio/word/000001.mp3", "is_primary": true }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.wordAudioAssetPath, "content-audio/word/000001.mp3")
        let url = try XCTUnwrap(card.wordAudioURL)
        XCTAssertTrue(url.absoluteString.hasSuffix(
            "/storage/v1/object/public/content-audio/word/000001.mp3"
        ))
        // 利用者の上書きやタグ付けで、単語音声が消えない。
        XCTAssertEqual(card.withTags(["fruit"]).wordAudioAssetPath, card.wordAudioAssetPath)
    }

    func testPrimaryPronunciationWithoutAudioDisablesWordAudio() throws {
        let json = """
        {
          "id": 43,
          "word_text": "a",
          "word_meanings": [
            { "id": 11, "priority": 1, "definition_jp": "ひとつの", "example_contents": [] }
          ],
          "word_pronunciations": [
            { "audio_asset_path": null, "is_primary": true }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertNil(card.wordAudioURL)
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

    @MainActor
    func testRedSheetCheckRendersHiddenRevealedAndMarkedRows() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = LocalStudyDataSource(directoryURL: directory)
        let words = (1...8).map { index in
            WordCard(id: index, cardId: index, text: index == 1 ? "accommodate" : "word \(index)",
                     meaning: "収容する、対応する", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
        for width: CGFloat in [320, 393] {
            let model = RedSheetCheckModel()
            model.start(words: words, source: source) { _ in }
            let hidden = try renderedWordList(words: words, displayMode: .list, width: width, redSheetEnabled: true, check: model)
            model.isAnswerVisible = true
            let revealed = try renderedWordList(words: words, displayMode: .list, width: width, redSheetEnabled: true, check: model)
            XCTAssertGreaterThan(try redPixelCount(in: hidden, rightHalf: true), try redPixelCount(in: revealed, rightHalf: true))
            model.submit(isCorrect: true)
            model.isAnswerVisible = true
            model.submit(isCorrect: false)
            let marked = try renderedWordList(words: words, displayMode: .list, width: width, redSheetEnabled: true, check: model)
            XCTAssertNotEqual(revealed.pngData(), marked.pngData())
            for (name, image) in [("hidden", hidden), ("revealed", revealed), ("marked", marked)] {
                let attachment = XCTAttachment(image: image)
                attachment.name = "Red check \(name) width \(Int(width))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        let largeModel = RedSheetCheckModel()
        largeModel.start(words: words, source: source) { _ in }
        let large = try renderedWordList(words: words, displayMode: .list, width: 320, redSheetEnabled: true,
                                        check: largeModel, dynamicTypeSize: .accessibility1)
        let attachment = XCTAttachment(image: large)
        attachment.name = "Red check large text width 320"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testRedSheetCheckAdvancesScrollsCompletesAndUndoesInSameView() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = LocalStudyDataSource(directoryURL: directory)
        let words = (1...12).map { id in
            WordCard(id: id, cardId: id, text: "word \(id)", meaning: "意味", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        _ = try renderedWordList(words: words, displayMode: .list, redSheetEnabled: true, check: model) { root in
            for index in 0..<10 {
                model.isAnswerVisible = true
                model.submit(isCorrect: index.isMultiple(of: 2))
                RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            }
            let scroll = try XCTUnwrap(self.descendants(of: root).compactMap { $0 as? UIScrollView }
                .first { $0.contentSize.height > 1500 })
            let advanced = try self.settledRedSheetImage(in: root)
            let visibleTop = scroll.contentOffset.y + scroll.adjustedContentInset.top
            XCTAssertGreaterThan(visibleTop, 400)
            XCTAssertLessThanOrEqual(visibleTop, 10 * 80)
            XCTAssertLessThan(10 * 80 - visibleTop, scroll.bounds.height - 200)
            XCTAssertFalse(model.isAnswerVisible)
            let advancedAttachment = XCTAttachment(image: advanced)
            advancedAttachment.name = "Red check automatically advanced to row 11"
            advancedAttachment.lifetime = .keepAlways
            self.add(advancedAttachment)
            for _ in 0..<2 {
                model.isAnswerVisible = true
                model.submit(isCorrect: true)
                RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            }
            XCTAssertTrue(model.isComplete)
            let completed = self.renderedImage(of: root)
            XCTAssertLessThan(try self.redPixelCount(in: completed, rightHalf: true), 5_000)
            let completionAttachment = XCTAttachment(image: completed)
            completionAttachment.name = "Red check completed"
            completionAttachment.lifetime = .keepAlways
            self.add(completionAttachment)
            var undone = false
            Task { await model.undo(); undone = true }
            let deadline = Date().addingTimeInterval(2)
            while !undone && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            XCTAssertTrue(undone)
            XCTAssertEqual(model.index, 11)
            XCTAssertNil(model.answers[12])
            XCTAssertFalse(model.isAnswerVisible)
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
        // 通常範囲の180・270に、上下1行分の50・430を足した範囲。
        XCTAssertEqual(stops, [50, 180, 270, 430])
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: 230, stops: stops), 270)
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: -500, stops: stops), 50)
        XCTAssertEqual(WordListRowSnapping.nearestStop(to: 900, stops: stops), 430)
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
                // 赤シートは画面上部まで広がるため、UIScrollView の自動セーフエリアも含める。
                let topInset = scroll.adjustedContentInset.top
                for proposedY: CGFloat in [113, 207, 357] {
                    var target = CGPoint(x: 0, y: proposedY)
                    scroll.delegate?.scrollViewWillEndDragging?(scroll, withVelocity: .zero, targetContentOffset: &target)
                    XCTAssertEqual((target.y + topInset).truncatingRemainder(dividingBy: 80), 0, accuracy: 0.5,
                                   "Expected a row boundary for proposed offset \(proposedY), got \(target.y)")
                    XCTAssertLessThanOrEqual(abs(target.y - proposedY), 40.5,
                                             "Must choose the nearest row, not jump back to the first row")
                }
                scroll.delegate?.scrollViewDidEndDragging?(scroll, willDecelerate: false)
                XCTAssertEqual(scroll.contentSize.height - scroll.bounds.height + topInset + scroll.adjustedContentInset.bottom, 29 * 80, accuracy: 1)
                for offset: CGFloat in [320, 29 * 80] {
                    scroll.setContentOffset(CGPoint(x: 0, y: offset - scroll.adjustedContentInset.top), animated: false)
                    _ = try self.settledRedSheetImage(in: root)
                    // 初回の全画面レイアウトでナビゲーションの余白が変わったら、その後の座標へ合わせる。
                    scroll.setContentOffset(CGPoint(x: 0, y: offset - scroll.adjustedContentInset.top), animated: false)
                    let snapshot = try self.settledRedSheetImage(in: root)
                    let sheetTop = try self.firstRedY(in: snapshot)
                    let viewportTop = scroll.convert(scroll.bounds.origin, to: root).y + scroll.adjustedContentInset.top
                    XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, offset, accuracy: 1)
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
        check: RedSheetCheckModel? = nil,
        dynamicTypeSize: DynamicTypeSize = .large,
        inspect: ((UIView) throws -> Void)? = nil
    ) throws -> UIImage {
        let appState = AppState(restoresSession: false)
        let rootView = NavigationStack {
            WordListView(previewWords: words, displayMode: displayMode, previewRedSheetEnabled: redSheetEnabled, previewCheck: check)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
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

    /// USL-305: 配信された類義語と語源がカードまで届くことを確かめる。
    /// 以前は表示側がサンプルを当てていたため、利用者は別の単語の値を見ていた。
    func testWordRecordCarriesRealSynonymsAndEtymology() throws {
        let json = """
        {
          "id": 9,
          "word_text": "fast",
          "word_meanings": [
            {
              "id": 1,
              "priority": 1,
              "part_of_speech_en": "adjective",
              "definition_jp": "速い",
              "etymology": "古英語 *fæst*（固い）から。「しっかり動く」→「速い」へ移った。",
              "synonyms": [
                "quick :: すばやい :: 反応や動作の速さ。",
                "rapid :: 急速な :: 変化の速さ。書き言葉でよく使う。"
              ],
              "example_contents": []
            }
          ]
        }
        """

        let record = try JSONDecoder().decode(WordRecord.self, from: Data(json.utf8))
        let card = try XCTUnwrap(record.toCard())

        XCTAssertEqual(card.etymology, "古英語 *fæst*（固い）から。「しっかり動く」→「速い」へ移った。")
        XCTAssertEqual(card.synonyms.map(\.word), ["quick", "rapid"])
        XCTAssertEqual(card.synonyms.first?.meaning, "すばやい")
        XCTAssertEqual(card.synonyms.first?.note, "反応や動作の速さ。")

        let content = WordCardContent(card: card)
        XCTAssertEqual(content.synonyms.map(\.word), ["quick", "rapid"])
        XCTAssertTrue(content.hasSupplements)
    }

    /// USL-305: 類義語も語源も無い単語では、偽の値を出さず裏面を空のままにする。
    func testWordCardWithoutSupplementsShowsNothing() throws {
        let json = """
        {
          "id": 10,
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
        let content = WordCardContent(card: card)

        XCTAssertTrue(content.synonyms.isEmpty)
        XCTAssertNil(content.etymology)
        XCTAssertFalse(content.hasSupplements)
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

    /// USL-309: 品詞が2つある `increase` で、デッキが名詞を主にしたとき、
    /// 名詞が先頭に来て例文もその意味から出し、動詞は副に回る。
    func testStudyCardRecordPutsDeckPrimaryMeaningFirst() throws {
        let card = try XCTUnwrap(increaseCard(primaryMeaningId: 1001))

        XCTAssertEqual(card.senses.map(\.meaning), ["増加", "増加する"])
        XCTAssertEqual(card.primaryMeaning, "増加")
        XCTAssertEqual(card.secondaryMeaning, "増加する")
        let threeSenses = WordCard(
            id: 1, text: "run",
            senses: ["走る", "経営する", "流れる"].map { WordSense(meaning: $0) },
            sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil, audioAssetPath: nil,
            tags: [], learningStatus: nil, learning: nil
        )
        XCTAssertEqual(threeSenses.secondaryMeaning, "経営する, 流れる")
        XCTAssertEqual(card.partOfSpeech, "noun")
        XCTAssertEqual(card.sentenceEnglish, "There was an increase in sales.")
        XCTAssertEqual(card.imageAssetPath, "content-images/simple/1001.webp")
    }

    /// USL-309: `primary_meaning_id` が NULL や別の単語の意味なら、`priority` 順のまま。
    func testStudyCardRecordFallsBackToPriorityWithoutPrimaryMeaning() throws {
        for primaryMeaningId in [nil, 9999] as [Int?] {
            let card = try XCTUnwrap(increaseCard(primaryMeaningId: primaryMeaningId))

            XCTAssertEqual(card.senses.map(\.meaning), ["増加する", "増加"])
            XCTAssertEqual(card.primaryMeaning, "増加する")
            XCTAssertEqual(card.sentenceEnglish, "Prices increase every year.")
        }
    }

    /// USL-309: 主の意味に例文が無くても、副の意味の例文・絵・音を出す。
    func testPrimaryMeaningWithoutExampleKeepsSecondaryExample() throws {
        let card = try XCTUnwrap(increaseCard(primaryMeaningId: 1001, nounHasExample: false))

        XCTAssertEqual(card.primaryMeaning, "増加")
        XCTAssertEqual(card.sentenceEnglish, "Prices increase every year.")
        XCTAssertEqual(card.audioAssetPath, "content-audio/example/simple/2.mp3")
    }

    /// USL-309: 主の意味を大きく、副の意味を小さく出したカードを画像で残す。
    @MainActor
    func testStudyCardShowsPrimaryMeaningLargeAndSecondarySmall() throws {
        let cards = [
            ("verb primary", try XCTUnwrap(increaseCard(primaryMeaningId: 2))),
            ("noun primary", try XCTUnwrap(increaseCard(primaryMeaningId: 1001)))
        ]
        for (name, card) in cards {
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

            let image = renderedImage(of: controller.view)
            window.isHidden = true
            XCTAssertGreaterThan(image.size.width, 0)

            let attachment = XCTAttachment(image: image)
            attachment.name = "USL-309 increase \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// 本番の `increase`（word_id 2）と同じ形。動詞（priority 1）と名詞（priority 2）を持つ。
    private func increaseCard(primaryMeaningId: Int?, nounHasExample: Bool = true) throws -> WordCard? {
        let nounExamples = nounHasExample ? """
        [{ "id": 1001, "sentence_en": "There was an increase in sales.", "sentence_jp": "売上が増加した。",
           "image_asset_path": "content-images/simple/1001.webp",
           "audio_asset_path": "content-audio/example/simple/1001.mp3" }]
        """ : "[]"
        let primary = primaryMeaningId.map(String.init) ?? "null"
        let json = """
        {
          "id": 5055,
          "word_id": 2,
          "sort_order": 2,
          "primary_meaning_id": \(primary),
          "word": {
            "id": 2,
            "word_text": "increase",
            "word_meanings": [
              { "id": 1001, "priority": 2, "part_of_speech_en": "noun", "definition_jp": "増加",
                "example_contents": \(nounExamples) },
              { "id": 2, "priority": 1, "part_of_speech_en": "verb", "definition_jp": "増加する",
                "example_contents": [{ "id": 2, "sentence_en": "Prices increase every year.",
                  "sentence_jp": "物価は毎年上がる。", "image_asset_path": "content-images/simple/2.webp",
                  "audio_asset_path": "content-audio/example/simple/2.mp3" }] }
            ]
          }
        }
        """
        return try JSONDecoder().decode(StudyCardRecord.self, from: Data(json.utf8)).toCard()
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
