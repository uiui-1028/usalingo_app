import Foundation

// 学習タブの「コンセプト」まわりの定義。
//
// デザインタブと同じ立ち位置で、画面の並びと言葉づかいを先に固めるための
// 表示専用の実装。選んだ内容は保存も送信もしない。
// 例外は `StudyMode` だけで、これは既存の学習画面へそのまま渡る。

/// 出題形式（A-2）。学習画面の出し分けはまだ無いので、選んでも表示だけが変わる。
enum ConceptAnswerFormat: String, CaseIterable, Identifiable {
    case englishToJapanese
    case japaneseToEnglish
    case listening
    case cloze
    case spelling

    var id: String { rawValue }

    var title: String {
        switch self {
        case .englishToJapanese: return "英 → 日"
        case .japaneseToEnglish: return "日 → 英"
        case .listening: return "音だけ聞く"
        case .cloze: return "例文の穴うめ"
        case .spelling: return "つづりを書く"
        }
    }
}

/// 分量（A-3）。終わりが見えることが目的なので、開始ボタンに結果を書く。
enum ConceptVolume: String, CaseIterable, Identifiable {
    case threeMinutes
    case tenCards
    case twentyCards
    case wholeDeck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeMinutes: return "3分だけ"
        case .tenCards: return "10枚"
        case .twentyCards: return "20枚"
        case .wholeDeck: return "ぜんぶ1周"
        }
    }

    /// 開始ボタンに出す見込み。時間はサンプル値。
    var startSummary: String {
        switch self {
        case .threeMinutes: return "約3分"
        case .tenCards: return "10枚・約4分"
        case .twentyCards: return "20枚・約8分"
        case .wholeDeck: return "全部・約20分"
        }
    }
}

/// 絞り込み（A-4）。複数選べる。品詞・タグ・SRSレベルはどれも既存データで作れる。
enum ConceptNarrowing: String, CaseIterable, Identifiable {
    case verbOnly
    case taggedPartFive
    case lowLevel
    case recentlyAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verbOnly: return "品詞：動詞"
        case .taggedPartFive: return "タグ：Part5"
        case .lowLevel: return "レベル Lv1–2"
        case .recentlyAdded: return "追加したのが新しい順"
        }
    }
}

/// 例文のトーン（A-6）。1語が例文を1つしか持てないため、いまは選択の見た目だけ。
enum ConceptSentenceTone: String, CaseIterable, Identifiable {
    case simple
    case business
    case horror
    case anime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "シンプル"
        case .business: return "ビジネス"
        case .horror: return "ホラー"
        case .anime: return "二次元"
        }
    }
}

/// イラストの画風（A-6）。こちらも1語が画像を1つしか持てないため、選択の見た目だけ。
enum ConceptIllustrationStyle: String, CaseIterable, Identifiable {
    case realistic
    case anime
    case animal
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .realistic: return "リアル"
        case .anime: return "二次元"
        case .animal: return "動物"
        case .none: return "絵なし"
        }
    }
}

/// 保存したコンセプト（A-5）。保存先はまだ無いので、並びを見るためのサンプル。
struct SavedConcept: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String

    static let samples: [SavedConcept] = [
        SavedConcept(id: "night", title: "寝る前10枚", summary: "TOEIC基礎 / 復習 / 日→英"),
        SavedConcept(id: "weak", title: "苦手つぶし5分", summary: "全デッキ / 苦手 / 英→日"),
        SavedConcept(id: "listen", title: "音だけ通し", summary: "日常英会話 / 全単語 / 音だけ")
    ]
}

/// デッキの周辺情報（B-2 / B-3 / B-4 / B-8 / B-12）のうち、
/// いまのデータ層からは出せない値。デッキIDから決まるので、開くたびに数字が動くことはない。
///
/// 新規と復習の件数だけは実データがあるので、この構造体には持たせない。
struct DeckDisplaySample {
    let coverSymbol: String
    let totalCount: Int
    let masteredCount: Int
    let learningCount: Int
    let weakCount: Int
    let previewWords: [String]

    /// まだ一度も出していない枚数。4つのチップの合計が総枚数と合うようにする。
    var untouchedCount: Int {
        max(0, totalCount - masteredCount - learningCount - weakCount)
    }

    var masteryRatio: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(masteredCount) / Double(totalCount))
    }

    var masteryPercentText: String {
        "\(Int((masteryRatio * 100).rounded()))%"
    }

    private static let coverSymbols = ["diamond", "triangle", "circle", "square", "hexagon", "seal"]

    private static let wordPools: [[String]] = [
        ["invoice", "deadline", "negotiate", "revenue", "warehouse"],
        ["reserve", "receipt", "boarding", "aisle", "refund"],
        ["agenda", "postpone", "attendee", "briefly", "handout"]
    ]

    /// 「最近学習した単語」（D-3）に出すサンプル。
    static let recentWordsSample = ["invoice", "deadline", "negotiate", "revenue"]

    private static let profiles: [(total: Int, mastered: Int, learning: Int, weak: Int)] = [
        (55, 20, 18, 5),
        (40, 25, 11, 2),
        (24, 2, 9, 7)
    ]

    static func forDeck(id: Int) -> DeckDisplaySample {
        let slot = abs(id) % profiles.count
        let profile = profiles[slot]
        return DeckDisplaySample(
            coverSymbol: coverSymbols[abs(id) % coverSymbols.count],
            totalCount: profile.total,
            masteredCount: profile.mastered,
            learningCount: profile.learning,
            weakCount: profile.weak,
            previewWords: wordPools[slot]
        )
    }
}
