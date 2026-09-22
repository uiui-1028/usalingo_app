import Foundation

/// 英→日の5択。選択肢は出題時に一度だけ作り、答え合わせまで同じ並びを保つ。
struct FiveChoiceGame {
    struct Question {
        let card: WordCard
        let choices: [WordCard]
        var correctIndex: Int { choices.firstIndex { $0.id == card.id }! }
    }

    private let cards: [WordCard]
    private let candidates: [Candidate]
    private let shufflesOrder: Bool
    private var nextCardIndex = 0
    private(set) var question: Question?
    private(set) var selectedIndex: Int?
    private(set) var answeredCount = 0
    private(set) var skippedCount = 0

    var isFinished: Bool { question == nil }
    var isRevealed: Bool { selectedIndex != nil }

    init(cards: [WordCard], candidates: [WordCard], shufflesOrder: Bool = true) {
        var seen = Set<Int>()
        let uniqueCards = cards.filter { seen.insert($0.id).inserted }
        self.cards = shufflesOrder ? uniqueCards.shuffled() : uniqueCards
        self.shufflesOrder = shufflesOrder
        self.candidates = candidates.map(Candidate.init).filter(\.isUsable)
        prepareQuestion()
    }

    /// 公開されている全単語ではなく、学習タブに追加済みのデッキだけを読む。
    static func load(deckId: Int, source: any StudyDataSource) async throws -> FiveChoiceGame {
        let decks = try await source.fetchDecks()
        guard decks.contains(where: { $0.id == deckId }) else { throw LocalStudyError.deckNotFound }
        var cards: [WordCard] = []
        var candidates: [WordCard] = []
        for deck in decks {
            try Task.checkCancellation()
            let deckCards = try await source.fetchCards(deckId: deck.id)
            if deck.id == deckId { cards = deckCards }
            candidates.append(contentsOf: deckCards)
        }
        try Task.checkCancellation()
        return FiveChoiceGame(cards: cards, candidates: candidates)
    }

    /// 1問につき最初の回答だけを返す。無効な番号や連打では学習記録を増やさない。
    mutating func answer(at index: Int) -> Bool? {
        guard let question, selectedIndex == nil, question.choices.indices.contains(index) else { return nil }
        selectedIndex = index
        answeredCount += 1
        return index == question.correctIndex
    }

    mutating func advance() {
        guard isRevealed else { return }
        selectedIndex = nil
        prepareQuestion()
    }

    private mutating func prepareQuestion() {
        question = nil
        while nextCardIndex < cards.count {
            let card = cards[nextCardIndex]
            nextCardIndex += 1
            let correct = Candidate(card: card)
            guard correct.isUsable else {
                skippedCount += 1
                continue
            }

            var picked = [correct]
            let pool = shufflesOrder ? candidates.shuffled() : candidates
            for candidate in pool {
                guard !candidate.conflicts(with: correct),
                      !picked.contains(where: {
                          $0.card.id == candidate.card.id || $0.card.wordId == candidate.card.wordId
                              || $0.word == candidate.word || $0.meanings == candidate.meanings
                      }) else { continue }
                picked.append(candidate)
                if picked.count == 5 { break }
            }
            guard picked.count == 5 else {
                skippedCount += 1
                continue
            }
            let choices = picked.map(\.card)
            question = Question(card: card, choices: shufflesOrder ? choices.shuffled() : choices)
            return
        }
    }

    private struct Candidate {
        let card: WordCard
        let word: String
        let meanings: Set<String>
        let synonymWords: Set<String>
        let synonymMeanings: Set<String>

        var isUsable: Bool { !word.isEmpty && !meanings.isEmpty }

        init(card: WordCard) {
            self.card = card
            word = Self.normalized(card.text)
            meanings = Self.meaningKeys(card.meaning)
            synonymWords = Set(card.synonyms.map { Self.normalized($0.word) }.filter { !$0.isEmpty })
            synonymMeanings = card.synonyms.reduce(into: Set<String>()) {
                $0.formUnion(Self.meaningKeys($1.meaning))
            }
        }

        func conflicts(with other: Candidate) -> Bool {
            // ponytail: 表現の異なる同義語の完全判定はしない。必要なら確認済み候補データを追加する。
            card.id == other.card.id || card.wordId == other.card.wordId || word == other.word
                || !meanings.isDisjoint(with: other.meanings)
                || synonymWords.contains(other.word) || other.synonymWords.contains(word)
                || !synonymMeanings.isDisjoint(with: other.meanings)
                || !other.synonymMeanings.isDisjoint(with: meanings)
        }

        private static func normalized(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: .whitespacesAndNewlines).joined()
        }

        private static func meaningKeys(_ text: String) -> Set<String> {
            Set(text.components(separatedBy: CharacterSet(charactersIn: "／/、,，;；\n"))
                .map(normalized).filter { !$0.isEmpty })
        }
    }
}
