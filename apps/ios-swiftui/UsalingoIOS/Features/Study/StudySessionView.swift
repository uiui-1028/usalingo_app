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
    @State private var showAnswer = false
    @State private var answerAttempt = StudyAnswerAttempt()
    @State private var isUndoingAnswer = false
    @State private var editingWord: WordCard?
    @State private var taggingWord: WordCard?
    @State private var sessionAnswers: [Bool] = []
    @State private var sessionProgresses: [LearningProgress] = []
    @State private var answerHistory: [AnswerCheckpoint] = []
    @StateObject private var audioPlaybackService = AudioPlaybackService()

    private let studyService = StudyService()

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
            answerControls
            toolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GridBackground())
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
        HStack(spacing: 20) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(AppStyle.ink)
                    .frame(width: 42, height: 42)
                    .background(AppStyle.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(AppStyle.line, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(cards.isEmpty ? "0 / 0" : "\(min(index + 1, cards.count)) / \(cards.count)")
                    Text(studyMode.title)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppStyle.muted)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppStyle.line)
                        Capsule()
                            .fill(AppStyle.accent(designSettings))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
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
                        }
                        .onEnded { value in
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
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showAnswer.toggle()
                    }
                }
        }
        .padding(.horizontal, 18)
    }

    private var toolbar: some View {
        HStack(spacing: 22) {
            toolbarButton("tag", action: tagCurrentCard)
            toolbarButton(
                audioPlaybackService.isPlaying ? "speaker.slash.fill" : "speaker.wave.2",
                isDisabled: currentAudioURL == nil,
                action: playCurrentCardAudio
            )
            toolbarButton(
                "arrow.uturn.backward",
                isDisabled: answerHistory.isEmpty || answerAttempt.isSaving || isUndoingAnswer,
                action: undo
            )
            toolbarButton("square.and.pencil", action: editCurrentCard)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
        .shadow(color: AppStyle.shadow, radius: 0, y: 5)
        .padding(16)
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage, index < cards.count {
            VStack(spacing: 8) {
                Text("回答を保存できませんでした")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppStyle.coral)
                Text(saveErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppStyle.muted)
                    .multilineTextAlignment(.center)
                Button("同じ回答をもう一度保存") {
                    retryAnswer()
                }
                .buttonStyle(.borderedProminent)
                .disabled(answerAttempt.isSaving || isUndoingAnswer)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var answerControls: some View {
        if !isLoading, index < cards.count {
            HStack(spacing: 12) {
                answerButton(title: "不正解", symbol: "xmark", color: AppStyle.coral) {
                    submitAnswer(isCorrect: false)
                }
                answerButton(title: "正解", symbol: "checkmark", color: AppStyle.accent) {
                    submitAnswer(isCorrect: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    private func answerButton(title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: color.opacity(0.30), radius: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(answerAttempt.isSaving || isUndoingAnswer)
    }

    private func toolbarButton(_ symbol: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppStyle.accent(designSettings))
                .frame(width: 48, height: 48)
                .background(AppStyle.background)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppStyle.line)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
    }

    private var progress: CGFloat {
        guard !cards.isEmpty else { return 0 }
        return CGFloat(min(index + 1, cards.count)) / CGFloat(cards.count)
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        loadErrorMessage = nil
        do {
            cards = try await studyService.fetchStudyQueue(deckId: deck.id, mode: studyMode, session: session)
            audioPlaybackService.stop()
            index = 0
            sessionAnswers = []
            sessionProgresses = []
            answerHistory = []
            answerAttempt = StudyAnswerAttempt()
            saveErrorMessage = nil
        } catch {
            cards = []
            loadErrorMessage = error.localizedDescription
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
              let session = appState.session,
              index < cards.count else {
            answerAttempt.cancel()
            return
        }
        do {
            let originalCard = cards[index]
            let savedAnswer = try await studyService.saveAnswerWithUndo(
                card: originalCard,
                isCorrect: isCorrect,
                session: session
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
            answerAttempt.succeeded()
            saveErrorMessage = nil
            showAnswer = false
            dragOffset = .zero
        } catch {
            answerAttempt.failed()
            saveErrorMessage = error.localizedDescription
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
              let session = appState.session,
              !answerAttempt.isSaving,
              !isUndoingAnswer else { return }
        Task { await restore(checkpoint, session: session) }
    }

    private func restore(_ checkpoint: AnswerCheckpoint, session: AuthSession) async {
        isUndoingAnswer = true
        defer { isUndoingAnswer = false }
        do {
            guard let cardId = checkpoint.originalCard.cardId else { return }
            try await studyService.restoreLearningProgress(
                cardId: cardId,
                previousProgress: checkpoint.previousProgress,
                session: session
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
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 38))
                .foregroundStyle(AppStyle.secondary)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppStyle.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

private struct StudyCompletionView: View {
    let correctCount: Int
    let incorrectCount: Int
    let studiedCount: Int
    let accuracyText: String
    let weakCount: Int

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(AppStyle.accent)

            VStack(spacing: 6) {
                Text("学習完了")
                    .font(.title.bold())
                    .foregroundStyle(AppStyle.ink)
                Text("今日の学習はここまで。")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    CompletionMetric(title: "正解", value: "\(correctCount)", color: AppStyle.accent)
                    CompletionMetric(title: "不正解", value: "\(incorrectCount)", color: AppStyle.coral)
                }
                HStack(spacing: 10) {
                    CompletionMetric(title: "今回学習", value: "\(studiedCount)", color: AppStyle.accent)
                    CompletionMetric(title: "正答率", value: accuracyText, color: AppStyle.secondary)
                }
                CompletionMetric(title: "苦手", value: "\(weakCount)", color: AppStyle.sun)
            }
        }
        .padding(24)
    }
}

private struct CompletionMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppStyle.muted)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.16), radius: 0, y: 4)
    }
}
