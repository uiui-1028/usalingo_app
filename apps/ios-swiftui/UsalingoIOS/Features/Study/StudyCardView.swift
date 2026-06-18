import SwiftUI

struct StudyCardView: View {
    let card: WordCard
    let showAnswer: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppStyle.surface)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

            GridBackground()
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .opacity(0.5)

            VStack(spacing: 12) {
                HStack {
                    Text("10")
                        .font(.title3.bold())
                    Spacer()
                    Text("10")
                        .font(.title3.bold())
                        .rotationEffect(.degrees(180))
                }

                if let url = card.illustrationURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxHeight: 190)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(height: 170)
                        .overlay(Text("No Image").foregroundStyle(AppStyle.muted))
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

                VStack(spacing: 8) {
                    Text(showAnswer ? card.meaning : "タップで答えを見る")
                        .font(.headline)
                        .foregroundStyle(showAnswer ? AppStyle.ink : AppStyle.muted)
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
        .frame(maxWidth: 340)
        .aspectRatio(0.74, contentMode: .fit)
    }
}
