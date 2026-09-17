import SwiftUI

/// 単語リストの背面（バナー）に置くデッキ選択の帯。
///
/// 前面のシートより1段退いた面に、所持しているデッキを札で並べる。
/// 真ん中に来ている札が「いま選んでいるデッキ」。
/// - 横スクロールは SwiftUI 標準の `ScrollView` に任せる。払った勢いの分だけ
///   何枚でも進み、真ん中の札で止まる。
/// - 札をタップすると、その札が真ん中へ来る。
/// - 下の点はタップ・なぞりで、そのデッキへ飛ぶ。
/// - 端は決めずに何周でも回る（A→B→C→D→A→…）。同じ並びを何周分も
///   つなげ、その真ん中から始める。
///
/// 画面の横幅いっぱいに置く（親で左右の余白を付けない）。余白を付けると、
/// `scrollPosition` で動かしたときだけ札がその余白ぶんずれて止まるため。
///
/// - Important: 札の帯と点の行は**戻るスワイプを止める領域**にしている
///   （`backSwipeProtectedRegion`）。同じ指の動きに「デッキ送り」と
///   「前の画面へ戻る」を両方は割り当てられないため。シートの上から
///   始めたスワイプでは今までどおり戻れる。
struct WordListDeckBanner: View {
    let decks: [Deck]
    /// 表示中のデッキ。札の位置をこれに合わせる。
    let selectedDeckID: Int?
    let onSelect: (Deck) -> Void

    /// 真ん中にある札の通し番号。割った余りで実際のデッキを決める。
    @State private var position: Int?

    /// 札の縦横比。横スワイプで送る「カード」に見える程度に縦長。
    private let cardAspectRatio: CGFloat = 0.92
    /// 点の行の高さと、その上下の間合い。
    private let indicatorRowHeight: CGFloat = 14
    /// スクロールが落ち着いてから単語を読み込むまでの待ち時間。
    /// 通り過ぎるだけのデッキまで読み込まないようにする。
    private let selectDelay: Duration = .milliseconds(250)

    /// 並びを何周分つなげるか。
    /// ponytail: 周の数で「無限」を作っている。端に近づいたら落ち着いた時点で
    /// 真ん中の同じ札へ戻すので、1回の払いで端まで届かない限り気づかれない。
    private var copies: Int { decks.count > 1 ? 400 : 1 }
    private var slotCount: Int { decks.count * copies }
    private var middleBase: Int { copies / 2 * decks.count }

    var body: some View {
        GeometryReader { proxy in
            let cardHeight = max(
                48,
                proxy.size.height - indicatorRowHeight - WireMetrics.spacingS
            )
            let cardWidth = cardHeight * cardAspectRatio

            VStack(spacing: WireMetrics.spacingS) {
                cardStrip(viewWidth: proxy.size.width, cardWidth: cardWidth, cardHeight: cardHeight)
                    .frame(height: cardHeight)

                WordListDeckPageDots(count: decks.count, currentIndex: currentDeckIndex) { target in
                    jump(toDeckIndex: target)
                }
                .frame(height: indicatorRowHeight)
                .backSwipeProtectedRegion()
            }
        }
        // 1枚通るごとに軽く震わせ、何枚進んだかを指に伝える。
        .sensoryFeedback(.selection, trigger: position)
        .task(id: position) {
            guard position != nil else { return }
            try? await Task.sleep(for: selectDelay)
            guard !Task.isCancelled else { return }
            recenterIfNearEdge()
            guard let deck = currentDeck, deck.id != selectedDeckID else { return }
            onSelect(deck)
        }
        // 保存していた選択や、読み込み後の先頭デッキへ札を合わせる。
        .onChange(of: selectedDeckID, initial: true) { syncToSelection() }
        .onChange(of: decks.count) { syncToSelection() }
    }

    /// 札の帯。真ん中の1枚を選択中として見せ、左右は送り先の予告として覗かせる。
    private func cardStrip(viewWidth: CGFloat, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let step = cardWidth + WireMetrics.spacingL
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<slotCount, id: \.self) { slot in
                    let isCenter = slot == position
                    WordListDeckTile(deck: deck(at: slot), isSelected: isCenter)
                        .frame(width: cardWidth, height: cardHeight)
                        .cardTapTarget {
                            guard !isCenter else { return }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                position = slot
                            }
                        }
                        // 札どうしの間は、スタックの間隔ではなく各枠の余白で取る。
                        // スタックの間隔を使うと、止まる位置が間隔ぶんずれるため。
                        .frame(width: step)
                }
            }
            .scrollTargetLayout()
            // 左右に余白を取り、先頭の札も真ん中で止まれるようにする。
            .padding(.horizontal, max(0, (viewWidth - step) / 2))
        }
        .scrollIndicators(.hidden)
        // 1枚ずつに制限しない。勢いよく払えば何枚でも進み、札の真ん中で止まる。
        .scrollTargetBehavior(DeckCenterSnapBehavior(step: step))
        .scrollPosition(id: $position, anchor: .center)
        // ここから始めた横の動きは「デッキ送り」に使う。戻るスワイプには渡さない。
        .backSwipeProtectedRegion()
    }

    /// 点で選んだデッキへ、今の周の中で近い向きに飛ぶ。
    private func jump(toDeckIndex target: Int) {
        let current = position ?? middleBase
        let next = current + target - currentDeckIndex
        guard next != current, (0..<slotCount).contains(next) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            position = next
        }
    }

    private func syncToSelection() {
        guard let deckIndex = decks.firstIndex(where: { $0.id == selectedDeckID }) ?? (decks.isEmpty ? nil : 0)
        else { return }
        if let position, position < slotCount, deckIndex == currentDeckIndex { return }
        position = middleBase + deckIndex
    }

    /// 端から1周以内に来たら、見た目の同じ真ん中の札へ黙って戻す。
    private func recenterIfNearEdge() {
        guard let position, decks.count > 1 else { return }
        guard position < decks.count || position >= slotCount - decks.count else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.position = middleBase + currentDeckIndex
        }
    }

    /// 通し番号を実際のデッキへ割り当てる。
    private func deck(at slot: Int) -> Deck {
        decks[slot % decks.count]
    }

    private var currentDeckIndex: Int {
        guard !decks.isEmpty else { return 0 }
        return (position ?? middleBase) % decks.count
    }

    private var currentDeck: Deck? {
        guard !decks.isEmpty else { return nil }
        return decks[currentDeckIndex]
    }
}

/// 慣性で止まる予定の位置を、いちばん近い札の真ん中へ丸める。
///
/// 左右の余白を「表示幅と札1枚ぶんの枠の差の半分」にしているので、札 k が真ん中に来る
/// スクロール位置はちょうど `k × 間隔` になる。止まる予定の位置で丸めるので、
/// 勢いが足りなければ少し戻り、行き過ぎそうなら少し進んで、ゆっくり止まる。
struct DeckCenterSnapBehavior: ScrollTargetBehavior {
    let step: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard step > 0 else { return }
        let maxX = max(0, context.contentSize.width - context.containerSize.width)
        let snapped = (target.rect.minX / step).rounded() * step
        target.rect.origin.x = min(max(snapped, 0), maxX)
    }
}

/// いま何枚目かを示す点の行。塗りつぶしが今いる場所。
/// タップした点、またはなぞって指の下にある点のデッキへ飛ぶ。
struct WordListDeckPageDots: View {
    let count: Int
    let currentIndex: Int
    let onPick: (Int) -> Void

    private let diameter: CGFloat = 8
    /// 点の行は低いので、指で触れる範囲だけ上下に広げる。
    private let touchOutset: CGFloat = 12

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            ForEach(0..<max(0, count), id: \.self) { position in
                Circle()
                    .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair)
                    .background(
                        Circle().fill(position == currentIndex ? WireColor.surface : WireColor.ink)
                    )
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle().inset(by: -touchOutset))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                pick(at: value.location.x, rowWidth: proxy.size.width)
                            }
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("デッキ \(currentIndex + 1) / \(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onPick((currentIndex + 1) % count)
            case .decrement: onPick((currentIndex - 1 + count) % count)
            @unknown default: break
            }
        }
    }

    /// 指の横位置から一番近い点を選ぶ。点の外へはみ出しても両端の点に丸める。
    private func pick(at x: CGFloat, rowWidth: CGFloat) {
        guard count > 0 else { return }
        let pitch = diameter + WireMetrics.spacingS
        let rowStart = (rowWidth - (CGFloat(count) * pitch - WireMetrics.spacingS)) / 2
        let target = min(count - 1, max(0, Int((x - rowStart + WireMetrics.spacingS / 2) / pitch)))
        guard target != currentIndex else { return }
        onPick(target)
    }
}

/// デッキ1件分の札。選択中は「線を太く・面を白く・影を付ける」で示す。
/// 色は使わない（Outline Wireframe Design System Section 2.1）。
struct WordListDeckTile: View {
    let deck: Deck
    let isSelected: Bool

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            DeckCoverMark(symbol: DeckDisplaySample.forDeck(id: deck.id).coverSymbol, size: 34)
            Text(deck.deckName)
                .wireFont(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WireMetrics.spacingS)
        .outlineSurface(
            radius: WireMetrics.radiusCard,
            stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
            shadow: isSelected ? .card : nil,
            fill: isSelected ? WireColor.surface : WireColor.scrim
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityHint("このデッキの単語に切り替えます")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
