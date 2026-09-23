import SwiftUI

struct FiveChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @State private var game: FiveChoiceGame?
    @State private var source: (any StudyDataSource)?
    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var answerQueue = StudyAnswerQueue()
    @State private var showsLeaveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            saveFailureBanner
            footer
        }
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear { appState.isShellChromeHidden = false }
        .confirmationDialog("未保存の回答があります", isPresented: $showsLeaveConfirmation, titleVisibility: .visible) {
            Button("保存せずに戻る", role: .destructive) { dismiss() }
            Button("学習に戻る", role: .cancel) { }
        } message: {
            Text("保存をやり直す場合は、この画面に戻って「もう一度保存」を押してください。")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("5択を準備しています")
        } else if let loadErrorMessage {
            StudyStatusView(
                symbol: "exclamationmark.triangle",
                title: "カードを読み込めませんでした",
                message: loadErrorMessage,
                actionTitle: "もう一度試す"
            ) { Task { await load() } }
        } else if let game, let question = game.question {
            // 結果側だけにタップ判定を置く。回答した同じタップで次の問題へ飛ばない。
            if game.isRevealed {
                questionScroll(question, game: game)
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("次の問題へ")) { advance() }
            } else {
                questionScroll(question, game: game)
            }
        } else if game?.answeredCount == 0 {
            StudyStatusView(
                symbol: "rectangle.stack.badge.minus",
                title: "5択を作れる問題がありません",
                message: "重複や似た意味を除くと、選択肢が足りません。学習するデッキを追加するか、別のモードをお試しください。",
                actionTitle: "デッキに戻る"
            ) { dismiss() }
        } else {
            VStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "checkmark.circle").wireFont(.titleL)
                Text(answerQueue.isEmpty ? "学習完了" : "回答を保存しています")
                    .wireFont(.titleL)
                if let game, game.skippedCount > 0 {
                    Text("選択肢が足りない\(game.skippedCount)問は出題しませんでした。")
                        .wireFont(.caption)
                }
            }
            .multilineTextAlignment(.center)
            .padding(WireMetrics.screenPadding)
        }
    }

    private func questionScroll(_ question: FiveChoiceGame.Question, game: FiveChoiceGame) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: WireMetrics.spacingL) {
                    partOfSpeechRow(question.card, revealed: game.isRevealed)
                    Text(question.card.text)
                        .wireFont(.titleL)
                        .multilineTextAlignment(.center)
                        .padding(WireMetrics.spacingXL)
                        .frame(maxWidth: .infinity)
                        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
                        .accessibilityIdentifier("fiveChoice.question")

                    VStack(spacing: WireMetrics.spacingM) {
                        ForEach(question.choices.indices, id: \.self) { index in
                            if game.isRevealed {
                                choice(question.choices[index], index: index, question: question, game: game)
                            } else {
                                Button {
                                    answer(at: index)
                                } label: {
                                    choice(question.choices[index], index: index, question: question, game: game)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("fiveChoice.answer.\(index)")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    Spacer(minLength: 0)
                }
                .padding(WireMetrics.screenPadding)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
    }

    private func choice(_ card: WordCard, index: Int, question: FiveChoiceGame.Question, game: FiveChoiceGame) -> some View {
        let isCorrect = game.isRevealed && index == question.correctIndex
        let isWrong = game.isRevealed && index == game.selectedIndex && !isCorrect
        let status = isCorrect ? "正解" : (isWrong ? "不正解" : "")
        // 正誤だけに色を添え、色を見分けなくても記号と文言で判断できるようにする。
        let color: Color = isCorrect ? Color(red: 0.08, green: 0.38, blue: 0.19)
            : (isWrong ? Color(red: 0.65, green: 0.12, blue: 0.12) : WireColor.ink)

        return VStack(spacing: WireMetrics.spacingXS) {
            VStack(spacing: WireMetrics.spacingXS) {
                if !status.isEmpty {
                    Label(status, systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .wireFont(.caption, color: color)
                }
                Text(card.meaning)
                    .wireFont(.body, color: color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(WireMetrics.spacingM)
            .frame(maxWidth: .infinity, minHeight: 52)
            .outlineSurface(
                radius: WireMetrics.radiusControl,
                stroke: isCorrect || isWrong ? WireMetrics.strokeHeavy : WireMetrics.strokeHair,
                shadow: nil,
                dashed: isWrong,
                fill: isCorrect || isWrong ? color.opacity(0.08) : WireColor.surface
            )
            if game.isRevealed {
                Text(card.text)
                    .wireFont(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.isRevealed ? "\(card.meaning)、\(card.text)" : card.meaning)
        .accessibilityValue(status)
    }

    private func partOfSpeechRow(_ card: WordCard, revealed: Bool) -> some View {
        let active = WordCardContent(card: card).partsOfSpeech
        // 接続詞への置き換えも答え合わせ後に行い、品詞を先に明かさない。
        let parts = WordPartOfSpeech.displayOrder.map { part in
            revealed && active.contains(.conjunction) && part == .preposition ? WordPartOfSpeech.conjunction : part
        }
        return HStack(spacing: 0) {
            ForEach(parts) { part in
                let highlighted = revealed && active.contains(part)
                Text(part.rawValue)
                    .wireFont(.caption, color: highlighted ? WireColor.ink : WireColor.subText)
                    .fontWeight(highlighted ? .bold : .regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WireMetrics.spacingXS)
                    .background {
                        if highlighted {
                            Capsule().fill(WireColor.groupL3)
                                .shadow(color: WireColor.ink.opacity(0.2), radius: 1, x: 0, y: -1)
                        }
                    }
                    .accessibilityAddTraits(highlighted ? .isSelected : [])
            }
        }
        .padding(WireMetrics.spacingXS)
        .outlineSurface(radius: WireMetrics.radiusPill, shadow: nil)
    }

    private var footer: some View {
        HStack {
            Button {
                if answerQueue.isEmpty { dismiss() } else { showsLeaveConfirmation = true }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.wireIcon(diameter: 44))
            .accessibilityLabel("学習に戻る")
            .disabled(answerQueue.isDraining)
            Spacer()
            if answerQueue.isDraining { ProgressView().accessibilityLabel("回答を保存中") }
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.vertical, WireMetrics.spacingS)
        .background {
            if game?.isRevealed == true {
                Color.clear.contentShape(Rectangle()).onTapGesture { advance() }
            }
        }
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage {
            VStack(spacing: WireMetrics.spacingS) {
                Text("回答を保存できませんでした").wireFont(.label)
                Text(saveErrorMessage).wireFont(.caption)
                Button("もう一度保存") {
                    self.saveErrorMessage = nil
                    drainAnswers()
                }
                .buttonStyle(.wireSecondary)
                .disabled(answerQueue.isDraining)
            }
            .multilineTextAlignment(.center)
            .padding(WireMetrics.spacingM)
            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil, dashed: true)
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private func answer(at index: Int) {
        guard var game, let card = game.question?.card,
              let isCorrect = game.answer(at: index) else { return }
        self.game = game
        HapticFeedbackService.tap()
        answerQueue.enqueue(cardIndex: game.answeredCount - 1, card: card, isCorrect: isCorrect)
        if saveErrorMessage == nil { drainAnswers() }
    }

    private func advance() {
        guard var game, game.isRevealed else { return }
        game.advance()
        self.game = game
        HapticFeedbackService.tap()
    }

    private func drainAnswers() {
        guard let source else { return }
        drainStudyAnswerQueue($answerQueue, appState: appState, saveErrorMessage: $saveErrorMessage, source: source)
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        let source = appState.studyDataSource
        self.source = source
        do {
            game = try await FiveChoiceGame.load(deckId: deck.id, source: source)
        } catch is CancellationError {
            return
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }
}
