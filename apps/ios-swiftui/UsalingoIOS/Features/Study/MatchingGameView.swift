import SwiftUI

/// 神経衰弱モード。英単語と日本語訳の12枚を裏向きに並べ、同じ語の2枚を揃えて消す。
///
/// 1手目で揃えられたら正解、一度でもミスした語は不正解として、通常の学習と同じ記録に流す。
struct MatchingGameView: View {
    /// 違った2枚を見せておく時間。
    private static let mismatchHoldSeconds: Double = 0.8
    private static let columnCount = 3

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @State private var game: MatchingGame?
    @State private var wordsById: [Int: WordCard] = [:]
    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var answerQueue = StudyAnswerQueue()
    @State private var sessionAnswers: [Bool] = []
    @State private var sessionProgresses: [LearningProgress] = []

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
                } else if wordsById.isEmpty {
                    StudyStatusView(
                        symbol: "rectangle.stack.badge.minus",
                        title: "カードがありません",
                        message: "別の学習モードを選ぶか、デッキに戻ってください。",
                        actionTitle: "デッキに戻る"
                    ) {
                        dismiss()
                    }
                } else if game?.isFinished == true {
                    StudyCompletionView(
                        correctCount: sessionAnswers.filter { $0 }.count,
                        incorrectCount: sessionAnswers.filter { !$0 }.count,
                        studiedCount: sessionAnswers.count,
                        accuracyText: accuracyText,
                        weakCount: sessionProgresses.filter(\.isWeak).count
                    )
                } else {
                    board
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            saveFailureBanner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WireColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear { appState.isShellChromeHidden = false }
    }

    private var header: some View {
        HStack(spacing: WireMetrics.spacingM) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.wireIcon(diameter: 40))
            .accessibilityLabel("デッキに戻る")

            Text(deck.deckName)
                .wireFont(.label)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("正解 \(sessionAnswers.filter { $0 }.count) / ミス \(sessionAnswers.filter { !$0 }.count)")
                .wireFont(.caption)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.vertical, WireMetrics.spacingM)
    }

    @ViewBuilder
    private var board: some View {
        if let game {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: WireMetrics.spacingS),
                    count: Self.columnCount
                ),
                spacing: WireMetrics.spacingS
            ) {
                ForEach(game.slots.indices, id: \.self) { slot in
                    tileView(at: slot, in: game)
                }
            }
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    @ViewBuilder
    private func tileView(at slot: Int, in game: MatchingGame) -> some View {
        if let tile = game.tile(at: slot) {
            let isFaceUp = game.isRevealed(tile)
            Button {
                flip(tile)
            } label: {
                Text(isFaceUp ? tile.text : "?")
                    .wireFont(isFaceUp ? .label : .titleS, color: isFaceUp ? WireColor.ink : WireColor.subText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                    .padding(WireMetrics.spacingS)
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .outlineSurface(
                        radius: WireMetrics.radiusControl,
                        shadow: .card,
                        fill: isFaceUp ? WireColor.surface : WireColor.groupL3
                    )
                    .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(game.isAwaitingHide)
            .accessibilityLabel(isFaceUp ? tile.text : "裏向きの札")
            .accessibilityHint(isFaceUp ? "" : "タップしてめくります")
        } else {
            // 補充までマスを空けておく。残っている札の位置を動かさないため。
            Color.clear.frame(minHeight: 84)
        }
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage {
            // 色相を使わずに異常を示す（破線 + 文言）。
            VStack(spacing: WireMetrics.spacingS) {
                Text("回答を保存できませんでした")
                    .wireFont(.label)
                Text(saveErrorMessage)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                Button("同じ回答をもう一度保存") {
                    self.saveErrorMessage = nil
                    drainAnswerQueue()
                }
                .buttonStyle(.wireSecondary)
                .disabled(answerQueue.isDraining)
            }
            .frame(maxWidth: .infinity)
            .padding(WireMetrics.spacingL)
            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil, dashed: true)
            .padding(WireMetrics.screenPadding)
        }
    }

    private var accuracyText: String {
        guard !sessionAnswers.isEmpty else { return "0%" }
        let correctCount = sessionAnswers.filter { $0 }.count
        return "\(Int((Double(correctCount) / Double(sessionAnswers.count) * 100).rounded()))%"
    }

    private func flip(_ tile: MatchingGame.Tile) {
        guard var game else { return }
        let result = game.flip(tileId: tile.id)
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            self.game = game
        }

        switch result {
        case .matched(let cardId, let isCorrect):
            if let card = wordsById[cardId] {
                answerQueue.enqueue(cardIndex: cardId, card: card, isCorrect: isCorrect)
                drainAnswerQueue()
            }
        case .mismatched:
            Task {
                try? await Task.sleep(for: .seconds(Self.mismatchHoldSeconds))
                guard var game = self.game else { return }
                game.hideRevealed()
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                    self.game = game
                }
            }
        case .revealed, .ignored:
            break
        }
    }

    /// 溜まった回答を投入順に保存する。カードの学習と同じく、UI は保存を待たない。
    private func drainAnswerQueue() {
        guard answerQueue.beginDraining() else { return }
        Task {
            while let pending = answerQueue.next {
                do {
                    let savedAnswer = try await appState.studyDataSource.saveAnswerWithUndo(
                        card: pending.card,
                        isCorrect: pending.isCorrect
                    )
                    sessionAnswers.append(pending.isCorrect)
                    sessionProgresses.append(savedAnswer.progress)
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

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            let cards = try await appState.studyDataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
            wordsById = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            game = MatchingGame(words: cards)
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }
}
