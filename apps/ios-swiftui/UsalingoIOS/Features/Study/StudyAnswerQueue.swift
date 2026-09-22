import SwiftUI

/// 保存待ちの回答を投入順に並べる行列。
///
/// 以前は「保存が終わるまで次の回答を受け付けない」作りだったため、通信のたびに
/// スワイプが塞がっていた。ここでは投入は常に成功させ、詰まるのは保存側だけにする。
struct StudyAnswerQueue {
    struct PendingAnswer {
        let cardIndex: Int
        let card: WordCard
        let isCorrect: Bool
        let attempt = AnswerSaveAttempt()
    }

    private(set) var pending: [PendingAnswer] = []
    private(set) var isDraining = false

    var isEmpty: Bool { pending.isEmpty }
    var next: PendingAnswer? { pending.first }

    mutating func enqueue(cardIndex: Int, card: WordCard, isCorrect: Bool) {
        pending.append(PendingAnswer(cardIndex: cardIndex, card: card, isCorrect: isCorrect))
    }

    /// 排出役は1本だけ立てる。すでに走っていれば新しい回答は既存のループが拾う。
    mutating func beginDraining() -> Bool {
        guard !isDraining, !pending.isEmpty else { return false }
        isDraining = true
        return true
    }

    mutating func completeFirst() {
        guard !pending.isEmpty else { return }
        pending.removeFirst()
    }

    mutating func endDraining() {
        isDraining = false
    }

    /// 実行中の保存を終えてから、未送信の直前の判定だけを取り消す。
    mutating func removeLast(cardIndex: Int) {
        guard !isDraining, pending.last?.cardIndex == cardIndex else { return }
        pending.removeLast()
    }

    mutating func reset() {
        pending.removeAll()
        isDraining = false
    }
}

/// 溜まった回答を投入順に保存する。排出役は常に1本だけで、走っている間に積まれた
/// 回答も同じループが拾う。UI はこの完了を待たない。
///
/// 学習カードとマッチングで違うのは保存直後の後始末だけなので、そこだけ
/// `onSaved` で受け取り、行列の進め方と失敗時の扱いはここに一本化する。
@MainActor
func drainStudyAnswerQueue(
    _ queue: Binding<StudyAnswerQueue>,
    appState: AppState,
    saveErrorMessage: Binding<String?>,
    onSaved: @escaping (StudyAnswerQueue.PendingAnswer, SavedAnswer) -> Void = { _, _ in }
) {
    guard queue.wrappedValue.beginDraining() else { return }
    Task {
        while let pending = queue.wrappedValue.next {
            do {
                let savedAnswer = try await appState.studyDataSource.saveAnswerWithUndo(
                    card: pending.card,
                    isCorrect: pending.isCorrect
                )
                onSaved(pending, savedAnswer)
                queue.wrappedValue.completeFirst()
                appState.markStudyDataChanged()
                saveErrorMessage.wrappedValue = nil
            } catch {
                // 失敗した回答は先頭に残す。「もう一度保存」でここから再開する。
                saveErrorMessage.wrappedValue = UserFacingError.message(for: error)
                break
            }
        }
        queue.wrappedValue.endDraining()
    }
}
