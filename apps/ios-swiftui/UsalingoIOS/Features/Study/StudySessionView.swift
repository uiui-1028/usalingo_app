import SwiftUI

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
    @State private var hasCrossedSwipeThreshold = false
    @State private var showAnswer = false
    @State private var answerAttempt = StudyAnswerAttempt()
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
            header

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            appState.isShellChromeHidden = true
        }
        .onDisappear {
            audioPlaybackService.stop()
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

    private var header: some View {
        HStack(spacing: WireMetrics.spacingL) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.wireIcon(diameter: 44))
            .accessibilityLabel("学習を終える")

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                HStack {
                    Text(cards.isEmpty ? "0 / 0" : "\(min(index + 1, cards.count)) / \(cards.count)")
                    Text(studyMode.title)
                }
                .wireFont(.caption)
                // 進み具合は色ではなく「枠の中がどれだけ塗られたか」で示す。
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair)
                        Capsule()
                            .fill(WireColor.ink)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.top, WireMetrics.spacingM)
        .padding(.bottom, WireMetrics.spacingM)
    }

    private var cardStack: some View {
        ZStack {
            if index + 1 < cards.count {
                StudyCardView(card: cards[index + 1], showAnswer: false)
                    .scaleEffect(0.95)
                    .offset(y: 12)
                    .opacity(0.72)
                    .allowsHitTesting(false)
            }

            StudyCardView(card: cards[index], showAnswer: showAnswer)
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 24)))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            let threshold: CGFloat = 110
                            let crossed = abs(value.translation.width) > threshold
                            if crossed && !hasCrossedSwipeThreshold {
                                HapticFeedbackService.swipeThresholdCrossed()
                            }
                            hasCrossedSwipeThreshold = crossed
                        }
                        .onEnded { value in
                            hasCrossedSwipeThreshold = false
                            let threshold: CGFloat = 110
                            if value.translation.width > threshold {
                                swipe(isCorrect: true)
                            } else if value.translation.width < -threshold {
                                swipe(isCorrect: false)
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture {
                    HapticFeedbackService.tap()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showAnswer.toggle()
                    }
                }
        }
        .padding(.horizontal, 18)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width > threshold {
                        dismiss()
                    }
                }
        )
    }

    @ViewBuilder
    private var actionBar: some View {
        if !isLoading, index < cards.count {
            HStack(spacing: WireMetrics.spacingS) {
                Button {
                    submitAnswer(isCorrect: false)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.wireIcon(diameter: 52))
                .disabled(answerAttempt.isSaving || isUndoingAnswer)
                .accessibilityLabel("不正解")

                toolbar
                    .frame(maxWidth: .infinity)

                Button {
                    submitAnswer(isCorrect: true)
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.wireIcon(diameter: 52, isSelected: true, invertsWhenSelected: true))
                .disabled(answerAttempt.isSaving || isUndoingAnswer)
                .accessibilityLabel("正解")
            }
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.top, WireMetrics.spacingXS)
            .padding(.bottom, WireMetrics.screenPadding)
        }
    }

    private var toolbar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            toolbarButton("tag", label: "タグ", action: tagCurrentCard)
            toolbarButton(
                audioPlaybackService.isPlaying ? "speaker.slash" : "speaker.wave.2",
                label: "音声を再生",
                isDisabled: currentAudioURL == nil,
                action: playCurrentCardAudio
            )
            toolbarButton(
                "arrow.uturn.backward",
                label: "ひとつ戻す",
                isDisabled: answerHistory.isEmpty || answerAttempt.isSaving || isUndoingAnswer,
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
        if let saveErrorMessage, index < cards.count {
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
                .disabled(answerAttempt.isSaving || isUndoingAnswer)
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

    private var progress: CGFloat {
        guard !cards.isEmpty else { return 0 }
        return CGFloat(min(index + 1, cards.count)) / CGFloat(cards.count)
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
            answerAttempt = StudyAnswerAttempt()
            saveErrorMessage = nil
            prefetchUpcomingImages()
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

    private func persistPendingAnswer() async {
        guard let isCorrect = answerAttempt.pendingAnswer,
              index < cards.count else {
            answerAttempt.cancel()
            return
        }
        do {
            let originalCard = cards[index]
            let savedAnswer = try await appState.studyDataSource.saveAnswerWithUndo(
                card: originalCard,
                isCorrect: isCorrect
            )
            cards[index] = originalCard.withLearningProgress(savedAnswer.progress)
            sessionAnswers.append(isCorrect)
            sessionProgresses.append(savedAnswer.progress)
            answerHistory.append(
                AnswerCheckpoint(
                    cardIndex: index,
                    originalCard: originalCard,
                    previousProgress: savedAnswer.previousProgress
                )
            )
            appState.markStudyDataChanged()
            audioPlaybackService.stop()
            index += 1
            prefetchUpcomingImages()
            answerAttempt.succeeded()
            saveErrorMessage = nil
            showAnswer = false
            dragOffset = .zero
        } catch {
            answerAttempt.failed()
            saveErrorMessage = UserFacingError.message(for: error)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                dragOffset = .zero
            }
        }
    }

    private func submitAnswer(isCorrect: Bool) {
        guard index < cards.count, answerAttempt.begin(isCorrect: isCorrect) else { return }
        saveErrorMessage = nil
        let target: CGFloat = isCorrect ? 700 : -700
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = CGSize(width: target, height: 0)
        }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            await persistPendingAnswer()
        }
    }

    private func retryAnswer() {
        guard answerAttempt.beginRetry() else { return }
        Task { await persistPendingAnswer() }
    }

    private func swipe(isCorrect: Bool) {
        submitAnswer(isCorrect: isCorrect)
    }

    private func undo() {
        guard let checkpoint = answerHistory.last,
              !answerAttempt.isSaving,
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
                dragOffset = .zero
            }
            appState.markStudyDataChanged()
        } catch {
            saveErrorMessage = "取り消しを保存できませんでした。もう一度お試しください。"
        }
    }

    private var currentAudioURL: URL? {
        guard index < cards.count else { return nil }
        return cards[index].audioURL
    }

    private func playCurrentCardAudio() {
        guard let currentAudioURL else { return }
        audioPlaybackService.togglePlayback(url: currentAudioURL)
    }

    /// 次にめくる数枚だけを低い優先度で温める。見ない一覧や表紙は取りに行かない。
    private func prefetchUpcomingImages() {
        let urls = cards
            .dropFirst(index + 1)
            .prefix(4)
            .compactMap(\.illustrationURL)
        CardImageCache.prefetch(urls: urls)
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

struct StudyAnswerAttempt {
    private(set) var pendingAnswer: Bool?
    private(set) var isSaving = false

    mutating func begin(isCorrect: Bool) -> Bool {
        guard !isSaving, pendingAnswer == nil else { return false }
        pendingAnswer = isCorrect
        isSaving = true
        return true
    }

    mutating func beginRetry() -> Bool {
        guard !isSaving, pendingAnswer != nil else { return false }
        isSaving = true
        return true
    }

    mutating func succeeded() {
        pendingAnswer = nil
        isSaving = false
    }

    mutating func failed() {
        isSaving = false
    }

    mutating func cancel() {
        pendingAnswer = nil
        isSaving = false
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
