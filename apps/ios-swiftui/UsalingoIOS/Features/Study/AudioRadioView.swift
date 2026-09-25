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
                        .glassBarSurface(in: RoundedRectangle(cornerRadius: WireMetrics.radiusLarge))
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
                .glassBarSurface(in: RoundedRectangle(cornerRadius: WireMetrics.radiusLarge))
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
        .buttonStyle(.glassBarIcon(diameter: 44, isSelected: isSelected))
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
        motion.snap(to: player.carouselIndex + 1, animated: !reduceMotion, gentle: true, completion: complete)
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
///
/// 手ざわりは Final Cut Pro のマグネティックタイムラインのように、枠へはっきり吸い付かせる。
/// - ドラッグ中は指に滑らかに付いてくる。枠の近くでは少しゆっくり、枠の境いでは少し速く動かし、
///   止まったり跳んだりさせずに、やわらかく枠へ引き寄せる。
/// - 指を離すと、勢いから行き先を決めて短い時間で行き過ぎずに止まる。滑ってから寄せる2段階はしない。
/// - 指で動かしたときだけ、枠の境いを越えるたびに軽く振動させる。自動送りはゆったり動かし、振動もしない。
@MainActor
final class AudioCarouselMotion: ObservableObject {
    private enum Magnet {
        /// 磁力の強さ。枠の近くでは指の (1 - strength) 倍、境いでは (1 + strength) 倍の速さで動く。
        /// 1 未満なら向きが逆になることはなく、指とのずれは最大で枠の間隔の strength / 2π。
        static let strength: CGFloat = 0.5
        /// 指を離したときの勢いを、どれだけ先まで見込むか（ミリ秒）。
        static let flickProjection: CGFloat = 150
        /// これより速く離したら、少なくとも1枠は進める（points / millisecond）。
        static let flickMinVelocity: CGFloat = 0.3
        /// 手で動かしたあとの止まり方。遠いほど少しだけ長くかける。
        static let snapBase: TimeInterval = 0.18
        static let snapPerSlot: TimeInterval = 0.04
        static let snapMax: TimeInterval = 0.34
        /// 自動送りのゆったりした動き。
        static let gentleSnap: TimeInterval = 0.420
    }

    @Published private(set) var position: CGFloat = 0
    private(set) var velocity: CGFloat = 0 // points / millisecond（参照JSと同じ）
    private(set) var isDragging = false
    private(set) var isMoving = false
    /// 枠に吸い付いたときに呼ぶ。テストでは差し替えて数える。
    var onDetent: (() -> Void)?
    private var stride: CGFloat = 174
    private var lastIndex = 0
    private var minimum: CGFloat { -CGFloat(lastIndex) * stride }
    var nearestIndex: Int { min(lastIndex, max(0, Int((-position / stride).rounded()))) }
    /// 指が指している位置。磁力で枠に張り付いている間は `position` とずれる。
    private var fingerPosition: CGFloat = 0
    /// 最後に吸い付いた枠。同じ枠で振動を繰り返さない。
    private var detentIndex = 0
    private var lastTranslation: CGFloat = 0
    private var lastDragTime: TimeInterval = 0
    private var snapStart: CGFloat = 0
    private var snapTarget: Int?
    private var snapElapsed: TimeInterval = 0
    private var snapDuration: TimeInterval = Magnet.gentleSnap
    private var isGentleSnap = false
    private var completion: ((Int) -> Void)?
    private var displayLink: CADisplayLink?
    private var previousFrame: TimeInterval = 0

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
        detentIndex = index
    }

    func beginDrag(at time: TimeInterval) {
        stop()
        isDragging = true
        // 見えている位置から指の位置を逆算し、つかんだ瞬間に札が跳ばないようにする。
        fingerPosition = unmagnetized(position)
        lastTranslation = 0
        lastDragTime = time
        velocity = 0
    }

    func drag(translation: CGFloat, at time: TimeInterval) {
        let delta = translation - lastTranslation
        let dt = max((time - lastDragTime) * 1000, 1)
        fingerPosition = rubberBand(fingerPosition + delta, resistance: 0.28)
        move(to: magnetized(fingerPosition), detents: true)
        if time > lastDragTime { velocity = velocity * 0.68 + delta / dt * 0.32 }
        lastTranslation = translation
        lastDragTime = time
    }

    /// 勢いから行き先を1つ決め、そこへまっすぐ止める。
    func endDrag(at time: TimeInterval, animated: Bool, completion: @escaping (Int) -> Void) {
        isDragging = false
        // 指を止めてから離した場合、古い速度でフリックしない。
        if time - lastDragTime > 0.08 { velocity = 0 }
        let current = (-fingerPosition / stride).rounded()
        var target = current
        // 「視差効果を減らす」ときは勢いを使わず、いちばん近い枠で止める。
        if animated {
            target = (-(fingerPosition + velocity * Magnet.flickProjection) / stride).rounded()
            if abs(velocity) > Magnet.flickMinVelocity, target == current {
                target += velocity < 0 ? 1 : -1
            }
        }
        snap(to: min(max(Int(target), 0), lastIndex), animated: animated, completion: completion)
    }

    /// `gentle` は自動送り用。ゆったり動かし、振動させない。
    func snap(to index: Int, animated: Bool, gentle: Bool = false, completion: @escaping (Int) -> Void) {
        stop()
        self.completion = completion
        snapTarget = index
        snapStart = position
        snapElapsed = 0
        isGentleSnap = gentle
        let slots = abs(-CGFloat(index) * stride - position) / max(stride, 1)
        snapDuration = gentle
            ? Magnet.gentleSnap
            : min(Magnet.snapBase + Magnet.snapPerSlot * TimeInterval(slots), Magnet.snapMax)
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
        guard isMoving, let target = snapTarget else { return }
        snapElapsed += seconds
        let t = min(snapElapsed / snapDuration, 1)
        // 自動送りは長く減速させ、手で動かしたあとは短く止めて余韻を残さない。
        let eased = isGentleSnap ? 1 - pow(1 - t, 4) : 1 - pow(1 - t, 3)
        move(to: snapStart + (-CGFloat(target) * stride - snapStart) * eased, detents: !isGentleSnap)
        if t >= 1 { finish(at: target) }
    }

    /// 枠の近くでは遅く、境いでは速くして、やわらかく枠へ引き寄せる。
    /// 枠と境いの上では指と同じ位置になり、その間もなめらかにつながる。
    /// 端より先（ゴムで伸びている間）は磁力をかけない。
    private func magnetized(_ raw: CGFloat) -> CGFloat {
        guard stride > 0, raw <= 0, raw >= minimum else { return raw }
        let slot = -raw / stride
        return -(slot - Magnet.strength * sin(2 * .pi * slot) / (2 * .pi)) * stride
    }

    /// `magnetized` の逆。単調に増えるので、ニュートン法で数回たどれば十分に合う。
    private func unmagnetized(_ shown: CGFloat) -> CGFloat {
        guard stride > 0, shown <= 0, shown >= minimum else { return shown }
        let target = -shown / stride
        var slot = target
        for _ in 0..<4 {
            let error = slot - Magnet.strength * sin(2 * .pi * slot) / (2 * .pi) - target
            slot -= error / (1 - Magnet.strength * cos(2 * .pi * slot))
        }
        return -slot * stride
    }

    /// 位置を動かし、枠の境いを越えて中央の枠が入れ替わったら1回だけ振動させる。
    private func move(to newPosition: CGFloat, detents: Bool) {
        position = newPosition
        guard detents, stride > 0 else { return }
        let index = Int((-newPosition / stride).rounded())
        guard (0...lastIndex).contains(index), index != detentIndex else { return }
        detentIndex = index
        if let onDetent { onDetent() } else { HapticFeedbackService.detent() }
    }

    private func rubberBand(_ y: CGFloat, resistance: CGFloat) -> CGFloat {
        if y > 0 { return y * resistance }
        if y < minimum { return minimum + (y - minimum) * resistance }
        return y
    }

    private func finish(at index: Int) {
        let callback = completion
        detentIndex = index
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
