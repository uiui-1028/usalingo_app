import SwiftUI

struct StudyCardView: View {
    let card: WordCard
    let showAnswer: Bool

    var body: some View {
        VStack(spacing: WireMetrics.spacingM) {
            HStack {
                Image(systemName: "bolt")
                    .wireFont(.titleS)
                Spacer()
                WirePill(
                    title: showAnswer ? "ANSWER" : "QUESTION",
                    isSelected: showAnswer,
                    font: .caption
                )
            }

            illustration

            Text(card.text)
                .wireFont(.titleL)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let part = card.partOfSpeech {
                Text(part.uppercased())
                    .wireFont(.caption)
            }

            StudyStatusBadge(status: card.learningStatus)

            if let learning = card.learning {
                HStack(spacing: WireMetrics.spacingXS) {
                    WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
                    WirePill(title: "\(learning.repetitions)回", font: .caption)
                    WirePill(title: "次: \(learning.shortNextReviewDate)", font: .caption)
                }
            }

            if !card.tags.isEmpty {
                HStack(spacing: WireMetrics.spacingXS) {
                    ForEach(card.tags.prefix(3), id: \.self) { tag in
                        WirePill(title: tag, font: .caption)
                    }
                }
            }

            VStack(spacing: WireMetrics.spacingS) {
                Text(showAnswer ? card.meaning : "タップで答えを見る")
                    .wireFont(showAnswer ? .titleS : .caption)
                    .multilineTextAlignment(.center)
                if showAnswer, let sentence = card.sentenceEnglish {
                    Text(sentence)
                        .wireFont(.body)
                        .multilineTextAlignment(.center)
                }
                if showAnswer, let sentence = card.sentenceJapanese {
                    Text(sentence)
                        .wireFont(.caption)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(WireMetrics.spacingXL)
        .outlineSurface(
            radius: WireMetrics.radiusCard,
            stroke: WireMetrics.strokeHeavy,
            shadow: .card
        )
        .frame(maxWidth: 350)
        .aspectRatio(0.74, contentMode: .fit)
    }

    /// イラスト枠。読み込めないときは対角クロスのプレースホルダを出す。
    ///
    /// `Color.clear` で 3:2 の枠を先に決めてから overlay で画像を敷き、角丸で切り抜く。
    /// こうしないと `scaledToFill` の画像が枠線の外へはみ出す（単語リストのカードと同じ約束）。
    @ViewBuilder
    private var illustration: some View {
        if let url = card.illustrationURL {
            Color.clear
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay {
                    CardImage(url: url, contentMode: .fill) {
                        Color.clear
                    }
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous)
                )
                .outlineSurface(
                    radius: WireMetrics.radiusLarge,
                    stroke: WireMetrics.strokeBase,
                    shadow: nil
                )
        } else {
            Color.clear
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay {
                    WireImagePlaceholder(radius: WireMetrics.radiusLarge)
                }
        }
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

private extension WordLearningSnapshot {
    var shortNextReviewDate: String {
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
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
