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
        .background {
            StudyBackSwipeEnabler()
        }
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
            .backSwipeProtectedRegion()

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
                .backSwipeProtectedRegion()
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
            .backSwipeProtectedRegion()
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

private extension View {
    /// UIKit 側の開始地点判定に使う印。ヒットテスト自体は担当しないため、カードや
    /// ボタンが受け取るタッチを奪わない。
    func backSwipeProtectedRegion() -> some View {
        background(StudyBackSwipeProtectedRegionMarker())
    }
}

private struct StudyBackSwipeProtectedRegionMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = StudyBackSwipeProtectedRegionView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class StudyBackSwipeProtectedRegionView: UIView {}

/// 戻る操作は UIKit 標準の対話的 pop にそのまま任せる。iOS 26 以降はコンテンツ全体、
/// それ以前は画面端からのスワイプ。指への追従・しきい値・前画面の視差は UIKit が持つので、
/// ここでは「どこから始めたら戻さないか」だけを足す。
private struct StudyBackSwipeEnabler: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> StudyBackSwipeHostView {
        let view = StudyBackSwipeHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowChange = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: StudyBackSwipeHostView, context: Context) {
        context.coordinator.attach(from: uiView)
    }

    static func dismantleUIView(_ uiView: StudyBackSwipeHostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: StudyBackSwipeHostView?
        private weak var gesture: UIGestureRecognizer?
        private weak var originalDelegate: UIGestureRecognizerDelegate?
        private var originalIsEnabled = true

        func attach(from view: StudyBackSwipeHostView?) {
            guard let view,
                  let navigationController = view.owningNavigationController,
                  let target = navigationController.studyBackSwipeGesture else { return }

            if let current = gesture, current !== target {
                restore(current)
            }
            if gesture !== target {
                gesture = target
                originalDelegate = target.delegate
                originalIsEnabled = target.isEnabled
            }
            hostView = view

            // 戻るボタンを隠している間 UIKit はこのジェスチャーを止めるので、明示的に戻す。
            target.isEnabled = true
            if target.delegate !== self {
                target.delegate = self
            }
        }

        func detach() {
            if let gesture {
                restore(gesture)
            }
            gesture = nil
            hostView = nil
        }

        private func restore(_ gesture: UIGestureRecognizer) {
            if gesture.delegate === self {
                gesture.delegate = originalDelegate
            }
            gesture.isEnabled = originalIsEnabled
            originalDelegate = nil
        }

        /// カードとアクションバーの marker から始まったタッチだけ、標準の戻るへ渡さない。
        /// それ以外の判断はすべて UIKit 本来の delegate に戻す。
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let hostView, let window = hostView.window else { return false }
            let location = touch.location(in: window)
            let startsInProtectedRegion = window.studyBackSwipeProtectedRegions.contains { marker in
                !marker.isHidden
                    && marker.alpha > 0.01
                    && marker.convert(marker.bounds, to: window).contains(location)
            }
            if startsInProtectedRegion { return false }
            return originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            originalDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldRecognizeSimultaneouslyWith: otherGestureRecognizer
            ) ?? false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldRequireFailureOf: otherGestureRecognizer
            ) ?? false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldBeRequiredToFailBy: otherGestureRecognizer
            ) ?? false
        }
    }
}

private final class StudyBackSwipeHostView: UIView {
    var onWindowChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?()
    }
}

private extension UIView {
    var owningNavigationController: UINavigationController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller.navigationController
            }
            responder = current.next
        }
        return nil
    }
}

private extension UINavigationController {
    /// iOS 26 はコンテンツ全体で戻れる recognizer を持つ。無い世代は従来の端スワイプ。
    ///
    /// CI の Xcode は iOS 26 SDK を持たない世代があり、シンボルを直に書くと
    /// `cannot find ... in scope` でビルドできない。宣言に依存しないよう
    /// セレクタで引き、応答しない実行環境では従来の端スワイプへ落ちる。
    var studyBackSwipeGesture: UIGestureRecognizer? {
        let contentPopSelector = NSSelectorFromString("interactiveContentPopGestureRecognizer")
        if responds(to: contentPopSelector),
           let contentGesture = perform(contentPopSelector)?.takeUnretainedValue() as? UIGestureRecognizer {
            return contentGesture
        }
        return interactivePopGestureRecognizer
    }
}

private extension UIView {
    var studyBackSwipeProtectedRegions: [StudyBackSwipeProtectedRegionView] {
        subviews.reduce(into: []) { result, subview in
            if let marker = subview as? StudyBackSwipeProtectedRegionView {
                result.append(marker)
            }
            result.append(contentsOf: subview.studyBackSwipeProtectedRegions)
        }
    }
}
