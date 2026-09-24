import SwiftUI
import UIKit

/// 音源再生モード。デッキを1語ずつ「英単語 → 日本語訳 → 英語例文」の順に流し続ける。
///
/// 学習の記録は付けない。聞き流し専用と割り切り、復習間隔の計算を動かさない。
struct AudioRadioView: View {
    /// 設定ボタンを押したときに、道具の帯の上へせり出す板。1枚だけ開く。
    private enum SettingPanel {
        case rate
        case sleep
        case gap
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @StateObject private var player = RadioPlayer()
    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var openPanel: SettingPanel?

    var body: some View {
        // 単語カードを下、道具の帯を上に重ねる。スライダーを開いて帯が伸びても、
        // 下のカードは動かない。
        ZStack(alignment: .bottom) {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let loadErrorMessage {
                    StudyStatusView(
                        symbol: "wifi.exclamationmark",
                        title: "カードを読み込めませんでした",
                        message: loadErrorMessage,
                        actionTitle: "もう一度試す"
                    ) {
                        Task { await load() }
                    }
                } else if player.hasNoPlayableCard {
                    StudyStatusView(
                        symbol: "speaker.slash",
                        title: "流せる音源がありません",
                        message: "単語と例文の音声がそろったカードが、このデッキにはありません。",
                        actionTitle: "デッキに戻る"
                    ) {
                        dismiss()
                    }
                } else {
                    carousel
                        .ignoresSafeArea(.container, edges: .vertical)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(0)

            actionBar
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onDisappear { player.stop() }
    }

    // MARK: - カード

    /// 1枚の高さ。プレビューも同じ値を使う。
    fileprivate var cardHeight: CGFloat { 150 }

    private var carousel: some View {
        AudioCoverflowCarousel(player: player, cardHeight: cardHeight) { word, isCurrent in
            card(word, isCurrent: isCurrent)
        }
    }

    /// 1枚の札。左に絵、右に単語と訳。いま鳴っている札だけ濃く出す。
    @ViewBuilder
    fileprivate func card(_ card: WordCard?, isCurrent: Bool) -> some View {
        HStack(spacing: WireMetrics.spacingM) {
            illustration(for: card)

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(card?.text ?? "")
                    .wireFont(isCurrent ? .titleL : .titleS)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(card?.primaryMeaning ?? "")
                    .wireFont(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, WireMetrics.spacingM)
                    .padding(.vertical, WireMetrics.spacingXS)
                    .background(Capsule().fill(WireColor.surface))
                    .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))

                if isCurrent, let sentence = card?.sentenceEnglish {
                    Text(sentence)
                        .wireFont(.caption)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WireMetrics.spacingM)
        .frame(height: cardHeight)
        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: isCurrent ? .card : nil)
        .accessibilityElement(children: isCurrent ? .combine : .ignore)
        .accessibilityHidden(!isCurrent)
    }

    /// 札の絵。無いときは他のカードと同じ対角クロスの枠を出す。
    @ViewBuilder
    private func illustration(for card: WordCard?) -> some View {
        let side = cardHeight - WireMetrics.spacingM * 2
        Group {
            if let url = card?.illustrationURL {
                Color.clear.overlay {
                    CardImage(url: url, contentMode: .fill, showsLoadingIndicator: false) {
                        Color.clear
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
                .outlineSurface(radius: WireMetrics.radiusCard, stroke: WireMetrics.strokeBase, shadow: nil)
            } else {
                WireImagePlaceholder(radius: WireMetrics.radiusCard)
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: - 道具の帯

    /// 他のモードと同じ位置に置く道具の帯。ボタンは中身の幅ぶんだけ。
    ///
    /// 設定の板は帯に入れず、独立したもう1枚の帯として上へ出す。帯が伸び縮みしないので、
    /// スライダーを開いてもボタンの位置が変わらない。
    ///
    /// 次の語・前の語はロック画面とイヤホンから使う。画面では場所を取らないよう置かない。
    @ViewBuilder
    private var actionBar: some View {
        if !isLoading, loadErrorMessage == nil, !player.hasNoPlayableCard {
            VStack(spacing: WireMetrics.spacingS) {
                if let openPanel {
                    settingPanel(for: openPanel)
                        .padding(.horizontal, WireMetrics.spacingL)
                        .padding(.vertical, WireMetrics.spacingM)
                        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
                        .padding(.horizontal, WireMetrics.screenPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: WireMetrics.spacingS) {
                    toolbarButton("chevron.left", label: "学習に戻る") { dismiss() }
                    toolbarButton(
                        player.isPlaying ? "stop.fill" : "play.fill",
                        label: player.isPlaying ? "ストップ" : "再生"
                    ) {
                        player.togglePlay()
                    }
                    toolbarButton("speedometer", label: "再生速度を変える", isSelected: openPanel == .rate) {
                        toggle(panel: .rate)
                    }
                    toolbarButton(
                        "moon.zzz",
                        label: "スリープタイマー",
                        isSelected: openPanel == .sleep || player.sleep != .off
                    ) {
                        toggle(panel: .sleep)
                    }
                    toolbarButton("hourglass", label: "間の長さを変える", isSelected: openPanel == .gap) {
                        toggle(panel: .gap)
                    }
                }
                .padding(WireMetrics.spacingM)
                .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
            }
            .padding(.bottom, WireMetrics.spacingM)
        }
    }

    @ViewBuilder
    private func settingPanel(for panel: SettingPanel) -> some View {
        switch panel {
        case .rate:
            ratePanel
        case .sleep:
            sleepPanel
        case .gap:
            gapPanel
        }
    }

    /// 速さ。0.50倍から2.00倍まで、0.01刻みで決める。
    private var ratePanel: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            HStack {
                Text("速さ")
                    .wireFont(.caption)
                Spacer(minLength: 0)
                Text(rateText)
                    .wireFont(.label)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { player.rate },
                    set: { player.setRate(($0 * 100).rounded() / 100) }
                ),
                in: RadioPlayer.minimumRate...RadioPlayer.maximumRate,
                step: 0.01,
                onEditingChanged: { isEditing in
                    // 読み上げは速さを途中で差し替えられない。指を離したときだけ読み直す。
                    if !isEditing { player.commitRate() }
                }
            )
            .tint(WireColor.ink)
            .accessibilityLabel("再生速度")
            .accessibilityValue(rateText)
        }
    }

    private var rateText: String { String(format: "%.2fx", player.rate) }

    private var sleepPanel: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            HStack {
                Text("スリープタイマー")
                    .wireFont(.caption)
                Spacer(minLength: 0)
                if let deadline = player.sleepDeadline {
                    Text(timerInterval: Date()...deadline, countsDown: true)
                        .wireFont(.label)
                        .monospacedDigit()
                }
            }

            HStack(spacing: WireMetrics.spacingXS) {
                ForEach(RadioSleep.allCases) { option in
                    pill(title: option.title, isSelected: player.sleep == option) {
                        player.setSleep(option)
                    }
                }
            }
        }
    }

    /// 間（ポーズ）。0.5秒から5.0秒まで、0.1刻みで決める。
    private var gapPanel: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            HStack {
                Text("間（ポーズ）の長さ")
                    .wireFont(.caption)
                Spacer(minLength: 0)
                Text(gapText)
                    .wireFont(.label)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { player.gap },
                    set: { player.setGap(($0 * 10).rounded() / 10) }
                ),
                in: RadioPlayer.minimumGap...RadioPlayer.maximumGap,
                step: 0.1
            )
            .tint(WireColor.ink)
            .accessibilityLabel("間の長さ")
            .accessibilityValue(gapText)
        }
    }

    private var gapText: String { String(format: "%.1f秒", player.gap) }

    private func pill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .wireFont(.caption, color: isSelected ? WireColor.surface : WireColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(isSelected ? WireColor.ink : WireColor.surface))
                .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func toolbarButton(
        _ symbol: String,
        label: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(.wireIcon(diameter: 44, isSelected: isSelected))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(panel: SettingPanel) {
        withAnimation(.easeOut(duration: 0.15)) {
            openPanel = openPanel == panel ? nil : panel
        }
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            let cards = try await appState.studyDataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
            player.start(cards: cards, deckName: deck.deckName)
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }
}

/// CodePenの補間と慣性。手動は今の周の両端で止め、自動再生だけ次の周へ進む。
private struct AudioCoverflowCarousel<CardContent: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var player: RadioPlayer
    @StateObject private var motion = AudioCarouselMotion()
    @State private var pendingAutomaticAdvance = false
    @State private var showsNextLap = false
    @State private var synchronizedCardID: WordCard.ID?

    let cardHeight: CGFloat
    private let cardContent: (WordCard, Bool) -> CardContent

    init(
        player: RadioPlayer,
        cardHeight: CGFloat,
        @ViewBuilder cardContent: @escaping (WordCard, Bool) -> CardContent
    ) {
        self.player = player
        self.cardHeight = cardHeight
        self.cardContent = cardContent
    }

    private let cardSpacing: CGFloat = 3
    private var cardStride: CGFloat { cardHeight + cardSpacing }

    // 中央と隣、その先の縮んだ札同士で、それぞれの見た目の高さから中心間距離を決める。
    private func visualOffset(for progress: CGFloat) -> CGFloat {
        let distance = abs(progress)
        let centerScale = reduceMotion ? 1 : AudioCarouselStyle.centerScale
        let sideScale = reduceMotion ? 1 : AudioCarouselStyle.sideScale
        let firstStep = cardHeight * (centerScale + sideScale) / 2 + cardSpacing
        let offset = min(distance, 1) * firstStep
            + max(distance - 1, 0) * (cardHeight * sideScale + cardSpacing)
        return progress < 0 ? -offset : offset
    }

    // 中央の前後5枚を描き、画面外へ続ける。少数デッキの札は重複させない。
    private var visibleIndices: Range<Int> {
        let center = -motion.position / cardStride
        let count = player.playableCardCount + (showsNextLap ? 1 : 0)
        let lower = max(0, min(count, Int(floor(center)) - 5))
        let upper = max(lower, min(count, Int(ceil(center)) + 6))
        return lower..<upper
    }

    var body: some View {
        ZStack {
            ForEach(visibleIndices, id: \.self) { index in
                if let word = player.carouselCard(relativeOffset: index - player.carouselIndex) {
                    let progress = CGFloat(index) + motion.position / cardStride
                    let style = AudioCarouselStyle(progress: progress)
                    cardContent(word, abs(progress) < 0.5)
                        .frame(maxWidth: 310)
                        .padding(.horizontal, WireMetrics.screenPadding)
                        .scaleEffect(reduceMotion ? 1 : style.scale)
                        .modifier(AudioCarouselProjection(style: style, isEnabled: !reduceMotion))
                        .saturation(style.saturation)
                        .colorMultiply(Color(white: style.brightness))
                        .opacity(style.opacity)
                        .offset(y: visualOffset(for: progress))
                        .zIndex(100 - Double(abs(progress)) * 10)
                        .onTapGesture { snap(to: index) }
                }
            }
        }
        // 操作バーの背後まで札を流し、中央3枚分の枠では切り取らない。
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "次の単語へ") { snap(to: player.carouselIndex + 1) }
        .accessibilityAction(named: "前の単語へ") { snap(to: player.carouselIndex - 1) }
        .onAppear { synchronize() }
        .onDisappear { motion.stop() }
        .onChange(of: player.currentCard?.id) { _, id in
            // ロック画面・イヤホンからの選択は、進行中の手動スクロールより優先する。
            if id != synchronizedCardID { synchronize() }
        }
        .onChange(of: player.automaticAdvanceRequest) { _, _ in requestAutomaticAdvance() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, motion.isMoving || motion.isDragging {
                let index = showsNextLap ? player.carouselIndex + 1 : motion.nearestIndex
                motion.snap(to: index, animated: false, completion: complete)
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced, motion.isMoving {
                motion.snap(to: motion.nearestIndex, animated: false, completion: complete)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard player.playableCardCount > 1 else { return }
                if !motion.isDragging {
                    motion.beginDrag(at: value.time.timeIntervalSinceReferenceDate)
                    showsNextLap = false
                }
                motion.drag(translation: value.translation.height, at: value.time.timeIntervalSinceReferenceDate)
            }
            .onEnded { value in
                guard motion.isDragging else { return }
                motion.endDrag(at: value.time.timeIntervalSinceReferenceDate,
                               animated: !reduceMotion, completion: complete)
            }
    }

    private func synchronize() {
        pendingAutomaticAdvance = false
        showsNextLap = false
        synchronizedCardID = player.currentCard?.id
        motion.configure(stride: cardStride, count: player.playableCardCount, index: player.carouselIndex)
    }

    private func snap(to index: Int) {
        guard player.playableCardCount > 1 else { return }
        showsNextLap = false
        motion.snap(to: min(max(0, index), player.playableCardCount - 1),
                    animated: !reduceMotion, completion: complete)
    }

    private func requestAutomaticAdvance() {
        guard player.isPlaying else { return }
        guard scenePhase == .active, player.playableCardCount > 1 else {
            motion.stop()
            player.moveCarousel(by: 1, shouldPlay: player.isPlaying)
            synchronize()
            return
        }
        pendingAutomaticAdvance = true
        guard !motion.isDragging, !motion.isMoving else { return }
        showsNextLap = player.carouselIndex == player.playableCardCount - 1
        motion.snap(to: player.carouselIndex + 1, animated: !reduceMotion, completion: complete)
    }

    private func complete(at index: Int) {
        let steps = index - player.carouselIndex
        let needsAdvance = pendingAutomaticAdvance && steps == 0 && player.isPlaying
        pendingAutomaticAdvance = false
        if steps != 0 {
            // 再生ボタン・スリープ・割り込みによる最新の状態を尊重する。
            // 途中の札は鳴らさず、キュー更新と座標の付け替えを同じ非アニメーション取引で行う。
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                player.moveCarousel(by: steps, shouldPlay: player.isPlaying)
                synchronize()
            }
        } else {
            showsNextLap = false
        }
        if needsAdvance { requestAutomaticAdvance() }
    }
}

/// 距離の補間値は参照JSと共通。brightnessは加算ではなくRGBへの乗算。
struct AudioCarouselStyle {
    static let centerScale: CGFloat = 1.06
    static let sideScale: CGFloat = 0.92
    let progress: CGFloat
    private var t: CGFloat { min(abs(progress), 1) }
    var scale: CGFloat { Self.centerScale + (Self.sideScale - Self.centerScale) * t }
    var rotation: CGFloat { min(12, max(-12, progress * -7)) }
    var depth: CGFloat { 35 - 95 * t }
    var opacity: Double { 1 - 0.6 * min(Double(abs(progress)) / 2.3, 1) }
    var saturation: Double { 1.08 - 0.46 * min(Double(abs(progress)) / 2, 1) }
    var brightness: Double { 1 - 0.32 * min(Double(abs(progress)) / 2, 1) }
}

/// CSSのtransform-origin: center center。透視変換もカード中央を基準にする。
struct AudioCarouselProjection: GeometryEffect {
    let style: AudioCarouselStyle
    let isEnabled: Bool

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard isEnabled else { return ProjectionTransform(CGAffineTransform.identity) }
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 1000
        transform = CATransform3DTranslate(transform, 0, 0, style.depth)
        transform = CATransform3DRotate(transform, style.rotation * .pi / 180, 1, 0, 0)
        let centered = CATransform3DConcat(
            CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0), transform
        )
        return ProjectionTransform(CATransform3DConcat(
            centered, CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        ))
    }
}

/// フレームごとに座標そのものを更新する。SwiftUIの暗黙アニメーションで札を再移動しない。
@MainActor
final class AudioCarouselMotion: ObservableObject {
    @Published private(set) var position: CGFloat = 0
    private(set) var velocity: CGFloat = 0 // points / millisecond（参照JSと同じ）
    private(set) var isDragging = false
    private(set) var isMoving = false
    private var stride: CGFloat = 174
    private var lastIndex = 0
    private var minimum: CGFloat { -CGFloat(lastIndex) * stride }
    var nearestIndex: Int { min(lastIndex, max(0, Int((-position / stride).rounded()))) }
    private var lastTranslation: CGFloat = 0
    private var lastDragTime: TimeInterval = 0
    private var previousFrame: TimeInterval = 0
    private var snapStart: CGFloat = 0
    private var snapTarget: Int?
    private var snapElapsed: TimeInterval = 0
    private var completion: ((Int) -> Void)?
    private var displayLink: CADisplayLink?

    // CADisplayLinkはtargetを強参照するため、弱参照の中継を挟む。
    @MainActor
    private final class TickTarget: NSObject {
        weak var motion: AudioCarouselMotion?
        @objc func tick(_ link: CADisplayLink) { motion?.tick(link) }
    }

    func configure(stride: CGFloat, count: Int, index: Int) {
        stop()
        self.stride = stride
        lastIndex = max(0, count - 1)
        position = -CGFloat(index) * stride
    }

    func beginDrag(at time: TimeInterval) {
        stop()
        isDragging = true
        lastTranslation = 0
        lastDragTime = time
        velocity = 0
    }

    func drag(translation: CGFloat, at time: TimeInterval) {
        let delta = translation - lastTranslation
        let dt = max((time - lastDragTime) * 1000, 1)
        position = rubberBand(position + delta, resistance: 0.28)
        if time > lastDragTime { velocity = velocity * 0.68 + delta / dt * 0.32 }
        lastTranslation = translation
        lastDragTime = time
    }

    func endDrag(at time: TimeInterval, animated: Bool, completion: @escaping (Int) -> Void) {
        isDragging = false
        // 指を止めてから離した場合、古い速度でフリックしない。
        if time - lastDragTime > 0.08 { velocity = 0 }
        self.completion = completion
        if !animated || position > 0 || position < minimum || abs(velocity) <= 0.035 {
            snap(to: nearestIndex, animated: animated, completion: completion)
        } else {
            snapTarget = nil
            startDisplayLink()
        }
    }

    func snap(to index: Int, animated: Bool, completion: @escaping (Int) -> Void) {
        stop()
        self.completion = completion
        snapTarget = index
        snapStart = position
        snapElapsed = 0
        if animated {
            startDisplayLink()
        } else {
            position = -CGFloat(index) * stride
            finish(at: index)
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isMoving = false
        isDragging = false
        snapTarget = nil
        completion = nil
    }

    private func startDisplayLink() {
        let target = TickTarget()
        target.motion = self
        let link = CADisplayLink(target: target, selector: #selector(TickTarget.tick(_:)))
        previousFrame = CACurrentMediaTime()
        displayLink = link
        isMoving = true
        link.add(to: .main, forMode: .common)
    }

    private func tick(_ link: CADisplayLink) {
        let dt = max(0, link.timestamp - previousFrame)
        previousFrame = link.timestamp
        advanceFrame(seconds: dt)
    }

    // 時間を注入できるようにし、60Hz/120Hz・長いドラッグの逆戻りをテストする。
    func advanceFrame(seconds: TimeInterval) {
        guard isMoving else { return }
        if let target = snapTarget {
            snapElapsed += seconds
            let t = min(snapElapsed / 0.420, 1)
            let eased = 1 - pow(1 - t, 4)
            position = snapStart + (-CGFloat(target) * stride - snapStart) * eased
            if t >= 1 { finish(at: target) }
        } else {
            let dt = min(seconds * 1000, 32)
            position += velocity * dt
            if position > 0 || position < minimum {
                position = rubberBand(position, resistance: 0.18)
                velocity *= 0.75
            }
            velocity *= pow(0.935, dt / 16.67)
            if abs(velocity) <= 0.05 {
                // 元JSの±0.35判定は、この条件では到達しない。慣性後の最寄りへスナップする。
                snapTarget = nearestIndex
                snapStart = position
                snapElapsed = 0
            }
        }
    }

    private func rubberBand(_ y: CGFloat, resistance: CGFloat) -> CGFloat {
        if y > 0 { return y * resistance }
        if y < minimum { return minimum + (y - minimum) * resistance }
        return y
    }

    private func finish(at index: Int) {
        let callback = completion
        stop()
        callback?(index)
    }
}

#if DEBUG
#Preview("音声モード・カルーセル") {
    let words = [
        ("apple", "りんご", "I eat an apple."),
        ("book", "本", "This is my book."),
        ("cat", "猫", "The cat is sleeping."),
        ("dog", "犬", "The dog is running."),
        ("flower", "花", "The flower is red.")
    ].enumerated().map { index, item in
        WordCard(
            id: index + 1,
            text: item.0,
            meaning: item.1,
            partOfSpeech: nil,
            sentenceEnglish: item.2,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: "file:///dev/null",
            wordAudioAssetPath: "file:///dev/null",
            tags: [],
            learningStatus: nil,
            learning: nil
        )
    }
    let screen = AudioRadioView(deck: Deck(id: 0, deckName: "プレビュー", description: nil))
    AudioCoverflowCarousel(player: RadioPlayer.preview(cards: words), cardHeight: screen.cardHeight) { word, isCurrent in
        screen.card(word, isCurrent: isCurrent)
    }
    .background(WireColor.background)
}
#endif
