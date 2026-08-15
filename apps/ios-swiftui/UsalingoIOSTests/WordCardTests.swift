import XCTest
@testable import UsalingoIOS

final class WordCardTests: XCTestCase {
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
}
