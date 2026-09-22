import SwiftUI

/// マッチングモード。左に日本語、右に英語を5枚ずつ表向きで並べ、同じ語の2枚を選んで消す。
///
/// 1手目で揃えられたら正解、一度でもミスした語は不正解として、通常の学習と同じ記録に流す。
/// 成績は画面に出さない。学習曲線は裏で動かし、遊んでいる間は点数を見せない。
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
    /// 揃ったばかりで黒ベタにしている札。
    @State private var flashingTileIds: Set<Int> = []
    /// 違って揺らしている札。
    @State private var shakingTileIds: Set<Int> = []

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
                    completion
                } else {
                    board
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
        .task { await load() }
    }

    /// 盤の下に置く道具。カード学習と違い正解・不正解は押さないので、帯だけを中央に出す。
    @ViewBuilder
    private var actionBar: some View {
        if !isLoading, loadErrorMessage == nil, !wordsById.isEmpty {
            HStack(spacing: WireMetrics.spacingS) {
                toolbarButton("chevron.left", label: "学習に戻る") { dismiss() }
                toolbarButton(
                    "shuffle",
                    label: "札を並べ替える",
                    isDisabled: game?.isFinished != false,
                    action: shuffleBoard
                )
            }
            .padding(.horizontal, WireMetrics.spacingM)
            .padding(.vertical, WireMetrics.spacingM)
            .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.bottom, WireMetrics.spacingM)
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

    @ViewBuilder
    private var board: some View {
        if let game {
            HStack(alignment: .top, spacing: WireMetrics.spacingS) {
                column(.japanese, in: game)
                column(.english, in: game)
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

    /// 遊び終えた合図だけを出す。正解数や正答率は見せない。
    private var completion: some View {
        VStack(spacing: WireMetrics.spacingL) {
            Image(systemName: "sparkles")
                .wireFont(.titleL)

            VStack(spacing: WireMetrics.spacingXS) {
                Text("学習完了")
                    .wireFont(.titleL)
                Text("今日の学習はここまで。")
                    .wireFont(.caption)
            }
        }
        .padding(WireMetrics.spacingXL)
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

    /// 残った札の場所だけ混ぜる。何を揃えたかは変わらないので、記録には触らない。
    private func shuffleBoard() {
        guard var game else { return }
        game.shuffleBoard()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            self.game = game
        }
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

    private func drainAnswerQueue() {
        drainStudyAnswerQueue($answerQueue, appState: appState, saveErrorMessage: $saveErrorMessage)
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
