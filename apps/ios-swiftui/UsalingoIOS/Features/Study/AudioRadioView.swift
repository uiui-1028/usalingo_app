import SwiftUI

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
    /// 指で引っぱっている途中の量。離したときに送るか戻すかを決める。
    @GestureState private var dragOffset: CGFloat = 0

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
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear {
            player.stop()
            appState.isShellChromeHidden = false
        }
    }

    // MARK: - カード

    /// 1枚の高さ。前後の札をどれだけ見せるかもこの高さで決まる。
    private var cardHeight: CGFloat { 150 }

    /// 上下に前後の札を並べたカルーセル。上へ払うと次、下へ払うと前の音源へ移る。
    ///
    /// 前後の札は薄くして、いま鳴っている札だけがはっきり見えるようにする。
    private var carousel: some View {
        VStack(spacing: WireMetrics.spacingM) {
            card(player.previousCard, isCurrent: false)
            card(player.currentCard, isCurrent: true)
            card(player.nextCard, isCurrent: false)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 12)
                .updating($dragOffset) { value, state, _ in
                    // 端まで引っぱれてしまうと送り過ぎるので、1枚ぶんの半分で止める。
                    state = max(min(value.translation.height, cardHeight / 2), -cardHeight / 2)
                }
                .onEnded { value in
                    guard abs(value.translation.height) > 40 else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        if value.translation.height < 0 {
                            player.next()
                        } else {
                            player.previous()
                        }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "次の単語へ") { player.next() }
        .accessibilityAction(named: "前の単語へ") { player.previous() }
    }

    /// 1枚の札。左に絵、右に単語と訳。いま鳴っている札だけ濃く出す。
    @ViewBuilder
    private func card(_ card: WordCard?, isCurrent: Bool) -> some View {
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
        .opacity(card == nil ? 0 : (isCurrent ? 1 : 0.35))
        .scaleEffect(isCurrent ? 1 : 0.94)
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
