import SwiftUI

struct WordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var word: WordCard
    @State private var isEditing = false
    @State private var isTagging = false
    @State private var isExpanded = false
    @State private var isFocused = false
    @GestureState private var sheetDrag: CGFloat = 0
    let onSaved: (WordCard) -> Void

    init(word: WordCard, onSaved: @escaping (WordCard) -> Void) {
        _word = State(initialValue: word)
        self.onSaved = onSaved
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let restingHeight = height * (isExpanded ? 0.68 : 0.29)
            let panelHeight = min(height * 0.72, max(height * 0.25, restingHeight - sheetDrag))
            let stageHeight = max(100, isFocused ? height - 110 : height - panelHeight - 64)
            let cardHeight = max(80, min(stageHeight - 24, (geometry.size.width - 56) / 0.64))
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [Color(red: 0.87, green: 0.86, blue: 0.94),
                                        Color(red: 0.72, green: 0.81, blue: 0.91)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        Text("WORD COLLECTION")
                            .font(.caption.weight(.semibold))
                            .tracking(2)
                        Spacer()
                        if !isFocused {
                            Button { isTagging = true } label: { Image(systemName: "tag") }
                                .accessibilityLabel("タグを編集")
                            Button { isEditing = true } label: { Image(systemName: "square.and.pencil") }
                                .accessibilityLabel("単語を編集")
                        }
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("単語リストに戻る")
                    }
                    .font(.title3)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .frame(height: 56)

                    InteractiveWordCard(word: word, reduceMotion: reduceMotion)
                        .frame(width: cardHeight * 0.64, height: cardHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: stageHeight)
                        .onTapGesture { animate { isFocused.toggle() } }
                        .accessibilityAction(named: isFocused ? "詳細を表示" : "カードを拡大") {
                            animate { isFocused.toggle() }
                        }
                    Spacer(minLength: 0)
                }
                if !isFocused {
                    detailPanel(height: panelHeight)
                        .background(alignment: .bottom) {
                            Color(red: 0.94, green: 0.98, blue: 1)
                                .frame(height: geometry.safeAreaInsets.bottom + 1)
                                .offset(y: geometry.safeAreaInsets.bottom)
                                .ignoresSafeArea(edges: .bottom)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button("詳細を表示", systemImage: "chevron.up") {
                        animate { isFocused = false }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                }
            }
            .foregroundStyle(Color(red: 0.19, green: 0.25, blue: 0.32))
        }
        .sheet(isPresented: $isEditing) {
            WordEditSheet(word: word) { savedWord in
                word = savedWord
                onSaved(savedWord)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isTagging) {
            TagSheet(word: word) { savedWord in
                word = savedWord
                onSaved(savedWord)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func detailPanel(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button {
                animate { isExpanded.toggle() }
            } label: {
                VStack(spacing: 12) {
                    Capsule().fill(.secondary.opacity(0.3)).frame(width: 44, height: 5)
                    HStack {
                        Label("カード詳細", systemImage: "rectangle.on.rectangle")
                        Spacer()
                        Text(isExpanded ? "小さくする" : "もっと見る")
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "詳細シートを縮小" : "詳細シートを展開")
            .simultaneousGesture(DragGesture(minimumDistance: 12)
                .updating($sheetDrag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    animate {
                        if value.predictedEndTranslation.height < -35 { isExpanded = true }
                        if value.predictedEndTranslation.height > 35 { isExpanded = false }
                    }
                })
            Divider().opacity(0.3)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(word.text).font(.largeTitle.bold())
                    Text(word.meaning).font(.title3)
                    WordMetaRow(word: word)
                    if !word.tags.isEmpty { TagChipRow(tags: word.tags) }
                    DetailBlock(title: "例文", text: word.sentenceEnglish ?? "例文は準備中です。")
                    if let japanese = word.sentenceJapanese {
                        DetailBlock(title: "日本語", text: japanese)
                    }
                    DetailBlock(title: "学習メモ", text: word.learning?.studySummary ?? "まだ学習していないカードです。")
                    DetailBlock(title: "覚え方 · サンプル", text: "絵の場面を思い浮かべながら、単語を声に出してみましょう。")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.94, green: 0.98, blue: 1))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .shadow(color: .black.opacity(0.12), radius: 20, y: -5)
    }

    private func animate(_ changes: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84), changes)
    }
}

/// 詳細シートの主役カード。指の位置で傾き、横に払うと表裏がめくれる。
///
/// - 傾き: 指の「位置」を見る。カードの中心からの距離を角度に写す。
/// - めくり: 指の「移動量」を見る。deadZone を越えた分だけ Y 軸に回し、
///   離した時点で 0° か 180° の近い方へ寄せる。
///   途中で止めても角度が飛ばないよう、離した瞬間に
///   `baseAngle` へ現在角をそのまま引き継いでから寄せている。
///
/// 裏面は学習カードと同じ `StudyCardBack` を使う。裏の情報設計は1か所に置く。
private struct InteractiveWordCard: View {
    let word: WordCard
    let reduceMotion: Bool

    /// 指を離したあとに残る角度。0 が表、180 が裏。
    @State private var baseAngle: Double = 0
    /// いま指で動かしている分の横移動量。離すと 0 に戻る。
    @State private var flipDrag: CGFloat = 0
    /// カードが回っている最中か。裏面のスクロールを開けてよいかの判定に使う。
    @State private var isTurning = false
    @GestureState private var touch: CGPoint?

    /// この距離までは傾きだけ。越えた分からめくりが始まる。
    private let deadZone: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)
            let x = touch.map { min(1, max(-1, ($0.x / width - 0.5) * 2)) } ?? 0
            let y = touch.map { min(1, max(-1, ($0.y / height - 0.5) * 2)) } ?? 0
            // めくり始めたら傾きを譲る。2つの回転が同じ軸で重ならないようにする。
            let tilt = reduceMotion ? 0 : Double(max(0, 1 - abs(flipDrag) / deadZone))
            let angle = baseAngle + flipAngle(for: flipDrag, width: width)
            let showsBack = isBack(angle)

            ZStack {
                face(showsBack: showsBack)
                if !reduceMotion {
                    LinearGradient(colors: [.clear, .white.opacity(touch == nil ? 0.08 : 0.38), .clear],
                                   startPoint: UnitPoint(x: 0.1 + x * 0.4, y: y * 0.3),
                                   endPoint: UnitPoint(x: 0.9 + x * 0.4, y: 1 + y * 0.3))
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.75), lineWidth: 1))
            .shadow(color: .black.opacity(touch == nil ? 0.16 : 0.24),
                    radius: touch == nil ? 12 : 24, x: -x * 12, y: 12 - y * 10)
            .rotation3DEffect(.degrees(-y * 13 * tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(angle + x * 13 * tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(touch == nil || reduceMotion ? 1 : 1.025)
            .animation(touch == nil && !reduceMotion ? .spring(response: 0.4, dampingFraction: 0.7) : nil, value: touch)
            .simultaneousGesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("wordCardTouch"))
                    .updating($touch) { value, state, _ in state = value.location }
                    .onChanged { value in
                        if !isTurning, abs(value.translation.width) > deadZone { isTurning = true }
                        flipDrag = value.translation.width
                    }
                    .onEnded { value in settle(value, width: width) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(showsBack ? "\(word.text) の裏面" : word.text)
            .accessibilityHint("タップで拡大。左右に払うと裏返ります")
            .accessibilityAction(named: showsBack ? "表に戻す" : "裏返す") { flip() }
        }
        .coordinateSpace(name: "wordCardTouch")
    }

    // MARK: - 面

    /// 表裏は同じ外形に重ねる。半分より回ったところで入れ替える。
    /// 裏面は 180° 逆に回してあり、カードが裏を向いたときに正しい向きで立つ。
    @ViewBuilder
    private func face(showsBack: Bool) -> some View {
        ZStack {
            front
                .opacity(showsBack ? 0 : 1)
                .allowsHitTesting(!showsBack)
            back
                .opacity(showsBack ? 1 : 0)
                .allowsHitTesting(showsBack)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private var front: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(.white)
            VStack(spacing: 0) {
                Color.clear
                    .overlay {
                        if let url = word.illustrationURL {
                            CardImage(url: url, contentMode: .fill, showsLoadingIndicator: true) {
                                placeholder
                            }
                        } else {
                            placeholder
                        }
                    }
                    .clipped()
                VStack(spacing: 5) {
                    Text(word.text).font(.title2.bold()).lineLimit(2).minimumScaleFactor(0.6)
                    Text(word.partOfSpeech?.uppercased() ?? "VOCABULARY")
                        .font(.caption2.weight(.medium)).tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(5)
            // 裏があることは、隠された操作なので小さく示しておく。
            flipHint
        }
    }

    private var back: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(.white)
            // 回っている間はスクロールを閉じる。理由は `StudyCardBack` 側に書いてある。
            StudyCardBack(content: WordCardContent(card: word), isScrollEnabled: !isTurning)
                .padding(16)
        }
    }

    private var flipHint: some View {
        Image(systemName: "arrow.2.squarepath")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(7)
            .background(.black.opacity(0.28), in: Circle())
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.82, green: 0.91, blue: 0.96),
                                    Color(red: 0.90, green: 0.87, blue: 0.97)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .ultraLight))
                Text("画像は準備中")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - 角度

    /// 横移動量を角度に写す。deadZone のぶんは傾きに使うので差し引く。
    /// カード幅の半分だけ払えば 180°、つまり1回ぶんめくれる。
    private func flipAngle(for translation: CGFloat, width: CGFloat) -> Double {
        let excess = max(0, abs(translation) - deadZone)
        let turn = Double(excess / (width * 0.5)) * 180
        return (translation < 0 ? -1 : 1) * min(360, turn)
    }

    private func isBack(_ angle: Double) -> Bool {
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return normalized > 90 && normalized < 270
    }

    /// 指を離したときに、いちばん近い面へ寄せる。
    /// 勢いを少し足すので、浅く速く払っただけでもめくれる。
    private func settle(_ value: DragGesture.Value, width: CGFloat) {
        let current = baseAngle + flipAngle(for: value.translation.width, width: width)
        let momentum = value.predictedEndTranslation.width - value.translation.width
        let predicted = current + Double(momentum / (width * 0.5)) * 180 * 0.35
        let snapped = (predicted / 180).rounded() * 180

        // 角度を飛ばさずに引き継ぐ。ここは見た目が変わらないので animation を切る。
        var handover = Transaction()
        handover.disablesAnimations = true
        withTransaction(handover) {
            baseAngle = current
            flipDrag = 0
        }
        turn(to: snapped)
    }

    private func flip() {
        isTurning = true
        turn(to: baseAngle + 180)
    }

    /// 目的の角度まで回し、止まったところで裏面のスクロールを開け直す。
    private func turn(to angle: Double) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            baseAngle = angle
        } completion: {
            isTurning = false
        }
    }
}

struct WordMetaRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            StatusBadge(status: word.learningStatus)
            if let part = word.partOfSpeech {
                WirePill(title: part.uppercased(), font: .caption)
            }
            if let learning = word.learning {
                WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
            }
            WirePill(title: "\(word.tags.count)タグ", font: .caption)
        }
        .padding(.top, WireMetrics.spacingXS)
    }
}

struct DetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text(title)
                .wireFont(.caption)
            Text(text)
                .wireFont(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}

extension WordLearningSnapshot {
    var studySummary: String {
        "SRS Lv.\(srsLevel) / \(repetitions)回復習 / 次回: \(formattedNextReviewDate) / 間隔: \(intervalDays)日"
    }

    var formattedNextReviewDate: String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        return nextReviewDate
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
