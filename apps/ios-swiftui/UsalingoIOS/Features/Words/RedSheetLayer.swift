import SwiftUI

/// 単語一覧の上に1枚だけ重ねる赤シート。一覧のスクロールとは独立していて、答えを出しても動かない。
/// 右半分を覆う不透明な板で、つまみは連続値で動き、空レコードも同じ量だけ動く。
struct RedSheetLayer: View {
    @Binding var topRatio: CGFloat
    let availableHeight: CGFloat
    let minimumTopRatio: CGFloat
    let maximumTopRatio: CGFloat
    @State private var dragStartTop: CGFloat?

    private var restingTop: CGFloat {
        RedSheetPosition.top(
            availableHeight: availableHeight,
            ratio: RedSheetPosition.clampedRatio(topRatio, minimum: minimumTopRatio, maximum: maximumTopRatio)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 上端は直線にして、角丸部分から隠した行の文字が見えないようにする。
            Rectangle()
                .fill(Color(red: 1, green: 0.18, blue: 0.23))
                .padding(.top, restingTop)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Capsule()
                .fill(.white)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("wordListViewport"))
                        .onChanged { value in
                            if dragStartTop == nil { dragStartTop = restingTop }
                            guard let dragStartTop else { return }
                            let top = dragStartTop + value.translation.height
                            topRatio = RedSheetPosition.clampedRatio(
                                top / max(1, availableHeight),
                                minimum: minimumTopRatio,
                                maximum: maximumTopRatio
                            )
                        }
                        .onEnded { _ in
                            dragStartTop = nil
                        }
                )
                .onTapGesture { }
                .accessibilityLabel("赤シートの高さ")
                .accessibilityValue("画面下から\(Int(((1 - topRatio) * 100).rounded()))パーセント")
                .accessibilityHint("上下にドラッグして滑らかに調整します")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        topRatio = RedSheetPosition.clampedRatio(topRatio - 0.01, minimum: minimumTopRatio, maximum: maximumTopRatio)
                    case .decrement:
                        topRatio = RedSheetPosition.clampedRatio(topRatio + 0.01, minimum: minimumTopRatio, maximum: maximumTopRatio)
                    @unknown default: break
                    }
                }
                .offset(y: restingTop)
                .backSwipeProtectedRegion()
        }
        .clipped()
    }
}

enum RedSheetPosition {
    static func top(availableHeight: CGFloat, ratio: CGFloat) -> CGFloat {
        max(0, availableHeight) * ratio
    }

    static func clampedRatio(_ ratio: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(maximum, max(minimum, ratio))
    }
}
