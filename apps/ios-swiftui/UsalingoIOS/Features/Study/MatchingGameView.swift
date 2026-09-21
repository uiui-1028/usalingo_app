import SwiftUI

/// マッチングモード。左に日本語、右に英語を5枚ずつ表向きで並べ、同じ語の2枚を選んで消す。
///
/// 1手目で揃えられたら正解、一度でもミスした語は不正解として、通常の学習と同じ記録に流す。
struct MatchingGameView: View {
    /// 揃った2枚を黒ベタで見せておく時間。この間に消えたと分かる。
    private static let matchFlashSeconds: Double = 0.45
    /// 違った2枚を揺らす時間。
    private static let shakeSeconds: Double = 0.3
    private static let tileHeight: CGFloat = 56

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
    /// 揃ったばかりで黒ベタにしている札。
    @State private var flashingTileIds: Set<Int> = []
    /// 違って揺らしている札。
    @State private var shakingTileIds: Set<Int> = []

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
        .background {
            BackSwipeEnabler()
        }
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
            VStack(spacing: WireMetrics.spacingM) {
                Text("同じ意味の組をタップしてください")
                    .wireFont(.caption)

                HStack(alignment: .top, spacing: WireMetrics.spacingS) {
                    column(.japanese, in: game)
                    column(.english, in: game)
                }
            }
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private func column(_ column: MatchingGame.Column, in game: MatchingGame) -> some View {
        VStack(spacing: WireMetrics.spacingS) {
            ForEach(Array(game.tiles(in: column).enumerated()), id: \.offset) { _, tile in
                if let tile {
                    tileView(tile, in: game)
                } else {
                    // 出す語が尽きたマス。並びを崩さないよう場所だけ空けておく。
                    Color.clear.frame(height: Self.tileHeight)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tileView(_ tile: MatchingGame.Tile, in game: MatchingGame) -> some View {
        let isFlashing = flashingTileIds.contains(tile.id)
        let isSelected = game.selectedTileId == tile.id
        // 選んだ札と揃った札はどちらも黒ベタ反転にし、揃ったほうにだけチェックを足す。
        let isInverted = isSelected || isFlashing

        return Button {
            tap(tile)
        } label: {
            HStack(spacing: WireMetrics.spacingXS) {
                if isFlashing {
                    Image(systemName: "checkmark")
                        .transition(.scale.combined(with: .opacity))
                }
                Text(tile.text)
            }
                .wireFont(.label, color: isInverted ? WireColor.surface : WireColor.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .padding(.horizontal, WireMetrics.spacingS)
                .frame(maxWidth: .infinity, minHeight: Self.tileHeight)
                .outlineSurface(
                    radius: WireMetrics.radiusControl,
                    shadow: tile.isCleared && !isFlashing ? nil : .card,
                    fill: isInverted ? WireColor.ink : WireColor.surface
                )
                .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(tile.isCleared)
        // 揃った札は消さずに薄く残す。並びが崩れず、どこまで進んだかも見える。
        .opacity(tile.isCleared && !isFlashing ? WireMetrics.disabledOpacity : 1)
        .scaleEffect(isSelected ? 1.03 : 1)
        .modifier(ShakeEffect(shakes: shakingTileIds.contains(tile.id) ? 1 : 0))
        .animation(.easeInOut(duration: Self.shakeSeconds), value: shakingTileIds)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        .animation(.easeInOut(duration: 0.25), value: isFlashing)
        .accessibilityLabel(tile.text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(tile.isCleared ? "揃いました" : "同じ意味の札と組にします")
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

    private func tap(_ tile: MatchingGame.Tile) {
        guard var game else { return }
        let result = game.tap(tileId: tile.id)
        self.game = game

        switch result {
        case .matched(let cardId, let isCorrect, let tileIds):
            if let card = wordsById[cardId] {
                answerQueue.enqueue(cardIndex: cardId, card: card, isCorrect: isCorrect)
                drainAnswerQueue()
            }
            flashingTileIds.formUnion(tileIds)
            Task {
                try? await Task.sleep(for: .seconds(Self.matchFlashSeconds))
                flashingTileIds.subtract(tileIds)
                guard var game = self.game, game.needsRefill else { return }
                game.refill()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    self.game = game
                }
            }
        case .mismatched(let tileIds):
            shakingTileIds.formUnion(tileIds)
            Task {
                try? await Task.sleep(for: .seconds(Self.shakeSeconds))
                shakingTileIds.subtract(tileIds)
            }
        case .selected, .ignored:
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

/// 組が違ったときに札を短く左右へ揺らす。色相を使わずに「違う」と伝える。
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var cycles: CGFloat = 3
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: travel * sin(shakes * .pi * cycles), y: 0)
        )
    }
}
