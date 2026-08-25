import SwiftUI

struct SwipeTutorialView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let complete: () -> Void
    let dismiss: () -> Void

    @State private var step = 0
    @State private var showsAnswer = false
    @State private var dragOffset: CGFloat = 0
    @State private var message = ""

    private let steps = [
        "タップで答えを見る",
        "左へスワイプ：まだむずかしい",
        "右へスワイプ：わかった"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Text("はじめての操作ガイド")
                        .font(.title3.weight(.black))
                    Spacer()
                    Button("あとで", action: dismiss)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityLabel("チュートリアルを閉じる")
                }

                ProgressView(value: Double(step + 1), total: Double(steps.count))
                    .tint(AppStyle.accent)
                    .accessibilityLabel("操作ガイド \(step + 1) / \(steps.count)")

                Text(step == steps.count ? "できました！" : steps[step])
                    .font(.title2.weight(.black))
                    .multilineTextAlignment(.center)

                tutorialCard

                Text(instruction)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppStyle.muted)
                    .frame(minHeight: 46)

                if !message.isEmpty {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppStyle.accentDark)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(message)
                }

                controls
            }
            .padding(24)
            .frame(maxWidth: 440)
            .background(AppStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppStyle.line, lineWidth: 1)
            }
            .padding(20)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var tutorialCard: some View {
        VStack(spacing: 12) {
            Text("apple")
                .font(.system(size: 40, weight: .black))
            Text(showsAnswer ? "りんご" : "タップして答えを見る")
                .font(.headline)
                .foregroundStyle(showsAnswer ? AppStyle.accentDark : AppStyle.muted)
            if step == 1 {
                Label("左へ：まだむずかしい", systemImage: "xmark.circle.fill")
                    .foregroundStyle(AppStyle.coral)
                    .font(.footnote.weight(.bold))
            } else if step == 2 {
                Label("右へ：わかった", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppStyle.accent)
                    .font(.footnote.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .background(AppStyle.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 2)
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset / 18)))
        .gesture(dragGesture)
        .onTapGesture {
            guard step == 0 else { return }
            showsAnswer = true
            message = "答えが見えました。次へ進めます。"
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showsAnswer ? "apple。答えはりんご。" : "apple。タップして答えを表示。")
        .accessibilityHint(step == 0 ? "ダブルタップで答えを表示します。" : "左右へスワイプするか、下のボタンで操作します。")
        .accessibilityAction(named: "答えを表示") {
            guard step == 0 else { return }
            showsAnswer = true
            message = "答えが見えました。次へ進めます。"
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if step == 0 {
                Button("答えを表示") {
                    showsAnswer = true
                    message = "答えが見えました。次へ進めます。"
                }
                .buttonStyle(.bordered)

                Button("次へ") { advance() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!showsAnswer)
            } else if step == 1 {
                swipeButtons
                Button("次へ") { advance() }
                    .buttonStyle(.borderedProminent)
                    .disabled(message != "左スワイプを試せました。")
            } else if step == 2 {
                swipeButtons
                Button("完了") { complete() }
                    .buttonStyle(.borderedProminent)
                    .disabled(message != "右スワイプを試せました。")
            } else {
                Button("学習をはじめる", action: complete)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var swipeButtons: some View {
        HStack(spacing: 12) {
            Button("左：まだむずかしい") { finishSwipe(.left) }
                .buttonStyle(.bordered)
            Button("右：わかった") { finishSwipe(.right) }
                .buttonStyle(.bordered)
        }
        .font(.footnote.weight(.semibold))
    }

    private var instruction: String {
        switch step {
        case 0: return "カードをタップして、英単語の答えを見てみましょう。"
        case 1: return "わからなかったときは、カードを左へ送ります。"
        case 2: return "わかったときは、カードを右へ送ります。"
        default: return "いつでも操作ガイドは見直せます。"
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard step == 1 || step == 2 else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard step == 1 || step == 2 else { return }
                if value.translation.width < -90 {
                    finishSwipe(.left)
                } else if value.translation.width > 90 {
                    finishSwipe(.right)
                } else {
                    resetCardPosition()
                    message = "もう少し大きく左右へ動かしてみましょう。"
                }
            }
    }

    private func finishSwipe(_ direction: SwipeDirection) {
        let isExpected = (step == 1 && direction == .left) || (step == 2 && direction == .right)
        guard isExpected else {
            resetCardPosition()
            message = step == 1 ? "左へ送る操作を試してみましょう。" : "右へ送る操作を試してみましょう。"
            return
        }

        message = direction == .left ? "左スワイプを試せました。" : "右スワイプを試せました。"
        if reduceMotion {
            dragOffset = 0
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                dragOffset = direction == .left ? -260 : 260
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                dragOffset = 0
            }
        }
    }

    private func advance() {
        step += 1
        message = ""
        dragOffset = 0
    }

    private func resetCardPosition() {
        if reduceMotion {
            dragOffset = 0
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                dragOffset = 0
            }
        }
    }
}

private enum SwipeDirection {
    case left
    case right
}

#if DEBUG
#Preview("Swipe Tutorial") {
    SwipeTutorialView(complete: {}, dismiss: {})
        .environmentObject(DesignSettings())
}
#endif
