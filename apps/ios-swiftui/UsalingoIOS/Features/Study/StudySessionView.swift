import SwiftUI
import UIKit

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    let deck: Deck
    let studyMode: StudyMode

    @State private var cards: [WordCard] = []
    @State private var index = 0
    @State private var isLoading = false
    @State private var loadErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var dragOffset = CGSize.zero
    @State private var hasCrossedRevealThreshold = false
    @State private var hasCrossedCommitThreshold = false
    @State private var showAnswer = false
    @State private var isFlipped = false
    /// ドラッグを横（カード送り）と縦（裏面のスクロール）のどちらに割り当てたか。
    @State private var dragAxis: DragAxis?
    @State private var answerQueue = StudyAnswerQueue()
    @State private var flyawayCards: [FlyawayCard] = []
    @State private var isUndoingAnswer = false
    @State private var editingWord: WordCard?
    @State private var taggingWord: WordCard?
    @State private var sessionAnswers: [Bool] = []
    @State private var sessionProgresses: [LearningProgress] = []
    @State private var answerHistory: [AnswerCheckpoint] = []
    @StateObject private var audioPlaybackService = AudioPlaybackService()

    init(deck: Deck, studyMode: StudyMode = .all) {
        self.deck = deck
        self.studyMode = studyMode
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let loadErrorMessage {
                    StudyStatusView(
                        symbol: "wifi.exclamationmark",
                        title: "カードを読み込めませんでした",
                        message: loadErrorMessage,
                        actionTitle: "もう一度試す"
                    ) {
                        Task { await load() }
                    }
                } else if cards.isEmpty {
                    StudyStatusView(
                        symbol: "rectangle.stack.badge.minus",
                        title: emptyMessage,
                        message: "別の学習モードを選ぶか、デッキに戻ってください。",
                        actionTitle: "デッキに戻る"
                    ) { dismiss() }
                } else if index < cards.count {
                    cardStack
                } else {
                    StudyCompletionView(
                        correctCount: sessionAnswers.filter { $0 }.count,
                        incorrectCount: sessionAnswers.filter { !$0 }.count,
                        studiedCount: sessionAnswers.count,
                        accuracyText: accuracyText,
                        weakCount: weakCount
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            saveFailureBanner
            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: currentCard?.id) {
            playCurrentCardAudioSequence()
        }
        .onChange(of: isFlipped) { _, isFlipped in
            if isFlipped {
                audioPlaybackService.stop()
            }
        }
        .onAppear {
            appState.isShellChromeHidden = true
        }
        .onDisappear {
            audioPlaybackService.stop()
            CardImageCache.stopPrefetching()
            Task { await CardAudioCache.shared.stopPrefetching() }
            appState.isShellChromeHidden = false
        }
        .sheet(item: $editingWord) { word in
            WordEditSheet(word: word) { savedWord in
                if let currentIndex = cards.firstIndex(where: { $0.id == savedWord.id }) {
                    cards[currentIndex] = savedWord
                }
            }
                .presentationDetents([.large])
        }
        .sheet(item: $taggingWord) { word in
            TagSheet(word: word) { savedWord in
                if let currentIndex = cards.firstIndex(where: { $0.id == savedWord.id }) {
                    cards[currentIndex] = savedWord
                }
            }
                .presentationDetents([.medium])
        }
        .task { await load() }
    }

    /// 束の中のカードはすべて同じ寸法・同じ位置に重ねる。順位による拡大縮小も位置差も
    /// つけないので、トップが抜けても次のカードは動かない。交代を待つアニメーションが
    /// 無く、現れた瞬間から捌ける。
    private var cardStack: some View {
        ZStack {
            if index + 1 < cards.count {
                StudyCardView(card: cards[index + 1], showAnswer: false)
                    .allowsHitTesting(false)
                    .zIndex(0)
            }

            StudyCardView(card: cards[index], showAnswer: showAnswer, isFlipped: isFlipped)
                .id(cards[index].id)
                .zIndex(1)
                .backSwipeProtectedRegion()
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 24)))
                // 裏面の ScrollView に横方向のドラッグを食われないよう、同時認識にする。
                // どちらの操作かは動き出しの向きで決め、決めた後は最後まで変えない。
                // 横方向は開示ラインで裏面を出し、指を離さずそのまま確定ラインまで
                // 続ければ、1回のスワイプで回答まで済ませられる。
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if dragAxis == nil {
                                dragAxis = DragAxis(translation: value.translation)
                            }

                            guard dragAxis == .horizontal else { return }
                            dragOffset = value.translation
                            let distance = abs(value.translation.width)

                            let reachedReveal = distance > SwipeThreshold.reveal
                            if reachedReveal && !hasCrossedRevealThreshold {
                                HapticFeedbackService.swipeThresholdCrossed()
                                if !showAnswer {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAnswer = true
                                    }
                                }
                            }
                            hasCrossedRevealThreshold = reachedReveal

                            let reachedCommit = distance > SwipeThreshold.commit
                            if reachedCommit && !hasCrossedCommitThreshold {
                                HapticFeedbackService.swipeThresholdCrossed()
                            }
                            hasCrossedCommitThreshold = reachedCommit
                        }
                        .onEnded { value in
                            let axis = dragAxis
                            dragAxis = nil
                            hasCrossedRevealThreshold = false
                            hasCrossedCommitThreshold = false
                            guard axis == .horizontal else { return }
                            if value.translation.width > SwipeThreshold.commit {
                                swipe(isCorrect: true)
                            } else if value.translation.width < -SwipeThreshold.commit {
                                swipe(isCorrect: false)
                            } else {
                                // 開示ラインを越えて出した裏面は、ここで隠し直さない。
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture {
                    advanceCardFace()
                }

            // 見送ったカードは独立した層で飛ばす。トップカードの入れ替えはこの演出を
            // 待たないので、飛んでいる最中でも次のカードをスワイプできる。
            ForEach(flyawayCards) { item in
                FlyawayCardView(item: item) { finished in
                    flyawayCards.removeAll { $0.id == finished.id }
                }
                .zIndex(2)
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var actionBar: some View {
        if !isLoading, index < cards.count {
            StudyAnswerActionBar(
                incorrectLabel: showAnswer ? "不正解" : "答えを表示。もう一度押すと不正解",
                correctLabel: showAnswer ? "正解" : "答えを表示。もう一度押すと正解",
                isDisabled: isUndoingAnswer,
                onIncorrect: { revealOrSubmitAnswer(isCorrect: false) },
                onCorrect: { revealOrSubmitAnswer(isCorrect: true) }
            ) {
                toolbar
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            toolbarButton("tag", label: "タグ", action: tagCurrentCard)
            audioButton(
                urls: [currentCard?.wordAudioURL, currentCard?.audioURL],
                symbol: "speaker.wave.2",
                label: "単語と例文の音声を再生"
            )
            audioButton(
                urls: [currentCard?.audioURL],
                symbol: "text.bubble",
                label: "例文の音声を再生"
            )
            toolbarButton(
                "arrow.uturn.backward",
                label: "ひとつ戻す",
                isDisabled: answerHistory.isEmpty || !answerQueue.isEmpty || isUndoingAnswer,
                action: undo
            )
            toolbarButton("square.and.pencil", label: "単語を編集", action: editCurrentCard)
        }
        .padding(.horizontal, WireMetrics.spacingM)
        .padding(.vertical, WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage, index < cards.count || !answerQueue.isEmpty {
            // 色相を使わずに異常を示す（破線 + 文言）。
            VStack(spacing: WireMetrics.spacingS) {
                Text("回答を保存できませんでした")
                    .wireFont(.label)
                Text(saveErrorMessage)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                Button("同じ回答をもう一度保存") {
                    retryAnswer()
                }
                .buttonStyle(.wireSecondary)
                .disabled(answerQueue.isDraining || isUndoingAnswer)
            }
            .frame(maxWidth: .infinity)
            .padding(WireMetrics.spacingL)
            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil, dashed: true)
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private func toolbarButton(
        _ symbol: String,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.wireIcon(diameter: 40))
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            cards = try await appState.studyDataSource.fetchStudyQueue(deckId: deck.id, mode: studyMode)
            audioPlaybackService.stop()
            index = 0
            sessionAnswers = []
            sessionProgresses = []
            answerHistory = []
            answerQueue.reset()
            flyawayCards = []
            saveErrorMessage = nil
            prefetchUpcomingMedia()
        } catch {
            cards = []
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }

    private var emptyMessage: String {
        switch studyMode {
        case .newOnly:
            return "新規カードはありません。"
        case .reviewOnly:
            return "復習期限のカードはありません。"
        case .all:
            return "このデッキにはカードがありません。"
        case .weakOnly:
            return "苦手カードはまだありません。"
        }
    }

    /// 溜まった回答を投入順に保存する。排出役は常に1本だけで、走っている間に積まれた
    /// 回答も同じループが拾う。UI はこの完了を待たない。
    private func drainAnswerQueue() {
        guard answerQueue.beginDraining() else { return }
        Task {
            while let pending = answerQueue.next {
                do {
                    let savedAnswer = try await appState.studyDataSource.saveAnswerWithUndo(
                        card: pending.card,
                        isCorrect: pending.isCorrect
                    )
                    if pending.cardIndex < cards.count {
                        cards[pending.cardIndex] = pending.card
                            .withLearningProgress(savedAnswer.progress)
                    }
                    sessionAnswers.append(pending.isCorrect)
                    sessionProgresses.append(savedAnswer.progress)
                    answerHistory.append(
                        AnswerCheckpoint(
                            cardIndex: pending.cardIndex,
                            originalCard: pending.card,
                            previousProgress: savedAnswer.previousProgress
                        )
                    )
                    answerQueue.completeFirst()
                    appState.markStudyDataChanged()
                    saveErrorMessage = nil
                } catch {
                    // 失敗した回答は先頭に残す。「もう一度保存」でここから再開する。
                    saveErrorMessage = UserFacingError.message(for: error)
                    break
                }
            }
            answerQueue.endDraining()
        }
    }

    /// カードの見送りと保存を切り離す。行列へ積んだらすぐ次のカードへ進むので、
    /// 飛ばす演出や通信の完了待ちでスワイプが塞がることはない。
    private func submitAnswer(isCorrect: Bool) {
        guard index < cards.count else { return }
        saveErrorMessage = nil

        let answeredCard = cards[index]
        let target: CGFloat = isCorrect ? 700 : -700
        flyawayCards.append(
            FlyawayCard(
                card: answeredCard,
                showAnswer: showAnswer,
                isFlipped: isFlipped,
                start: dragOffset,
                end: CGSize(width: target, height: dragOffset.height)
            )
        )
        answerQueue.enqueue(cardIndex: index, card: answeredCard, isCorrect: isCorrect)

        audioPlaybackService.stop()
        index += 1
        showAnswer = false
        isFlipped = false
        dragOffset = .zero
        prefetchUpcomingMedia()

        drainAnswerQueue()
    }

    /// タップ1回で1段ずつ進める。回答前→回答表示→裏、裏からは回答表示の表へ戻す。
    /// 回答前には戻さない。
    private func advanceCardFace() {
        HapticFeedbackService.tap()
        withAnimation(.easeInOut(duration: 0.32)) {
            if !showAnswer {
                showAnswer = true
            } else {
                isFlipped.toggle()
            }
        }
    }

    private func retryAnswer() {
        saveErrorMessage = nil
        drainAnswerQueue()
    }

    /// 答えを見ないまま正誤を保存しない。1回目は表示だけ、表示後の2回目で保存する。
    private func revealOrSubmitAnswer(isCorrect: Bool) {
        if showAnswer {
            submitAnswer(isCorrect: isCorrect)
        } else {
            HapticFeedbackService.tap()
            withAnimation(.easeInOut(duration: 0.2)) {
                showAnswer = true
            }
        }
    }

    private func swipe(isCorrect: Bool) {
        submitAnswer(isCorrect: isCorrect)
    }

    private func undo() {
        guard let checkpoint = answerHistory.last,
              answerQueue.isEmpty,
              !isUndoingAnswer else { return }
        Task { await restore(checkpoint) }
    }

    private func restore(_ checkpoint: AnswerCheckpoint) async {
        isUndoingAnswer = true
        defer { isUndoingAnswer = false }
        do {
            guard let cardId = checkpoint.originalCard.cardId else { return }
            try await appState.studyDataSource.restoreLearningProgress(
                cardId: cardId,
                previousProgress: checkpoint.previousProgress
            )

            audioPlaybackService.stop()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                cards[checkpoint.cardIndex] = checkpoint.originalCard
                index = checkpoint.cardIndex
                sessionAnswers.removeLast()
                sessionProgresses.removeLast()
                answerHistory.removeLast()
                showAnswer = false
                isFlipped = false
                dragOffset = .zero
            }
            appState.markStudyDataChanged()
        } catch {
            saveErrorMessage = "取り消しを保存できませんでした。もう一度お試しください。"
        }
    }

    private var currentCard: WordCard? {
        index < cards.count ? cards[index] : nil
    }

    /// 新しいカードが表面で現れたときだけ、単語から例文の順に各音声を1回鳴らす。
    private func playCurrentCardAudioSequence() {
        guard let currentCard, !isFlipped else { return }
        audioPlaybackService.playSequence(
            urls: [currentCard.wordAudioURL, currentCard.audioURL].compactMap { $0 }
        )
    }

    /// 渡した順に続けて鳴らす。押し始めの1本が鳴っている間だけ停止の見た目にし、
    /// もう一度押すと途中でも止める。鳴らせる音声が1本も無いカードでは押せない。
    private func audioButton(urls: [URL?], symbol: String, label: String) -> some View {
        let queue = urls.compactMap { $0 }
        let isPlayingThis = audioPlaybackService.playingURL != nil
            && audioPlaybackService.playingURL == queue.first
        return toolbarButton(
            isPlayingThis ? "speaker.slash" : symbol,
            label: label,
            isDisabled: queue.isEmpty
        ) {
            guard !queue.isEmpty else { return }
            if isPlayingThis {
                audioPlaybackService.stop()
            } else {
                audioPlaybackService.playSequence(urls: queue)
            }
        }
    }

    /// 現在のカードから数枚先までを温める。1枚消費するたびに窓が1つ先へずれるので、
    /// 常に読み込み済みの控えが残る。取得済みのものは各キャッシュ側で弾かれる。
    /// 音声も同じ窓で先に取っておき、電波が切れても学習を続けられるようにする。
    private func prefetchUpcomingMedia() {
        let upcoming = cards
            .dropFirst(index)
            .prefix(CardImageCache.prefetchWindow)
        CardImageCache.prefetch(urls: upcoming.compactMap(\.illustrationURL))
        let audioURLs = upcoming.flatMap { [$0.wordAudioURL, $0.audioURL].compactMap { $0 } }
        Task { await CardAudioCache.shared.prefetch(urls: audioURLs) }
    }

    private func editCurrentCard() {
        guard index < cards.count else { return }
        editingWord = cards[index]
    }

    private func tagCurrentCard() {
        guard index < cards.count else { return }
        taggingWord = cards[index]
    }

    private var accuracyText: String {
        guard !sessionAnswers.isEmpty else { return "0%" }
        let correctCount = sessionAnswers.filter { $0 }.count
        let accuracy = Double(correctCount) / Double(sessionAnswers.count) * 100
        return "\(Int(accuracy.rounded()))%"
    }

    private var weakCount: Int {
        sessionProgresses.filter(\.isWeak).count
    }

}

/// 学習中の「不正解・補助操作・正解」を同じ見た目と配置で並べる共通バー。
struct StudyAnswerActionBar<Toolbar: View>: View {
    let correctSymbol: String
    let incorrectLabel: String
    let correctLabel: String
    let isDisabled: Bool
    let onIncorrect: () -> Void
    let onCorrect: () -> Void
    @ViewBuilder let toolbar: Toolbar

    init(
        correctSymbol: String = "checkmark",
        incorrectLabel: String = "不正解",
        correctLabel: String = "正解",
        isDisabled: Bool = false,
        onIncorrect: @escaping () -> Void,
        onCorrect: @escaping () -> Void,
        @ViewBuilder toolbar: () -> Toolbar
    ) {
        self.correctSymbol = correctSymbol
        self.incorrectLabel = incorrectLabel
        self.correctLabel = correctLabel
        self.isDisabled = isDisabled
        self.onIncorrect = onIncorrect
        self.onCorrect = onCorrect
        self.toolbar = toolbar()
    }

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button(action: onIncorrect) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.wireIcon(diameter: 52))
            .disabled(isDisabled)
            .accessibilityLabel(incorrectLabel)

            toolbar

            Button(action: onCorrect) {
                Image(systemName: correctSymbol)
            }
            .buttonStyle(.wireIcon(diameter: 52, isSelected: true, invertsWhenSelected: true))
            .disabled(isDisabled)
            .accessibilityLabel(correctLabel)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.top, WireMetrics.spacingXS)
        .padding(.bottom, WireMetrics.screenPadding)
        .backSwipeProtectedRegion()
    }
}

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

/// 横スワイプの目盛りは2段。開示ラインで裏面を出し、指はそのまま。確定ラインまで
/// 滑らせて離したときだけ正誤として保存する。
private enum SwipeThreshold {
    static let reveal: CGFloat = 60
    static let commit: CGFloat = 130
}

/// ドラッグの向き。動き出しの成分が大きいほうへ倒し、その操作だけを通す。
private enum DragAxis {
    case horizontal
    case vertical

    /// 動き出しの数ポイントは指のぶれで向きが定まらないので、
    /// 一定距離を超えるまで判定を保留する。
    init?(translation: CGSize) {
        guard hypot(translation.width, translation.height) >= 8 else { return nil }
        self = abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical
    }
}

/// 見送ったカードを飛ばすためだけの控え。トップカードとは別の層に置くので、
/// この演出が終わるのを待たずに次のカードを操作できる。
private struct FlyawayCard: Identifiable {
    let id = UUID()
    let card: WordCard
    let showAnswer: Bool
    let isFlipped: Bool
    let start: CGSize
    let end: CGSize
}

private struct FlyawayCardView: View {
    let item: FlyawayCard
    let onFinished: (FlyawayCard) -> Void

    @State private var offset: CGSize?

    var body: some View {
        let current = offset ?? item.start
        StudyCardView(card: item.card, showAnswer: item.showAnswer, isFlipped: item.isFlipped)
            .offset(current)
            .rotationEffect(.degrees(Double(current.width / 24)))
            .opacity(offset == nil ? 1 : 0)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeIn(duration: 0.2)) {
                    offset = item.end
                } completion: {
                    onFinished(item)
                }
            }
    }
}

private struct AnswerCheckpoint {
    let cardIndex: Int
    let originalCard: WordCard
    let previousProgress: LearningProgress?
}

private struct StudyStatusView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        WireCard {
            VStack(spacing: WireMetrics.spacingM) {
                Image(systemName: symbol)
                    .wireFont(.titleL)
                Text(title)
                    .wireFont(.titleS)
                    .multilineTextAlignment(.center)
                Text(message)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                Button(actionTitle, action: action)
                    .buttonStyle(.wirePrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(WireMetrics.spacingXL)
    }
}

private struct StudyCompletionView: View {
    let correctCount: Int
    let incorrectCount: Int
    let studiedCount: Int
    let accuracyText: String
    let weakCount: Int

    var body: some View {
        VStack(spacing: WireMetrics.spacingL) {
            Image(systemName: "sparkles")
                .wireFont(.titleL)

            VStack(spacing: WireMetrics.spacingXS) {
                Text("学習完了")
                    .wireFont(.titleL)
                Text("今日の学習はここまで。")
                    .wireFont(.caption)
            }

            VStack(spacing: WireMetrics.spacingM) {
                HStack(spacing: WireMetrics.spacingM) {
                    CompletionMetric(title: "正解", value: "\(correctCount)")
                    CompletionMetric(title: "不正解", value: "\(incorrectCount)")
                }
                HStack(spacing: WireMetrics.spacingM) {
                    CompletionMetric(title: "今回学習", value: "\(studiedCount)")
                    CompletionMetric(title: "正答率", value: accuracyText)
                }
                CompletionMetric(title: "苦手", value: "\(weakCount)")
            }
        }
        .padding(WireMetrics.spacingXL)
    }
}

private struct CompletionMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            Text(title)
                .wireFont(.caption)
            Text(value)
                .wireFont(.titleL)
        }
        .frame(maxWidth: .infinity)
        .padding(WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}
