import SwiftUI

struct WordLibraryCard: View {
    let word: WordCard

    var body: some View {
        VStack(spacing: 0) {
            illustration

            Text(word.text)
                .wireFont(.titleS)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, WireMetrics.spacingS)
                .padding(.vertical, WireMetrics.spacingXS)
        }
        .clipShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(word.text)
        .accessibilityHint("単語の詳細を開きます")
    }

    /// 画像は必ず 3:4 の枠へ収め、はみ出した分は枠の内側で切り落とす。
    /// `Color.clear` で枠の大きさを先に決めてから overlay で敷くことで、
    /// `scaledToFill` の画像がカードの外へ広がらないようにする。
    private var illustration: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                illustrationContent
            }
            .clipped()
    }

    @ViewBuilder
    private var illustrationContent: some View {
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
    let number: Int
    var hidesMeaningFromAccessibility = false
    var checkResult: Bool? = nil
    var reservesCheckResultSpace = false
    var isCheckTarget = false
    var coversMeaning = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)
                Text(word.text)
                    .wireFont(.titleS)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 20)
            .frame(maxHeight: .infinity, alignment: .leading)
            .containerRelativeFrame(.horizontal, count: 2, spacing: 0)

            Text(word.meaning)
                .wireFont(.body, color: Color(red: 0.65, green: 0.09, blue: 0.1))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 14)
                .padding(.trailing, reservesCheckResultSpace || checkResult != nil ? 42 : 14)
                .padding(.vertical, 20)
                .frame(maxHeight: .infinity, alignment: .leading)
            .containerRelativeFrame(.horizontal, count: 2, spacing: 0)
                .overlay(alignment: .leading) {
                    Rectangle().fill(WireColor.ink.opacity(0.12)).frame(width: 1)
                }
                .accessibilityHidden(hidesMeaningFromAccessibility)
                .overlay {
                    if coversMeaning {
                        Color(red: 1, green: 0.18, blue: 0.23)
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: .trailing) {
                    if let checkResult {
                        Image(systemName: checkResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, checkResult ? Color.black : Color.red)
                            .padding(.trailing, 10)
                            .accessibilityLabel(checkResult ? "わかる" : "わからない")
                    }
                }
        }
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        .background(number.isMultiple(of: 2) ? WireColor.surface : WireColor.ink.opacity(0.04))
        .overlay {
            if isCheckTarget {
                Rectangle().fill(Color.black.opacity(0.055))
                    .overlay(alignment: .leading) { Rectangle().fill(Color.black).frame(width: 3) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(WireColor.ink.opacity(0.12)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(reservesCheckResultSpace
            ? (isCheckTarget ? "チェック中の単語。タップで答えを表示します" : "単語を順番にチェックします")
            : "単語の詳細を開きます")
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

extension View {
    /// 囲いの形の中だけをタップ領域にする。
    ///
    /// `List` の行に `Button` を置くと、行の余白や左右の背景まで反応してしまう。
    /// 背景は戻るスワイプが使う場所なので、そこと取り合いにならないよう
    /// カードの角丸の内側でだけタップを受ける。
    func cardTapTarget(
        radius: CGFloat = WireMetrics.radiusCard,
        action: @escaping () -> Void
    ) -> some View {
        contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
    }
}
