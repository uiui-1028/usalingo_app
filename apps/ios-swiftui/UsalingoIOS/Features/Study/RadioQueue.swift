import Foundation

/// 音源再生で1語ぶんに流すもの。
enum RadioStep: Equatable {
    /// 英単語の収録音源。
    case word(URL)
    /// 日本語訳。収録音源が無いので端末の読み上げを使う。
    case meaning(String)
    /// 英語例文の収録音源。
    case sentence(URL)
}

/// ラジオの再生順。デッキを一周したら混ぜ直して、また先頭から流し続ける。
///
/// 単語か例文の収録音源が欠けているカードは、無音の間ができてしまうので最初から外す。
struct RadioQueue {
    /// 流せるカードだけを、この周の順に並べたもの。
    private(set) var cards: [WordCard]
    private(set) var index = 0
    private let shufflesEachLap: Bool
    private let sourceCards: [WordCard]
    /// ひとつ前までに通った周。逆向きへ戻るときも、画面で見えていた並びを変えない。
    private var previousLaps: [[WordCard]] = []
    /// 次の周は先に決めておく。最後の札の下に見えていた札と、実際に次に鳴る札を一致させる。
    private var futureLaps: [[WordCard]] = []

    /// - Parameter shufflesEachLap: 毎周混ぜるか。テストだけ `false` にする。
    init(cards: [WordCard], shufflesEachLap: Bool = true) {
        let playable = cards.filter { $0.wordAudioURL != nil && $0.audioURL != nil }
        self.shufflesEachLap = shufflesEachLap
        self.sourceCards = playable
        let firstLap = shufflesEachLap ? playable.shuffled() : playable
        self.cards = firstLap
        if !firstLap.isEmpty {
            self.futureLaps = [Self.makeLap(from: playable, after: firstLap.last?.id, shuffled: shufflesEachLap)]
        }
    }

    var isEmpty: Bool { cards.isEmpty }

    var current: WordCard? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    /// ひとつ前のカード。カルーセルで上に並べる。先頭なら最後のカードを見せる。
    var previous: WordCard? {
        guard !cards.isEmpty else { return nil }
        if index > 0 { return cards[index - 1] }
        return previousLaps.last?.last ?? cards.last
    }

    /// 次のカード。次の周まで先に決めてあるため、画面で見えた札がそのまま次に鳴る。
    var next: WordCard? {
        guard !cards.isEmpty else { return nil }
        if index + 1 < cards.count { return cards[index + 1] }
        return futureLaps.first?.first ?? cards.first
    }

    /// 現在位置から数えた札。画面外の札も先に並べ、ドラッグ中に途中で途切れさせない。
    func card(relativeOffset: Int) -> WordCard? {
        guard !cards.isEmpty else { return nil }
        var copy = self
        if relativeOffset > 0 {
            for _ in 0..<relativeOffset { copy.advance() }
        } else if relativeOffset < 0 {
            for _ in 0..<(-relativeOffset) { copy.rewind() }
        }
        return copy.current
    }

    /// いまのカードで流すもの。訳が空のカードは読み上げを飛ばす。
    var currentSteps: [RadioStep] {
        guard let card = current, let wordAudio = card.wordAudioURL, let sentenceAudio = card.audioURL else {
            return []
        }
        let meaning = card.primaryMeaning.trimmingCharacters(in: .whitespacesAndNewlines)
        return [.word(wordAudio)] + (meaning.isEmpty ? [] : [.meaning(meaning)]) + [.sentence(sentenceAudio)]
    }

    mutating func advance() {
        guard !cards.isEmpty else { return }
        guard cards.count > 1 else { return }
        guard index + 1 >= cards.count else {
            index += 1
            return
        }
        previousLaps.append(cards)
        if previousLaps.count > 2 { previousLaps.removeFirst() }
        cards = futureLaps.isEmpty
            ? Self.makeLap(from: sourceCards, after: cards.last?.id, shuffled: shufflesEachLap)
            : futureLaps.removeFirst()
        index = 0
        prepareNextLap()
    }

    mutating func rewind() {
        guard !cards.isEmpty else { return }
        guard cards.count > 1 else { return }
        guard index == 0 else {
            index -= 1
            return
        }
        guard let previousLap = previousLaps.popLast() else {
            index = cards.count - 1
            return
        }
        futureLaps.insert(cards, at: 0)
        cards = previousLap
        index = cards.count - 1
    }

    private mutating func prepareNextLap() {
        guard futureLaps.isEmpty, !cards.isEmpty else { return }
        futureLaps.append(Self.makeLap(from: sourceCards, after: cards.last?.id, shuffled: shufflesEachLap))
    }

    /// 周の変わり目で同じカードが続けて鳴らないよう、先頭だけずらす。
    private static func makeLap(from source: [WordCard], after previousID: WordCard.ID?, shuffled: Bool) -> [WordCard] {
        guard shuffled, source.count > 1 else { return source }
        var lap = source.shuffled()
        if lap.first?.id == previousID {
            lap.swapAt(0, 1)
        }
        return lap
    }
}
