import SwiftUI

/// デッキ設定のボトムシート。`.sheet` は使わない。
///
/// 「始める」ボタンとシートを**同じ親コンテナ**に入れて、1つの `offset` で
/// 一緒に動かす（`BottomSheetAttachedButtonDemo` のやり方）。
/// `.sheet` で出して、ボタンだけを別の重ね方で浮かせると、システムが敷く
/// 半透明の幕とボタン側の下敷きが二重に見えて、由来の分からない背景になる。
/// ここでは幕を敷かず、面はすべて自前で描く。
struct DeckConceptSheet: View {
    let deck: Deck
    let counts: StudyDeckCounts?
    let onStart: (StudyMode) -> Void
    let onClose: () -> Void

    @State private var detent: Detent = .medium
    @State private var selectedMode: StudyMode = .all
    @GestureState private var dragTranslation: CGFloat = 0

    private enum Detent {
        case large
        case medium
    }

    /// つまみの見た目。ここを持って上下に動かす。
    private enum Metrics {
        static let largeTopInset: CGFloat = 96
        static let mediumHeightRatio: CGFloat = 0.46
        /// 下へ引ききったときの余白。ここを越えたら閉じる。
        static let overshoot: CGFloat = 120
        static let dismissDistance: CGFloat = 96
        static let cornerRadius: CGFloat = 28
        static let grabberHeight: CGFloat = 5
        static let grabberWidth: CGFloat = 44
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let largeY = Metrics.largeTopInset
            let mediumY = screenHeight * Metrics.mediumHeightRatio
            let baseY = detent == .large ? largeY : mediumY
            let currentY = max(largeY, min(mediumY + Metrics.overshoot, baseY + dragTranslation))

            // ボタンとシートを1つの縦並びに入れる。動かすのはこのまとまりだけ。
            VStack(alignment: .trailing, spacing: WireMetrics.spacingS) {
                startButton
                    .padding(.trailing, WireMetrics.screenPadding)

                sheetSurface(height: screenHeight)
            }
            .offset(y: currentY)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: detent)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var startButton: some View {
        Button("始める", systemImage: "play.fill") {
            onStart(selectedMode)
        }
        .buttonStyle(.wirePrimary)
        .fixedSize()
        .accessibilityHint("選んだ学習モードで学習を始めます")
    }

    private func sheetSurface(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            DeckConceptView(deck: deck, counts: counts, selectedMode: $selectedMode)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Metrics.cornerRadius,
                topTrailingRadius: Metrics.cornerRadius,
                style: .continuous
            )
            .fill(WireColor.background)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: Metrics.cornerRadius,
                topTrailingRadius: Metrics.cornerRadius,
                style: .continuous
            )
            .stroke(WireColor.ink, lineWidth: WireMetrics.strokeBase)
            .frame(height: height)
            .allowsHitTesting(false)
        }
        .clipped()
    }

    /// つまみとデッキ名。ドラッグはここだけで受ける。
    /// シートの中身は縦スクロールするので、面全体で受けると取り合いになる。
    private var header: some View {
        VStack(spacing: WireMetrics.spacingS) {
            Capsule()
                .fill(WireColor.ink.opacity(0.35))
                .frame(width: Metrics.grabberWidth, height: Metrics.grabberHeight)
                .padding(.top, WireMetrics.spacingS)

            HStack(spacing: WireMetrics.spacingS) {
                Text(deck.deckName)
                    .wireFont(.titleS)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .wireFont(.label)
                        .padding(WireMetrics.spacingS)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
            }
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.bottom, WireMetrics.spacingS)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // 下へ大きく振り切ったら閉じる。中途半端な位置に残さない。
                if value.predictedEndTranslation.height > Metrics.dismissDistance,
                   detent == .medium {
                    onClose()
                    return
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    detent = value.predictedEndTranslation.height < 0 ? .large : .medium
                }
            }
    }
}
