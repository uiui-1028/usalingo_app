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

    /// - Parameter shufflesEachLap: 毎周混ぜるか。テストだけ `false` にする。
    init(cards: [WordCard], shufflesEachLap: Bool = true) {
        let playable = cards.filter { $0.wordAudioURL != nil && $0.audioURL != nil }
        self.shufflesEachLap = shufflesEachLap
        self.cards = shufflesEachLap ? playable.shuffled() : playable
    }

    var isEmpty: Bool { cards.isEmpty }

    var current: WordCard? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    /// ひとつ前のカード。カルーセルで上に並べる。先頭なら最後のカードを見せる。
    var previous: WordCard? {
        cards.isEmpty ? nil : cards[(index - 1 + cards.count) % cards.count]
    }

    /// 次のカード。カルーセルで下に並べる。
    ///
    /// 周の変わり目では `advance()` が混ぜ直すので、ここで見せた札とは別の札が鳴ることがある。
    var next: WordCard? {
        cards.isEmpty ? nil : cards[(index + 1) % cards.count]
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
        index += 1
        guard index >= cards.count else { return }
        index = 0
        startNewLap()
    }

    mutating func rewind() {
        guard !cards.isEmpty else { return }
        index = index > 0 ? index - 1 : cards.count - 1
    }

    /// 周の変わり目で同じカードが続けて鳴らないよう、先頭だけずらす。
    private mutating func startNewLap() {
        guard shufflesEachLap, cards.count > 1 else { return }
        let previousLast = cards[cards.count - 1].id
        cards.shuffle()
        if cards[0].id == previousLast {
            cards.swapAt(0, 1)
        }
    }
}
