import SwiftUI

struct StudyCardView: View {
    @EnvironmentObject private var designSettings: DesignSettings
    let card: WordCard
    let showAnswer: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius(designSettings) + 8, style: .continuous)
                .fill(AppStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: AppStyle.cornerRadius(designSettings) + 8, style: .continuous)
                        .stroke(AppStyle.line, lineWidth: 2)
                }
                .shadow(color: AppStyle.shadow, radius: 0, y: 7)

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title3.bold())
                        .foregroundStyle(AppStyle.sun)
                    Spacer()
                    Text(showAnswer ? "ANSWER" : "QUESTION")
                        .font(.caption.weight(.black))
                        .foregroundStyle(showAnswer ? AppStyle.accent : AppStyle.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((showAnswer ? AppStyle.accent : AppStyle.line).opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let url = card.illustrationURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 190)
                    .frame(maxWidth: .infinity)
                    .background(AppStyle.background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppStyle.line, lineWidth: 1)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppStyle.background)
                        .frame(height: 170)
                        .overlay {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(AppStyle.muted)
                        }
                }

                Text(card.text)
                    .font(.system(size: 36, weight: .black))
                    .minimumScaleFactor(0.65)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let part = card.partOfSpeech {
                    Text(part.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.muted)
                }

                StudyStatusBadge(status: card.learningStatus)

                if let learning = card.learning {
                    HStack(spacing: 6) {
                        studyMetaChip("Lv.\(learning.srsLevel)")
                        studyMetaChip("\(learning.repetitions)回")
                        studyMetaChip("次: \(learning.shortNextReviewDate)")
                    }
                }

                if !card.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(card.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppStyle.accent(designSettings).opacity(0.12))
                                .foregroundStyle(AppStyle.accent(designSettings))
                                .clipShape(Capsule())
                        }
                    }
                }

                VStack(spacing: 8) {
                    Text(showAnswer ? card.meaning : "タップで答えを見る")
                        .font(.headline)
                        .foregroundStyle(showAnswer ? AppStyle.accentDark : AppStyle.muted)
                        .multilineTextAlignment(.center)
                    if showAnswer, let sentence = card.sentenceEnglish {
                        Text(sentence)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    if showAnswer, let sentence = card.sentenceJapanese {
                        Text(sentence)
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: 350)
        .aspectRatio(0.74, contentMode: .fit)
    }

    private func studyMetaChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppStyle.background)
            .foregroundStyle(AppStyle.muted)
            .clipShape(Capsule())
    }
}

private struct StudyStatusBadge: View {
    @EnvironmentObject private var designSettings: DesignSettings
    let status: String?

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
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

    private var color: Color {
        switch status {
        case "learning":
            AppStyle.accent(designSettings)
        case "mastered":
            AppStyle.accentDark
        default:
            AppStyle.muted
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
