import SwiftUI

/// 学習カード。表に主情報、裏に補足情報を置き、Y 軸のフリップで入れ替える。
///
/// Anki 時代のカードテンプレート（品詞・単語・例文・画像・訳・類義語・語源）の情報設計を
/// 引き継ぎ、囲いだけをマテリアルから Outline Wireframe に置き換えている。
///
/// - 凸（浮いた面）= `outlineSurface(shadow:)`
/// - 凹（沈んだ面）= `wireRecessed()`（面を一段濃くして細い枠線を回す）
struct StudyCardView: View {
    let card: WordCard
    let showAnswer: Bool
    /// 裏返しているか。裏面だけが縦スクロールする。
    var isFlipped: Bool = false

    private var content: WordCardContent { WordCardContent(card: card) }

    var body: some View {
        ZStack {
            // 表裏はどちらも同じ外形。半分より回ったところで入れ替える。
            face { StudyCardFront(card: card, content: content, showAnswer: showAnswer) }
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            face { StudyCardBack(content: content) }
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        // 外形は表裏で変えない。裏返しても束の重なりとスワイプ判定はずれない。
        .frame(maxWidth: 350)
        .aspectRatio(0.74, contentMode: .fit)
    }

    private func face<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(WireMetrics.spacingL)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .outlineSurface(
                radius: WireMetrics.radiusCard,
                stroke: WireMetrics.strokeHeavy,
                shadow: .card
            )
    }
}

// MARK: - 表

/// 表面。単語・イラスト・品詞・訳・例文・学習ステータスを、枠に収まる高さで並べる。
/// スクロールしない面なので、長い文は行数を絞って縮める。
private struct StudyCardFront: View {
    let card: WordCard
    let content: WordCardContent
    let showAnswer: Bool

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            StudyCardHeader(
                title: showAnswer ? "ANSWER" : "QUESTION",
                isSelected: showAnswer
            )

            partOfSpeechRow

            Text(card.text)
                .wireFont(.titleL)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            illustration

            if showAnswer {
                Text(card.meaning)
                    .wireFont(.titleS)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let sentence = card.sentenceEnglish, !sentence.isEmpty {
                    WireRecessedText(sentence)
                }
                if let sentence = card.sentenceJapanese, !sentence.isEmpty {
                    WireRecessedText(sentence)
                }
            } else {
                Text("タップで答えを見る")
                    .wireFont(.caption)
            }

            Spacer(minLength: 0)

            statusPills
        }
    }

    /// 該当する品詞だけを凹ませ、残りは線を持たない平らな文字にする。
    private var partOfSpeechRow: some View {
        HStack(spacing: 0) {
            ForEach(displayedPartsOfSpeech) { part in
                let isActive = part == content.partOfSpeech
                Text(part.rawValue)
                    .wireFont(.caption, color: isActive ? WireColor.ink : WireColor.subText)
                    .fontWeight(isActive ? .bold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WireMetrics.spacingXS)
                    .modifier(PartOfSpeechHighlight(isActive: isActive))
            }
        }
        .padding(WireMetrics.spacingXS)
        .outlineSurface(
            radius: WireMetrics.radiusPill,
            stroke: WireMetrics.strokeBase,
            shadow: nil
        )
    }

    /// 接続詞のカードでは、前置詞の枠を接続詞に置き換える（Anki テンプレートと同じ扱い）。
    private var displayedPartsOfSpeech: [WordPartOfSpeech] {
        var parts = WordPartOfSpeech.displayOrder
        if content.partOfSpeech == .conjunction,
           let index = parts.firstIndex(of: .preposition) {
            parts[index] = .conjunction
        }
        return parts
    }

    private var statusPills: some View {
        HStack(spacing: WireMetrics.spacingXS) {
            StudyStatusBadge(status: card.learningStatus)
            if let learning = card.learning {
                WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
                WirePill(title: "\(learning.repetitions)回", font: .caption)
            }
            if let tag = card.tags.first {
                WirePill(title: tag, font: .caption)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// イラスト枠。読み込めないときは対角クロスのプレースホルダを出す。
    @ViewBuilder
    private var illustration: some View {
        if let url = card.illustrationURL {
            CardImage(url: url) {
                Color.clear
            }
            .frame(maxWidth: .infinity, maxHeight: 130)
            .outlineSurface(
                radius: WireMetrics.radiusLarge,
                stroke: WireMetrics.strokeBase,
                shadow: nil
            )
        } else {
            WireImagePlaceholder(radius: WireMetrics.radiusLarge)
                .frame(height: 110)
        }
    }
}

// MARK: - 裏

/// 裏面。補足情報だけを載せ、枠に収まらないときだけ縦スクロールさせる。
private struct StudyCardBack: View {
    let content: WordCardContent

    private static let scrollSpace = "StudyCardBackScroll"

    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    /// 中身が枠に収まらないときだけスクロールを開ける。収まるときは
    /// スクロールもバウンスも起こさない。
    private var isOverflowing: Bool {
        contentHeight > viewportHeight + 1
    }

    /// まだ下に続きがあるか。読み切ったらフェードを消す。
    private var hasMoreBelow: Bool {
        isOverflowing && scrollOffset < contentHeight - viewportHeight - 1
    }

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            StudyCardHeader(title: "MORE", isSelected: true, showsSampleTag: content.usesSampleData)

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: isOverflowing) {
                    VStack(spacing: WireMetrics.spacingM) {
                        if content.hasSupplements {
                            synonymSection
                            etymologySection
                        } else {
                            Text("補足情報はまだありません")
                                .wireFont(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.top, WireMetrics.spacingL)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        ScrollMetricsReader(
                            coordinateSpace: Self.scrollSpace,
                            contentHeight: $contentHeight,
                            offset: $scrollOffset
                        )
                    )
                }
                .coordinateSpace(name: Self.scrollSpace)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(!isOverflowing)
                .onAppear { viewportHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, newValue in viewportHeight = newValue }
                // 続きがあることは、下端を薄く消して示す。読み切ったら消える。
                .overlay(alignment: .bottom) {
                    if hasMoreBelow {
                        LinearGradient(
                            colors: [WireColor.surface.opacity(0), WireColor.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: WireMetrics.spacingXL)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var synonymSection: some View {
        if !content.synonyms.isEmpty {
            BentoGroup(title: "類義語", tone: .l2, padding: WireMetrics.spacingM) {
                VStack(spacing: WireMetrics.spacingS) {
                    ForEach(content.synonyms) { synonym in
                        synonymItem(synonym)
                    }
                }
            }
        }
    }

    private func synonymItem(_ synonym: WordSynonym) -> some View {
        VStack(spacing: WireMetrics.spacingS) {
            // 上段は Anki と同じ 2 : 3。単語は平ら、訳は凹ませて役割を分ける。
            HStack(alignment: .center, spacing: WireMetrics.spacingS) {
                Text(synonym.word)
                    .wireFont(.titleS)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(synonym.meaning.isEmpty ? "—" : synonym.meaning)
                    .wireFont(.label, color: WireColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WireMetrics.spacingS)
                    .padding(.horizontal, WireMetrics.spacingS)
                    .wireRecessed()
            }
            .frame(maxWidth: .infinity)

            WireRecessedText(synonym.note ?? "—")
        }
        .padding(WireMetrics.spacingM)
        .outlineSurface(
            radius: WireMetrics.radiusControl,
            stroke: WireMetrics.strokeBase,
            shadow: .card
        )
    }

    @ViewBuilder
    private var etymologySection: some View {
        if let etymology = content.etymology, !etymology.isEmpty {
            BentoGroup(title: "語源", tone: .l1, shadow: .card, padding: WireMetrics.spacingM) {
                Text(etymology)
                    .wireFont(.caption)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 部品

private struct StudyCardHeader: View {
    let title: String
    var isSelected: Bool = false
    var showsSampleTag: Bool = false

    var body: some View {
        HStack {
            Image(systemName: "bolt")
                .wireFont(.titleS)
            Spacer()
            if showsSampleTag {
                WirePill(title: "サンプル", font: .caption)
            }
            WirePill(title: title, isSelected: isSelected, font: .caption)
        }
    }
}

/// 例文・訳文・補足に使う凹んだ文章ブロック。
private struct WireRecessedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .wireFont(.caption)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, WireMetrics.spacingS)
            .padding(.horizontal, WireMetrics.spacingM)
            .wireRecessed()
    }
}

/// スクロール中身の高さと、いまどこまで送ったかを測って返す。
/// スクロールが要るか、まだ下に続きがあるかの判定に使う。
private struct ScrollMetricsReader: View {
    let coordinateSpace: String
    @Binding var contentHeight: CGFloat
    @Binding var offset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.frame(in: .named(coordinateSpace)).minY
            Color.clear
                .onChange(of: proxy.size.height, initial: true) { _, newValue in
                    contentHeight = newValue
                }
                .onChange(of: top, initial: true) { _, newValue in
                    offset = -newValue
                }
        }
    }
}

/// 品詞行の当たっている枠だけを凹ませる。
private struct PartOfSpeechHighlight: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.wireRecessed(radius: WireMetrics.radiusPill)
        } else {
            content
        }
    }
}

private extension View {
    /// 沈んだ面。マテリアルの `inset box-shadow` にあたる表現を、
    /// 色を増やさずに「面を一段濃くする + 細い枠線」で置き換える。
    func wireRecessed(radius: CGFloat = WireMetrics.radiusSmall) -> some View {
        outlineSurface(
            radius: radius,
            stroke: WireMetrics.strokeHair,
            shadow: nil,
            fill: WireColor.groupL3
        )
    }
}

private struct StudyStatusBadge: View {
    let status: String?

    var body: some View {
        WirePill(title: title, isSelected: status == "mastered", font: .caption)
    }

    private var title: String {
        switch status {
        case "learning":
            "復習中"
        case "mastered":
            "習得済み"
        default:
            "未学習"
        }
    }
}
