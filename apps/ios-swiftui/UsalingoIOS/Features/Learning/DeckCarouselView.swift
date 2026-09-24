import SwiftUI

/// 学習タブの並びの1枠。デッキか、両端に置く空き枠。
enum DeckSlot: Hashable, Identifiable {
    case deck(Deck)
    case empty(DeckSlotEdge)

    var id: String {
        switch self {
        case .deck(let deck): return "deck-\(deck.id)"
        case .empty(let edge): return "empty-\(edge)"
        }
    }

    var deck: Deck? {
        if case .deck(let deck) = self { return deck }
        return nil
    }

    /// 先頭と末尾に空き枠を1つずつ置く。デッキが無いときは空き枠1つだけにする。
    static func slots(for decks: [Deck]) -> [DeckSlot] {
        guard !decks.isEmpty else { return [.empty(.bottom)] }
        return [.empty(.top)] + decks.map(DeckSlot.deck) + [.empty(.bottom)]
    }
}

/// 空き枠がどちらの端か。追加したデッキはこの端へ入る。
enum DeckSlotEdge: Hashable {
    case top
    case bottom
}

/// 学習画面のデッキ一覧。上下のスワイプで回す平面のカルーセル。
///
/// 動きは音声モードのカルーセル（`AudioCarouselMotion`）と同じで、枠に磁石のように吸い付き、
/// 指を離すと勢いに応じた枠でピタッと止まる。中央の枠だけが縦に広がり、デッキなら表紙・名前・進み具合を
/// 見せる。ほかは表紙と名前だけの細い帯にする。両端の空き枠をタップするとデッキを足せる。
/// 空き枠も中央では同じだけ広げる。高さがそろうので、どの枠の間でも1枠ぶんの移動量が同じになる。
struct DeckCarouselView: View {
    /// 見た目の寸法。帯と中央の大きさはここだけで決める。
    private enum Metrics {
        static let bandHeight: CGFloat = 64
        static let expandedHeight: CGFloat = 240
        static let spacing: CGFloat = 10
        /// 表紙が占める横幅の割合。帯でも中央でも同じ幅にして、高さだけを伸ばす。
        static let coverWidthRatio: CGFloat = 0.45
        /// 帯の横幅。中央のカードより少し細くして、主役を目立たせる。
        static let bandWidthRatio: CGFloat = 0.92
    }

    private let layout = DeckCarouselLayout(
        bandHeight: Metrics.bandHeight,
        expandedHeight: Metrics.expandedHeight,
        spacing: Metrics.spacing
    )

    let decks: [Deck]
    /// 最初に中央へ置くデッキ。見つからなければ先頭のデッキにする。
    let centeredDeckId: Int?
    let coverURL: (Deck) -> URL?
    let summary: (Deck) -> DeckProgressSummary
    let onOpen: (Deck) -> Void
    let onSelect: (Deck) -> Void
    let onAdd: (DeckSlotEdge) -> Void
    let onExport: (Deck) -> Void
    let onDelete: (Deck) -> Void
    let canExport: (Deck) -> Bool
    let canDelete: (Deck) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = AudioCarouselMotion()
    /// 中央で止まっている枠。動いている途中は、指を離したあと止まるまで変えない。
    @State private var centerIndex = 0

    private var slots: [DeckSlot] { DeckSlot.slots(for: decks) }

    var body: some View {
        GeometryReader { proxy in
            let center = -motion.position / layout.stride

            ZStack {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let offset = CGFloat(index) - center
                    let y = layout.y(offset: offset)
                    // 画面の外の枠は描かない。
                    if abs(y) < proxy.size.height {
                        let expansion = layout.expansion(offset: offset)
                        slotView(slot, index: index, expansion: expansion,
                                 width: proxy.size.width, height: layout.height(offset: offset))
                            .offset(y: y)
                            .zIndex(Double(expansion))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        .onAppear { synchronize() }
        .onDisappear { motion.stop() }
        .onChange(of: slots.map(\.id)) { _, _ in synchronize() }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced, motion.isMoving {
                motion.snap(to: motion.nearestIndex, animated: false, completion: complete)
            }
        }
    }

    // MARK: - 1枠

    @ViewBuilder
    private func slotView(_ slot: DeckSlot, index: Int, expansion: CGFloat,
                          width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (Metrics.bandWidthRatio + (1 - Metrics.bandWidthRatio) * expansion)
        Group {
            switch slot {
            case .deck(let deck):
                deckCard(deck, index: index, expansion: expansion, width: cardWidth, height: height)
            case .empty(let edge):
                emptyCard(edge, width: cardWidth, height: height)
            }
        }
        // ponytail: VoiceOver は中央の枠だけを読み、上下の操作で隣へ移すだけの最低限。
        // 作り込みは後でまとめて行う（AGENTS.md の方針）。
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: snap(to: centerIndex + 1)
            case .decrement: snap(to: centerIndex - 1)
            @unknown default: break
            }
        }
        .accessibilityHidden(index != centerIndex)
    }

    private func deckCard(_ deck: Deck, index: Int, expansion: CGFloat,
                          width: CGFloat, height: CGFloat) -> some View {
        let progress = summary(deck)
        let isCenter = index == centerIndex

        return HStack(alignment: .top, spacing: WireMetrics.spacingM) {
            DeckCoverImage(url: coverURL(deck), symbol: DeckCoverSymbol.forDeck(id: deck.id))
                .frame(width: width * Metrics.coverWidthRatio)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(deck.deckName)
                    .wireFont(expansion > 0.5 ? .titleS : .label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // 中央へ近づくほど、進み具合を浮かび上がらせる。
                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    DeckMasteryBar(
                        masteredCount: progress.masteredCount,
                        totalCount: progress.totalCount,
                        ratio: progress.masteryRatio,
                        percentText: progress.masteryPercentText
                    )
                    ViewThatFits(in: .horizontal) {
                        DeckStatusChips(summary: progress)
                        DeckStatusChips(summary: progress, axis: .vertical)
                    }
                }
                .opacity(Double(expansion))
            }
            .padding(.vertical, WireMetrics.spacingS)
        }
        .padding(WireMetrics.spacingS)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
        .contentShape(Rectangle())
        .onTapGesture { isCenter ? onOpen(deck) : snap(to: index) }
        // 何もできないデッキ（配信中の公式デッキ）には、空のメニューを出さない。
        .deckMenu(isEnabled: canExport(deck) || canDelete(deck)) { menu(for: deck) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityValue("\(progress.totalCount) 語のうち \(progress.masteredCount) 語を習得")
        .accessibilityHint("選んだ遊び方で開きます")
        .accessibilityAddTraits(.isButton)
    }

    /// 空き枠。どこにあってもタップでデッキライブラリを開く。
    private func emptyCard(_ edge: DeckSlotEdge, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
            .fill(BentoTone.l3.fill)
            .overlay {
                Image(systemName: "plus")
                    .wireFont(.titleS)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(WireColor.surface))
                    .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
            }
            .overlay(
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .strokeBorder(WireColor.ink, style: StrokeStyle(lineWidth: WireMetrics.strokeHair, dash: [5, 4]))
            )
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture { onAdd(edge) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(edge == .top ? "先頭にデッキを追加" : "末尾にデッキを追加")
            .accessibilityHint("デッキライブラリを開きます")
            .accessibilityAddTraits(.isButton)
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

    // MARK: - 動かす

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard slots.count > 1 else { return }
                if !motion.isDragging {
                    motion.beginDrag(at: value.time.timeIntervalSinceReferenceDate)
                }
                motion.drag(translation: value.translation.height, at: value.time.timeIntervalSinceReferenceDate)
            }
            .onEnded { value in
                guard motion.isDragging else { return }
                motion.endDrag(at: value.time.timeIntervalSinceReferenceDate,
                               animated: !reduceMotion, completion: complete)
            }
    }

    /// 覚えているデッキを中央へ置き直す。デッキの増減で並びが変わったときも呼ぶ。
    private func synchronize() {
        let slots = self.slots
        let remembered = slots.firstIndex { $0.deck?.id == centeredDeckId && centeredDeckId != nil }
        let firstDeck = slots.firstIndex { $0.deck != nil }
        centerIndex = remembered ?? firstDeck ?? 0
        motion.configure(stride: layout.stride, count: slots.count, index: centerIndex)
    }

    private func snap(to index: Int) {
        let target = min(max(0, index), slots.count - 1)
        guard target != centerIndex else { return }
        motion.snap(to: target, animated: !reduceMotion, completion: complete)
    }

    private func complete(at index: Int) {
        centerIndex = index
        if let deck = slots[index].deck { onSelect(deck) }
    }
}

/// カルーセルの並び計算。見た目と切り離してあるので、単体で確かめられる。
///
/// 中央の枠ほど高く、離れた枠は帯の高さになる。どの枠も広がり方が同じなので、中央と隣の
/// 中心どうしは常に `stride` だけ離れ、指の移動と枠の移動がそろう。一周はしない。
struct DeckCarouselLayout {
    let bandHeight: CGFloat
    let expandedHeight: CGFloat
    let spacing: CGFloat

    /// 1枠ぶん進むときに動く距離。中央の枠と隣の帯の、中心どうしの間隔と同じ。
    var stride: CGFloat { (bandHeight + expandedHeight) / 2 + spacing }

    /// 中央へどれだけ近いか。`offset` は中央からの枠の数で、0 がちょうど中央、1 以上離れると帯。
    func expansion(offset: CGFloat) -> CGFloat {
        max(0, 1 - abs(offset))
    }

    func height(offset: CGFloat) -> CGFloat {
        bandHeight + (expandedHeight - bandHeight) * expansion(offset: offset)
    }

    /// 画面中央からの縦位置。中央の隣までは `stride` 刻み、その先は帯どうしの間隔で並べる。
    func y(offset: CGFloat) -> CGFloat {
        let distance = abs(offset)
        let y = min(distance, 1) * stride + max(distance - 1, 0) * (bandHeight + spacing)
        return offset < 0 ? -y : y
    }
}

/// デッキの並び順と、最後に中央へ置いたデッキを端末へ覚えておく。
///
/// 利用者ごとに分けて覚える。端末で作ったデッキの番号は利用者ごとに 1 から振るので、
/// 分けないと別の人の同じ番号のデッキを指してしまう。
/// 覚えていないデッキは末尾へ足し、消えたデッキは詰める。
struct DeckOrderStore {
    private let orderKey: String
    private let selectedKey: String
    private let defaults: UserDefaults

    init(accountId: String, defaults: UserDefaults = .standard) {
        orderKey = "learning.deckOrder.\(accountId)"
        selectedKey = "learning.selectedDeck.\(accountId)"
        self.defaults = defaults
    }

    /// 覚えた順に並べ、その結果を覚え直す。
    func arranged(_ decks: [Deck]) -> [Deck] {
        let saved = defaults.array(forKey: orderKey) as? [Int] ?? []
        let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let result = decks.enumerated()
            .sorted { lhs, rhs in
                (rank[lhs.element.id] ?? saved.count + lhs.offset)
                    < (rank[rhs.element.id] ?? saved.count + rhs.offset)
            }
            .map(\.element)
        defaults.set(result.map(\.id), forKey: orderKey)
        return result
    }

    /// 追加したデッキを、選んだ空き枠の側の端へ置く。
    func place(deckId: Int, at edge: DeckSlotEdge, in currentOrder: [Int]) {
        var ids = currentOrder.filter { $0 != deckId }
        switch edge {
        case .top: ids.insert(deckId, at: 0)
        case .bottom: ids.append(deckId)
        }
        defaults.set(ids, forKey: orderKey)
    }

    var selectedDeckId: Int? {
        get { defaults.object(forKey: selectedKey) as? Int }
        nonmutating set { defaults.set(newValue, forKey: selectedKey) }
    }

    /// 退会したときに、その人の並び順を消す。
    func removeAll() {
        defaults.removeObject(forKey: orderKey)
        defaults.removeObject(forKey: selectedKey)
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
