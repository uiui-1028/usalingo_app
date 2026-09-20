import SwiftUI

/// 学習画面のデッキ一覧。上下のスワイプで回す、奥行きのあるカルーセル。
///
/// 1枚のカードに表紙・デッキ名・進み具合をまとめて入れ、カードごと動かす。中央の1枚が
/// 主役で、その上下に最大2枚ずつを傾けて重ねる。指を離すといちばん近いカードが中央へ
/// 来る。先頭より上と、最後より下へは進まない。
struct DeckCarouselView: View {
    /// 見た目の寸法。傾きと重なりの強さはここだけで決める。
    private enum Metrics {
        /// カードの中の表紙の大きさ。カードの幅に対する割合と、上限。
        static let coverWidthRatio: CGFloat = 0.3
        static let coverWidthRange: ClosedRange<CGFloat> = 88...124

        /// 1枚ぶん進むときに動く高さ。カードの高さに対する割合。
        ///
        /// 倒したカードは縦に薄く見えるので、その薄くなった高さのぶんは空ける。ここを
        /// 詰めすぎると隣のカードが中央のカードへ深く差し込まれ、突き抜けて見える。
        static let slotRatio: CGFloat = 0.9
        /// いちばん端のカードの傾き。90度まで倒すと裏返ってしまうので、ここで頭打ちにする。
        static let tiltDegrees: Double = 75
        static let perspective: CGFloat = 0.65
        /// 遠いカードを小さくする割合。奥にあることは、この縮みで見せる。
        static let scaleFalloff: Double = 0.2
        static let opacityFalloff: Double = 0.22

        /// カードの高さが測れるまで使う見込みの値。
        static let estimatedCardHeight: CGFloat = 180
        /// 指を離したあと滑り続ける時間の目安（秒）。この長さぶんの勢いで先へ進む。
        static let glideSeconds: Double = 0.24
        /// 1回のスワイプで進める最大枚数。勢いの読み取りが跳ねても飛びすぎないための保険。
        static let maxStepsPerSwipe = 12
        /// 端をはみ出して引ける最大の枚数。ゴムのように、引くほど伸びにくくなる。
        static let overscrollLimit: Double = 0.45
        /// これ以上動いたらタップではなくスワイプとして扱う。
        static let dragThreshold: CGFloat = 8
    }

    let decks: [Deck]
    let coverURL: (Deck) -> URL?
    let summary: (Deck) -> DeckProgressSummary
    let onOpen: (Deck) -> Void
    let onExport: (Deck) -> Void
    let onDelete: (Deck) -> Void
    let canExport: (Deck) -> Bool
    let canDelete: (Deck) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// いま中央に来ている位置。整数がちょうど中央で、指で動かしている間も滑っている間も
    /// この1つの値が動く。端をはみ出した値も一度そのまま持ち、表示のときにゴムで縮める。
    @State private var position: Double = 0
    /// ドラッグを始めたときの位置。指の移動量はここからの差として足す。
    @State private var dragStartPosition: Double?
    @State private var suppressTapUntil = Date.distantPast
    /// 実際に組み上がったカードの高さ。文字を大きくしても重なり方が崩れないよう、
    /// 決め打ちにせず測った値を使う。
    @State private var cardHeight = Metrics.estimatedCardHeight

    var body: some View {
        GeometryReader { proxy in
            let slotHeight = cardHeight * Metrics.slotRatio

            DeckCarouselStage(position: displayPosition) { position in
                ZStack {
                    ForEach(slots(position: position)) { slot in
                        card(slot, width: proxy.size.width)
                            .rotation3DEffect(
                                .degrees(reduceMotion ? 0 : tilt(for: slot.offset)),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .center,
                                perspective: Metrics.perspective
                            )
                            .scaleEffect(reduceMotion ? 1 : scale(for: slot.offset))
                            .opacity(opacity(for: slot.offset))
                            .offset(y: verticalOffset(for: slot.offset, slotHeight: slotHeight))
                            .zIndex(-abs(slot.offset))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
            .contentShape(Rectangle())
            .coordinateSpace(name: "deckCarousel")
            .gesture(dragGesture(stepHeight: slotHeight))
        }
        .onPreferenceChange(DeckCardHeightKey.self) { height in
            if height > 0 { cardHeight = height }
        }
        .onAppear { position = Double(centerIndex) }
        .onChange(of: decks.map(\.id)) { _, _ in
            dragStartPosition = nil
            position = Double(centerIndex)
        }
    }

    // MARK: - 1枚のカード

    private func card(_ slot: Slot, width: CGFloat) -> some View {
        let deck = slot.deck
        let progress = summary(deck)
        let coverSize = coverSize(cardWidth: width)

        return VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            HStack(alignment: .top, spacing: WireMetrics.spacingL) {
                DeckCoverImage(url: coverURL(deck), symbol: DeckCoverSymbol.forDeck(id: deck.id))
                    .frame(width: coverSize, height: coverSize)

                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text(deck.deckName)
                        .wireFont(.titleS)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DeckMasteryBar(
                        masteredCount: progress.masteredCount,
                        totalCount: progress.totalCount,
                        ratio: progress.masteryRatio,
                        percentText: progress.masteryPercentText
                    )
                }
            }
            DeckStatusChips(summary: progress)
        }
        .padding(WireMetrics.spacingL)
        .frame(width: width, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
        .background {
            // 重なり幅の元になるカードの高さを測る。見た目の拡大・回転は寸法を変えない。
            GeometryReader { proxy in
                Color.clear.preference(key: DeckCardHeightKey.self, value: proxy.size.height)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { activate(slot) }
        // 何もできないデッキ（配信中の公式デッキ）には、空のメニューを出さない。
        .deckMenu(isEnabled: canExport(deck) || canDelete(deck)) { menu(for: deck) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityValue(
            "\(centerIndex + 1) 件目、全 \(decks.count) 件。"
                + "\(progress.totalCount) 語のうち \(progress.masteredCount) 語を習得"
        )
        .accessibilityHint("上下にはじくと別のデッキへ移ります")
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(by: 1)
            case .decrement: move(by: -1)
            @unknown default: break
            }
        }
        // 中央以外は VoiceOver から隠し、中央の1枚で前後移動と起動をまかなう。
        .accessibilityHidden(slot.step != 0)
    }

    @ViewBuilder
    private func menu(for deck: Deck) -> some View {
        if canExport(deck) {
            Button("書き出す") { onExport(deck) }
        }
        if canDelete(deck) {
            Button("削除", role: .destructive) { onDelete(deck) }
        }
    }

    /// 端のカードは中央へ寄せるだけ。中央のカードだけがデッキを開く。
    private func activate(_ slot: Slot) {
        guard Date.now >= suppressTapUntil else { return }
        if slot.step == 0 {
            onOpen(slot.deck)
        } else {
            move(by: slot.step)
        }
    }

    private func coverSize(cardWidth: CGFloat) -> CGFloat {
        min(max(cardWidth * Metrics.coverWidthRatio, Metrics.coverWidthRange.lowerBound),
            Metrics.coverWidthRange.upperBound)
    }

    // MARK: - 並べ方

    /// 画面に出す分だけのカード。
    private func slots(position: Double) -> [Slot] {
        layout.placements(position: position).map {
            Slot(deck: decks[$0.index], offset: $0.offset)
        }
    }

    private var layout: DeckCarouselLayout { DeckCarouselLayout(count: decks.count) }

    /// いちばん近いデッキの位置。
    private var centerIndex: Int { layout.clamp(Int(position.rounded())) }

    /// 実際に描く位置。端をはみ出したぶんはゴムのように縮めて、引っぱった手ごたえを出す。
    private var displayPosition: Double {
        layout.rubberBanded(position, limit: Metrics.overscrollLimit)
    }

    /// 中央からの縦の位置。遠いほど詰めるので、倒れて薄くなったカードが離れて浮かない。
    private func verticalOffset(for offset: Double, slotHeight: CGFloat) -> CGFloat {
        let compressed = DeckCarouselLayout.compressedOffset(offset)
        return CGFloat(compressed) * slotHeight
    }

    /// 上のカードは上端が奥へ、下のカードは下端が奥へ倒れる。中央から離れるほど強く
    /// 倒すが、端で頭打ちにする。まっすぐ比例させると2枚離れたカードが裏返る。
    private func tilt(for offset: Double) -> Double {
        let limit = Double(DeckCarouselLayout.maxNeighbors)
        let normalized = (offset / limit).clamped(to: -1...1)
        return -Metrics.tiltDegrees * sin(normalized * .pi / 2)
    }

    private func scale(for offset: Double) -> Double {
        max(0.4, 1 - Metrics.scaleFalloff * abs(offset))
    }

    private func opacity(for offset: Double) -> Double {
        let edgeFade = ((2.5 - abs(offset)) / 0.5).clamped(to: 0...1)
        return max(0, 1 - Metrics.opacityFalloff * abs(offset)) * edgeFade
    }

    // MARK: - 動かす

    private func dragGesture(stepHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: Metrics.dragThreshold, coordinateSpace: .named("deckCarousel"))
            .onChanged { value in
                guard decks.count > 1, stepHeight > 0 else { return }
                suppressTapUntil = .now.addingTimeInterval(0.35)
                let start = dragStartPosition ?? position
                dragStartPosition = start
                position = start - Double(value.translation.height / stepHeight)
            }
            .onEnded { value in
                suppressTapUntil = .now.addingTimeInterval(0.35)
                dragStartPosition = nil
                guard decks.count > 1, stepHeight > 0 else {
                    position = Double(centerIndex)
                    return
                }
                // 指を離したあとも勢いのぶんだけ滑らせ、いちばん近いカードで止める。
                let velocity = Double(value.velocity.height / stepHeight)
                let glide = -velocity * Metrics.glideSeconds
                let steps = Int((position + glide).rounded()) - centerIndex
                let target = layout.clamp(
                    centerIndex + steps.clamped(
                        to: -Metrics.maxStepsPerSwipe...Metrics.maxStepsPerSwipe
                    )
                )
                settle(to: target)
            }
    }

    private func move(by steps: Int) {
        let next = layout.clamp(centerIndex + steps)
        guard next != centerIndex else { return }
        settle(to: next)
    }

    /// 目的のカードまで滑らせて止める。遠いほど長くかけて減速する。
    private func settle(to index: Int) {
        let distance = abs(Double(index) - position)
        withAnimation(scrollAnimation(distance: distance)) {
            position = Double(index)
        }
    }

    /// 慣性で滑るときの動き。距離が長いほどゆっくり減速させる。
    /// 「視差効果を減らす」ときは弾みを付けず、まっすぐ止める。
    private func scrollAnimation(distance: Double) -> Animation {
        guard !reduceMotion else { return .easeOut(duration: 0.25) }
        return .spring(response: min(0.34 + 0.09 * distance, 0.95), dampingFraction: 0.86)
    }

    /// 画面に出す1枚ぶんの位置。
    private struct Slot: Identifiable {
        let deck: Deck
        /// 中央からの距離。0 が中央、負が上、正が下。指で動かしている途中は小数。
        let offset: Double

        var id: Int { deck.id }
        /// タップしたときに動かす枚数。
        var step: Int { Int(offset.rounded()) }
    }
}

/// 位置そのものを補間し、カードの出入り・奥行き順も毎フレーム同じ位置から計算する。
/// 各カードの変形だけを個別にアニメーションすると、途中の並び順が最終位置へ飛ぶ。
private struct DeckCarouselStage<Content: View>: View, Animatable {
    var position: Double
    @ViewBuilder var content: (Double) -> Content

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        content(position)
            .transaction { $0.animation = nil }
    }
}

/// カルーセルの並び計算。見た目と切り離してあるので、単体で確かめられる。
///
/// 一周はしない。先頭のデッキの上と、最後のデッキの下には何も出さない。
struct DeckCarouselLayout {
    /// 中央の上下それぞれに出す最大枚数。
    static let maxNeighbors = 2

    let count: Int
    private let maxNeighbors: Int

    init(count: Int, maxNeighbors: Int = DeckCarouselLayout.maxNeighbors) {
        self.count = max(count, 0)
        self.maxNeighbors = maxNeighbors
    }

    /// 画面に出す位置。`position` はいま中央に来ている枚数で、指で動かしている途中は小数。
    /// 戻り値は `decks` の添字と、中央からの距離の組。
    func placements(position: Double) -> [(index: Int, offset: Double)] {
        guard count > 0 else { return [] }
        let limit = Double(maxNeighbors) + 0.5

        return (0..<count).compactMap { index in
            let offset = Double(index) - position
            guard abs(offset) <= limit else { return nil }
            return (index, offset)
        }
    }

    /// 距離が増えても順序が逆転しない圧縮曲線。
    static func compressedOffset(_ offset: Double) -> Double {
        offset / (1 + 0.21 * abs(offset))
    }

    /// 端で止める。先頭より上と、最後より下へは進まない。
    func clamp(_ index: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    /// 端をはみ出した位置を、ゴムのように縮めて返す。
    ///
    /// 引くほど伸びにくくなり、どれだけ引いても `limit` 枚より先へは出ない。範囲の中では
    /// 何も変えないので、指の動きにそのまま付いてくる。
    func rubberBanded(_ position: Double, limit: Double) -> Double {
        let last = Double(max(count - 1, 0))
        guard limit > 0 else { return min(max(position, 0), last) }
        if position < 0 { return -stretched(-position, limit: limit) }
        if position > last { return last + stretched(position - last, limit: limit) }
        return position
    }

    private func stretched(_ distance: Double, limit: Double) -> Double {
        (1 - 1 / (distance / limit + 1)) * limit
    }
}

/// デッキの表紙。正方形に切り抜いて枠いっぱいに出す。
/// 画像が無いときと読み込めないときは、デッキの見分け記号を置いた仮表紙にする。
struct DeckCoverImage: View {
    let url: URL?
    let symbol: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
        // 大きさは外から渡された正方形に決めさせ、画像はその中へはみ出したぶんを切り落とす。
        // 画像自身に大きさを決めさせると、横長の絵が枠を押し広げてしまう。
        return Color.clear
            .overlay {
                CardImage(url: url, contentMode: .fill, showsLoadingIndicator: false) {
                    fallback
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            WireImagePlaceholder(radius: WireMetrics.radiusControl)
            Image(systemName: symbol)
                .wireFont(.titleL)
        }
    }
}

/// カードの高さを親へ伝える。いちばん高いカードに合わせる。
private struct DeckCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// 中身があるときだけ長押しメニューを付ける。
    @ViewBuilder
    func deckMenu<Content: View>(
        isEnabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isEnabled {
            contextMenu { content() }
        } else {
            self
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
