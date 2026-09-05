import SwiftUI

/// デザインタブ上半分のプレビュー枠（空箱）。
///
/// ここで決めたデザインが実際にどう見えるかを映すための場所。
/// タッチ操作は受け取らず、表示専用。中身は今は空で、
/// このファイルの `content` を差し替えるだけで自由に作り込める。
struct DesignPreviewStage<Content: View>: View {
    /// 枠の中に描くもの。省略すると空箱になる。
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous)
                .fill(WireColor.ink)

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // プレビューなので操作は一切受け取らない。
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("デザインプレビュー")
    }
}

extension DesignPreviewStage where Content == EmptyView {
    /// 中身が空のプレビュー枠。
    init() {
        self.init { EmptyView() }
    }
}

#Preview {
    DesignPreviewStage()
        .padding()
}
