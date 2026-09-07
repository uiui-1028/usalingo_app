import SwiftUI

/// デザインタブ上半分のプレビュー枠。
///
/// ここで決めたデザインが実際にどう見えるかを映すための場所。
struct DesignPreviewStage<Content: View>: View {
    /// 枠の中に描くもの。標準では色カルーセルを表示する。
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous)
                .fill(WireColor.ink)

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // スライド中の内容も黒い角丸枠の外へ出さない。
        .clipShape(RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("デザインプレビュー")
    }
}

extension DesignPreviewStage where Content == DesignColorCarousel {
    /// 4色を自動で切り替える標準プレビュー。
    init() {
        self.init { DesignColorCarousel() }
    }
}

/// 色見本を5秒ごとに左へ送り、現在位置を4つの丸で示す。
struct DesignColorCarousel: View {
    private static let colors: [Color] = [
        Color(red: 1.00, green: 0.35, blue: 0.58),
        .white,
        Color(red: 0.32, green: 0.43, blue: 1.00),
        Color(red: 1.00, green: 0.78, blue: 0.20)
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedIndex = 1
    @State private var dragProgress: CGFloat = 0
    @State private var isSettling = false

    var body: some View {
        GeometryReader { proxy in
            let boxWidth = min(proxy.size.width * 0.48, proxy.size.height * 0.68)
            let boxHeight = min(boxWidth * 1.08, proxy.size.height * 0.72)
            let cardTravel = min(proxy.size.width * 0.63, boxWidth + WireMetrics.spacingXL * 2)

            VStack(spacing: WireMetrics.spacingS) {
                Spacer(minLength: WireMetrics.spacingM)

                ZStack {
                    // さらに外側の待機カードも描き、切り替え完了時に
                    // 左右端のカードが突然現れないよう連続させる。
                    ForEach(-2...2, id: \.self) { offset in
                        let colorIndex = wrappedIndex(selectedIndex + offset)
                        let position = CGFloat(offset) - dragProgress

                        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                            .fill(Self.colors[colorIndex])
                            .overlay {
                                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                                    .strokeBorder(Color.black, lineWidth: WireMetrics.strokeBase)
                            }
                            .frame(width: boxWidth, height: boxHeight)
                            .offset(x: position * cardTravel)
                            .accessibilityHidden(offset != 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard !isSettling,
                                  abs(value.translation.width) > abs(value.translation.height) else { return }
                            dragProgress = min(1, max(-1, -value.translation.width / max(cardTravel, 1)))
                        }
                        .onEnded { value in
                            settleDrag(
                                translation: value.translation.width,
                                predictedTranslation: value.predictedEndTranslation.width,
                                cardTravel: cardTravel
                            )
                        }
                )

                HStack(spacing: WireMetrics.spacingS) {
                    ForEach(Self.colors.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.white : Color.gray)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.black, lineWidth: WireMetrics.strokeHair)
                            }
                            .frame(width: 14, height: 14)
                    }
                }
                .padding(.bottom, WireMetrics.spacingS)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("色プレビュー")
        .accessibilityValue("全4色のうち\(selectedIndex + 1)番目")
        .accessibilityAction(named: "次の色") { move(by: 1) }
        .accessibilityAction(named: "前の色") { move(by: -1) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                guard !isSettling else { continue }
                move(by: 1)
            }
        }
    }

    private func settleDrag(
        translation: CGFloat,
        predictedTranslation: CGFloat,
        cardTravel: CGFloat
    ) {
        guard !isSettling else { return }

        let passedDistanceThreshold = abs(translation) > cardTravel * 0.18
        let passedVelocityThreshold = abs(predictedTranslation) > cardTravel * 0.35
        let projectedTranslation = abs(predictedTranslation) > abs(translation)
            ? predictedTranslation
            : translation
        let step = passedDistanceThreshold || passedVelocityThreshold
            ? (projectedTranslation < 0 ? 1 : -1)
            : 0

        move(by: step)
    }

    private func move(by step: Int) {
        guard !isSettling, (-1...1).contains(step) else { return }
        isSettling = true

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.32)) {
            dragProgress = CGFloat(step)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedIndex = wrappedIndex(selectedIndex + step)
                dragProgress = 0
                isSettling = false
            }
        }
    }

    private func wrappedIndex(_ index: Int) -> Int {
        (index % Self.colors.count + Self.colors.count) % Self.colors.count
    }
}

#Preview {
    DesignPreviewStage()
        .padding()
}
