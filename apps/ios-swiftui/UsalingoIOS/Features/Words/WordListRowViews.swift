import SwiftUI

struct WordLibraryCard: View {
    let word: WordCard

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipped()

            Text(word.text)
                .wireFont(.titleS)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, WireMetrics.spacingS)
                .padding(.vertical, WireMetrics.spacingXS)
        }
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(word.text)
        .accessibilityHint("単語の詳細を開きます")
    }

    @ViewBuilder
    private var illustration: some View {
        if let url = word.illustrationURL {
            CardImage(
                url: url,
                contentMode: .fill,
                showsLoadingIndicator: true
            ) {
                imagePlaceholder()
            }
        } else {
            imagePlaceholder()
        }
    }

    private func imagePlaceholder() -> some View {
        WireImagePlaceholder(radius: WireMetrics.radiusControl)
    }
}

struct WordRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: WireMetrics.spacingM) {
            WireAvatar(initials: String(word.text.prefix(1)).uppercased(), diameter: 42)

            VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                HStack(spacing: WireMetrics.spacingS) {
                    Text(word.text)
                        .wireFont(.titleS)
                    if let part = word.partOfSpeech {
                        WirePill(title: part.uppercased(), font: .caption)
                    }
                    StatusBadge(status: word.learningStatus)
                }
                Text(word.meaning)
                    .wireFont(.body)
                    .lineLimit(1)
                if let sentence = word.sentenceEnglish, !sentence.isEmpty {
                    Text(sentence)
                        .wireFont(.caption)
                        .lineLimit(1)
                }
                if !word.tags.isEmpty {
                    TagChipRow(tags: Array(word.tags.prefix(3)))
                }
                if let learning = word.learning {
                    Text("次回: \(learning.formattedNextReviewDate)")
                        .wireFont(.caption)
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .wireFont(.caption)
        }
        .padding(WireMetrics.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
    }
}

struct StatusBadge: View {
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

struct TagChipRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingXS) {
                ForEach(tags, id: \.self) { tag in
                    WirePill(title: tag, font: .caption)
                }
            }
        }
    }
}
