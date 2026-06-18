import SwiftUI

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @State private var cards: [WordCard] = []
    @State private var index = 0
    @State private var message = ""
    @State private var isLoading = false
    @State private var dragOffset = CGSize.zero
    @State private var showAnswer = false

    private let studyService = StudyService()

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                if isLoading {
                    ProgressView()
                } else if index < cards.count {
                    cardStack
                } else {
                    VStack(spacing: 14) {
                        Text("学習完了！")
                            .font(.title.bold())
                        Image(systemName: "sparkles")
                            .font(.system(size: 42))
                            .foregroundStyle(AppStyle.accent)
                        Text(message.isEmpty ? "今日の学習はここまで。" : message)
                            .foregroundStyle(AppStyle.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .navigationBarBackButtonHidden(true)
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 20) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(AppStyle.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 9) {
                Text(cards.isEmpty ? "0 / 0" : "\(min(index + 1, cards.count)) / \(cards.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppStyle.muted)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.82))
                        Capsule()
                            .fill(AppStyle.accent)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
            toolbarButton("tag", action: {})
            toolbarButton("speaker.wave.2", action: {})
            toolbarButton("arrow.uturn.backward", action: undo)
            toolbarButton("square.and.pencil", action: {})
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppStyle.line)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
        .padding(16)
    }

    private func toolbarButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppStyle.accent)
                .frame(width: 48, height: 48)
                .background(AppStyle.background)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppStyle.line)
                }
        }
        .buttonStyle(.plain)
    }

    private var progress: CGFloat {
        guard !cards.isEmpty else { return 0 }
        return CGFloat(min(index + 1, cards.count)) / CGFloat(cards.count)
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        do {
            cards = try await studyService.fetchStudyQueue(deckId: deck.id, session: session)
            message = cards.isEmpty ? "このデッキにはカードがありません。" : ""
        } catch {
            message = error.localizedDescription
        }
        isLoading = false
    }

    private func answer(_ isCorrect: Bool) async {
        guard let session = appState.session, index < cards.count else { return }
        do {
            try await studyService.saveAnswer(card: cards[index], isCorrect: isCorrect, session: session)
            index += 1
            showAnswer = false
            dragOffset = .zero
        } catch {
            message = error.localizedDescription
        }
    }

    private func swipe(isCorrect: Bool) {
        let target: CGFloat = isCorrect ? 700 : -700
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = CGSize(width: target, height: 0)
        }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            await answer(isCorrect)
        }
    }

    private func undo() {
        guard index > 0 else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            index -= 1
            showAnswer = false
            dragOffset = .zero
        }
    }
}
