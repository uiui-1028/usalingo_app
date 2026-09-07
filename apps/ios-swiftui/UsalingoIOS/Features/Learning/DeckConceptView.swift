import SwiftUI

/// デッキを開いたときの「どう遊ぶか」を組み立てる画面（A-1〜A-6 / B-1・B-2・B-3・B-4・B-8）。
///
/// デザインタブと同じく、いまは表示だけの仮組み。選んだ内容のうち実際に効くのは
/// `StudyMode` だけで、残りは学習画面へ渡していない。
///
/// 「始める」ボタンはこの画面には置かない。面の外（`DeckConceptSheet` の上端）に
/// 出すため、選んだ学習モードだけを `Binding` で外へ渡す。
struct DeckConceptView: View {
    let deck: Deck
    let counts: StudyDeckCounts?
    /// 開始ボタンが面の外にあるので、選択結果は呼び出し側が持つ。
    @Binding var selectedMode: StudyMode

    @State private var selectedFormat: ConceptAnswerFormat = .englishToJapanese
    @State private var selectedVolume: ConceptVolume = .tenCards
    @State private var selectedNarrowings: Set<ConceptNarrowing> = []
    @State private var selectedTone: ConceptSentenceTone = .simple
    @State private var selectedStyle: ConceptIllustrationStyle = .realistic

    private var sample: DeckDisplaySample { DeckDisplaySample.forDeck(id: deck.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: WireMetrics.spacingL) {
                summaryGroup
                previewGroup
                modeGroup
                formatGroup
                volumeGroup
                narrowingGroup
                dataConceptGroup
            }
            .padding(WireMetrics.screenPadding)
            // 面の上端にあるつまみと最初の枠がぶつからないよう、少しだけ空ける。
            .padding(.top, WireMetrics.spacingS)
        }
        .background(WireColor.background)
    }

    // MARK: - デッキの周辺情報（B-1 / B-2 / B-3 / B-4）

    private var summaryGroup: some View {
        BentoGroup(tone: .l1) {
            HStack(alignment: .top, spacing: WireMetrics.spacingM) {
                DeckCoverMark(symbol: sample.coverSymbol)

                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text(deck.description ?? "説明はまだありません")
                        .wireFont(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DeckMasteryBar(
                        masteredCount: sample.masteredCount,
                        totalCount: sample.totalCount,
                        ratio: sample.masteryRatio,
                        percentText: sample.masteryPercentText
                    )

                    DeckStatusChips(sample: sample)
                }
            }
        }
    }

    // MARK: - 収録内容プレビュー（B-8）

    private var previewGroup: some View {
        BentoGroup(title: "収録されている語", tone: .l1) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                chipScroller(sample.previewWords) { word in
                    WirePill(title: word, font: .caption)
                }
                Text("ほか \(max(0, sample.totalCount - sample.previewWords.count)) 語")
                    .wireFont(.caption)
            }
        }
    }

    // MARK: - 1. どれを出すか（A-1）

    private var modeGroup: some View {
        BentoGroup(title: "1. どれを出すか", tone: .l2) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                ForEach(StudyMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        ConceptOptionRow(
                            title: mode.title,
                            detail: cardCountText(for: mode),
                            isSelected: selectedMode == mode
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
                }

                // 上の枚数は仮の数字なので、いま本当に出せる枚数をここで断る。
                WireframeNotice(text: actualCountText)
            }
        }
    }

    // MARK: - 2. どう答えるか（A-2）

    private var formatGroup: some View {
        BentoGroup(title: "2. どう答えるか", tone: .l2) {
            chipScroller(ConceptAnswerFormat.allCases) { format in
                Button {
                    selectedFormat = format
                } label: {
                    WirePill(title: format.title, isSelected: selectedFormat == format)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedFormat == format ? .isSelected : [])
            }
        }
    }

    // MARK: - 3. どれだけやるか（A-3）

    private var volumeGroup: some View {
        BentoGroup(title: "3. どれだけやるか", tone: .l2) {
            chipScroller(ConceptVolume.allCases) { volume in
                Button {
                    selectedVolume = volume
                } label: {
                    WirePill(title: volume.title, isSelected: selectedVolume == volume)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedVolume == volume ? .isSelected : [])
            }
        }
    }

    // MARK: - 4. しぼりこむ（A-4）

    private var narrowingGroup: some View {
        BentoGroup(title: "4. しぼりこむ", tone: .l2) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                chipScroller(ConceptNarrowing.allCases) { narrowing in
                    Button {
                        toggle(narrowing)
                    } label: {
                        WirePill(
                            title: narrowing.title,
                            isSelected: selectedNarrowings.contains(narrowing)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedNarrowings.contains(narrowing) ? .isSelected : [])
                }
                Text("選ばなければ、しぼりこみません。")
                    .wireFont(.caption)
            }
        }
    }

    // MARK: - 5. 見た目のコンセプト（A-6）

    private var dataConceptGroup: some View {
        BentoGroup(title: "5. 見た目のコンセプト", tone: .l3) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text("例文のトーン")
                        .wireFont(.label)
                    chipScroller(ConceptSentenceTone.allCases) { tone in
                        Button {
                            selectedTone = tone
                        } label: {
                            WirePill(title: tone.title, isSelected: selectedTone == tone)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedTone == tone ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text("イラストの画風")
                        .wireFont(.label)
                    chipScroller(ConceptIllustrationStyle.allCases) { style in
                        Button {
                            selectedStyle = style
                        } label: {
                            WirePill(title: style.title, isSelected: selectedStyle == style)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedStyle == style ? .isSelected : [])
                    }
                }

                WireframeNotice(
                    text: "いまは1つの語が例文と絵を1つずつしか持てないため、選んでも出題は変わりません。"
                )
            }
        }
    }

    // MARK: - 部品

    /// 横に並べて、はみ出したらスクロールさせる。折り返しは扱わない。
    private func chipScroller<Item: Identifiable, Chip: View>(
        _ items: [Item],
        @ViewBuilder chip: @escaping (Item) -> Chip
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(items) { item in
                    chip(item)
                }
            }
            // 枠線が縁で切れないように、内側へ半分だけ余白を持つ。
            .padding(.vertical, WireMetrics.strokeHeavy)
        }
    }

    private func chipScroller<Chip: View>(
        _ words: [String],
        @ViewBuilder chip: @escaping (String) -> Chip
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(words, id: \.self) { word in
                    chip(word)
                }
            }
            .padding(.vertical, WireMetrics.strokeHeavy)
        }
    }

    private func toggle(_ narrowing: ConceptNarrowing) {
        if selectedNarrowings.contains(narrowing) {
            selectedNarrowings.remove(narrowing)
        } else {
            selectedNarrowings.insert(narrowing)
        }
    }

    /// 枚数はすべて同じ仮データから引く。合計が総枚数と合うようにするため。
    private func cardCountText(for mode: StudyMode) -> String {
        switch mode {
        case .newOnly: return "\(sample.untouchedCount)枚"
        case .reviewOnly: return "\(sample.learningCount)枚"
        case .all: return "\(sample.totalCount)枚"
        case .weakOnly: return "\(sample.weakCount)枚"
        }
    }

    /// 実データで出せる枚数。仮の数字との食い違いをここで説明する。
    private var actualCountText: String {
        guard let counts else { return "いま出せる枚数はまだ読み込めていません。" }
        return "上の枚数は仮の数字です。いま実際に出せるのは 新規 \(counts.newCount)枚・復習 \(counts.dueCount)枚 です。"
    }
}

/// デッキ設定シートの中身。「始める」をシートの面の外（上）へ出すための入れ物。
///
/// 標準の `.sheet` は、指でつかんで動かしている途中の位置を外から読めない。
/// そこで「シートの外に置いたボタン」を別の View として重ねるのではなく、
/// シートの背景を透明にして、この1つの中身の中で
/// 「ボタンの帯」＋「面（パネル）」を縦に並べる。こうするとシートを上下に動かしても
/// ボタンと面はいつもくっついたまま動く。
struct DeckConceptSheet: View {
    let deck: Deck
    let counts: StudyDeckCounts?
    @Binding var selectedMode: StudyMode
    let onStart: (StudyMode) -> Void

    var body: some View {
        VStack(spacing: WireMetrics.spacingM) {
            startButton
            panel
        }
    }

    /// 面の外に浮かせる主行動。右寄せにして、面の上のすき間に置く。
    private var startButton: some View {
        Button("始める", systemImage: "play.fill") {
            onStart(selectedMode)
        }
        .buttonStyle(.wirePrimary)
        // wirePrimary は横いっぱいに広がるので、中身の幅で止める。
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHint("選択した学習モードで学習を始めます")
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, WireMetrics.screenPadding)
    }

    /// シートに見せる面。背景はシート側ではなくここで描く。
    private var panel: some View {
        DeckConceptView(deck: deck, counts: counts, selectedMode: $selectedMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: WireMetrics.radiusLarge,
                    topTrailingRadius: WireMetrics.radiusLarge,
                    style: .continuous
                )
                .fill(WireColor.background)
                // ホームインジケータの帯まで面を伸ばし、下に地が見えないようにする。
                .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) { grabber }
    }

    /// 標準のドラッグインジケータはシート枠の上端（＝ボタンの帯）に出てしまうので、
    /// 隠したうえで面の上端に自前で描く。
    private var grabber: some View {
        Capsule()
            .fill(WireColor.ink.opacity(0.25))
            .frame(width: 36, height: 5)
            .padding(.top, WireMetrics.spacingS)
            .accessibilityHidden(true)
    }
}

/// 学習画面へ渡す組み合わせ。`navigationDestination(item:)` に載せるためだけの入れ物。
struct StudyLaunch: Identifiable, Hashable {
    let deck: Deck
    let mode: StudyMode

    var id: String { "\(deck.id)-\(mode.rawValue)" }
}

/// 「どれを出すか」の1行。選択は色ではなく、枠線の太さと太字で示す（DS Section 3.2）。
private struct ConceptOptionRow: View {
    let title: String
    let detail: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: WireMetrics.spacingM) {
            Text(title)
                .wireFont(.label)
                .fontWeight(isSelected ? .bold : .semibold)
            Spacer(minLength: WireMetrics.spacingS)
            Text(detail)
                .wireFont(.caption)
        }
        .padding(WireMetrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineSurface(
            radius: WireMetrics.radiusControl,
            stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
            shadow: nil
        )
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous))
    }
}

#if DEBUG
#Preview("Deck Concept") {
    Group {
        DeckConceptView(
            deck: Deck(id: 1, deckName: "TOEIC 基礎 600", description: "頻出600語。Part5 の土台をつくる。"),
            counts: StudyDeckCounts(newCount: 12, dueCount: 8),
            selectedMode: .constant(.all)
        )
    }
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
