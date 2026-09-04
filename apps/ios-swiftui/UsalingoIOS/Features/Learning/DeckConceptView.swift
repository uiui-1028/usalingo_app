import SwiftUI

/// デッキを開いたときの「どう遊ぶか」を組み立てる画面（A-1〜A-6 / B-1・B-2・B-3・B-4・B-8）。
///
/// デザインタブと同じく、いまは表示だけの仮組み。選んだ内容のうち実際に効くのは
/// `StudyMode` だけで、残りは学習画面へ渡していない。
struct DeckConceptView: View {
    let deck: Deck
    let counts: StudyDeckCounts?

    @State private var selectedMode: StudyMode = .all
    @State private var selectedFormat: ConceptAnswerFormat = .englishToJapanese
    @State private var selectedVolume: ConceptVolume = .tenCards
    @State private var selectedNarrowings: Set<ConceptNarrowing> = []
    @State private var selectedTone: ConceptSentenceTone = .simple
    @State private var selectedStyle: ConceptIllustrationStyle = .realistic
    @State private var saveMessage: String?
    @State private var launch: StudyLaunch?

    private var sample: DeckDisplaySample { DeckDisplaySample.forDeck(id: deck.id) }

    var body: some View {
        ScrollView {
            VStack(spacing: WireMetrics.spacingL) {
                notice
                summaryGroup
                previewGroup
                modeGroup
                formatGroup
                volumeGroup
                narrowingGroup
                dataConceptGroup
                actionGroup
            }
            .padding(WireMetrics.screenPadding)
        }
        .background(WireColor.background)
        .navigationTitle(deck.deckName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WireColor.background, for: .navigationBar)
        .navigationDestination(item: $launch) { launch in
            StudySessionView(deck: launch.deck, studyMode: launch.mode)
        }
    }

    // MARK: - 断り書き

    private var notice: some View {
        BentoGroup(tone: .l1) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                Label("コンセプトは表示だけの仮組み", systemImage: "square.dashed")
                    .wireFont(.titleS)
                WireframeNotice(
                    text: "並びと言葉づかいを決めるための画面です。選んだ内容は保存されず、実際の出題に効くのは「どれを出すか」だけです。"
                )
            }
        }
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

    // MARK: - 保存 / 開始（A-5）

    private var actionGroup: some View {
        BentoGroup(tone: .l3) {
            VStack(spacing: WireMetrics.spacingM) {
                Button("このくみあわせを保存する") {
                    saveMessage = "保存先はまだありません。並びを見るための画面です。"
                }
                .buttonStyle(.wireSecondary)

                if let saveMessage {
                    Text(saveMessage)
                        .wireFont(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(WireMetrics.spacingM)
                        .outlineSurface(
                            radius: WireMetrics.radiusControl,
                            shadow: nil,
                            dashed: true,
                            fill: BentoTone.l3.fill
                        )
                }

                Button("はじめる（\(selectedVolume.startSummary)）") {
                    launch = StudyLaunch(deck: deck, mode: selectedMode)
                }
                .buttonStyle(.wirePrimary)
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

/// 学習画面へ渡す組み合わせ。`navigationDestination(item:)` に載せるためだけの入れ物。
private struct StudyLaunch: Identifiable, Hashable {
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
    NavigationStack {
        DeckConceptView(
            deck: Deck(id: 1, deckName: "TOEIC 基礎 600", description: "頻出600語。Part5 の土台をつくる。"),
            counts: StudyDeckCounts(newCount: 12, dueCount: 8)
        )
    }
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
