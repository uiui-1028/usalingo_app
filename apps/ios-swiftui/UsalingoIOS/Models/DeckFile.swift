import Foundation

/// デッキJSON（docs/plans/learning-tab-guest-first-plan.md 4.3）の読み書きエラー。
/// T-4 の読み込み失敗時に理由を画面へ出すため、日本語の説明を持つ。
enum DeckFileError: LocalizedError, Equatable {
    case unreadable
    case unsupportedFormatVersion(Int)
    case emptyDeckId
    case duplicateCardIds([Int])

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "デッキJSONの形式が正しくありません。"
        case .unsupportedFormatVersion(let version):
            return "このアプリが対応していない formatVersion \(version) です。対応している版は \(DeckFile.supportedFormatVersion) です。"
        case .emptyDeckId:
            return "deckId が空です。"
        case .duplicateCardIds(let ids):
            return "カードのIDが重複しています: \(ids.map(String.init).joined(separator: ", "))"
        }
    }
}

/// 同梱サンプルデッキと、読み込み・書き出しの両方で使うデッキJSONの形式。
/// 学習進捗はこのJSONに含めない。進捗は端末側で別管理する。
struct DeckFile: Codable, Equatable {
    static let supportedFormatVersion = 1

    let formatVersion: Int
    let deckId: String
    let deckName: String
    let description: String?
    let cards: [DeckFileCard]

    static func decode(from data: Data) throws -> DeckFile {
        let file: DeckFile
        do {
            file = try JSONDecoder().decode(DeckFile.self, from: data)
        } catch {
            throw DeckFileError.unreadable
        }
        try file.validate()
        return file
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func validate() throws {
        guard formatVersion == Self.supportedFormatVersion else {
            throw DeckFileError.unsupportedFormatVersion(formatVersion)
        }
        guard !deckId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeckFileError.emptyDeckId
        }
        var seen = Set<Int>()
        var duplicates = Set<Int>()
        for card in cards where !seen.insert(card.id).inserted {
            duplicates.insert(card.id)
        }
        guard duplicates.isEmpty else {
            throw DeckFileError.duplicateCardIds(duplicates.sorted())
        }
    }
}

/// 例文・品詞・タグは任意項目。欠けていても学習が回るようにすべて Optional で受ける。
struct DeckFileCard: Codable, Equatable {
    let id: Int
    let text: String
    let meaning: String
    let partOfSpeech: String?
    let sentenceEnglish: String?
    let sentenceJapanese: String?
    let imageAssetPath: String?
    let audioAssetPath: String?
    let tags: [String]?
}
