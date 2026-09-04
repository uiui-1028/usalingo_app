import SwiftUI

struct WordDetailSheet: View {
    @State private var word: WordCard
    @State private var isEditing = false
    @State private var isTagging = false
    let onSaved: (WordCard) -> Void

    init(word: WordCard, onSaved: @escaping (WordCard) -> Void) {
        _word = State(initialValue: word)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                    if let url = word.illustrationURL {
                        CardImage(url: url) {
                            Color.clear
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 180)
                        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: nil)
                    }

                    VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                        Text(word.text)
                            .wireFont(.titleL)
                        Text(word.meaning)
                            .wireFont(.titleS)
                        if let part = word.partOfSpeech {
                            Text(part.uppercased())
                                .wireFont(.caption)
                        }
                        WordMetaRow(word: word)
                        if !word.tags.isEmpty {
                            TagChipRow(tags: word.tags)
                        }
                    }

                    if let sentence = word.sentenceEnglish {
                        DetailBlock(title: "Example", text: sentence)
                    }

                    if let sentence = word.sentenceJapanese {
                        DetailBlock(title: "日本語", text: sentence)
                    }

                    if let learning = word.learning {
                        DetailBlock(title: "学習メモ", text: learning.studySummary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("単語詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WireColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isTagging = true
                    } label: {
                        Image(systemName: "tag")
                            .wireFont(.label)
                    }
                    .accessibilityLabel("タグを編集")
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .wireFont(.label)
                    }
                    .accessibilityLabel("単語を編集")
                }
            }
            .sheet(isPresented: $isEditing) {
                WordEditSheet(word: word) { savedWord in
                    word = savedWord
                    onSaved(savedWord)
                }
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $isTagging) {
                TagSheet(word: word) { savedWord in
                    word = savedWord
                    onSaved(savedWord)
                }
                    .presentationDetents([.medium])
            }
        }
    }
}

struct WordMetaRow: View {
    let word: WordCard

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            StatusBadge(status: word.learningStatus)
            if let part = word.partOfSpeech {
                WirePill(title: part.uppercased(), font: .caption)
            }
            if let learning = word.learning {
                WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
            }
            WirePill(title: "\(word.tags.count)タグ", font: .caption)
        }
        .padding(.top, WireMetrics.spacingXS)
    }
}

struct DetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text(title)
                .wireFont(.caption)
            Text(text)
                .wireFont(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}

extension WordLearningSnapshot {
    var studySummary: String {
        "SRS Lv.\(srsLevel) / \(repetitions)回復習 / 次回: \(formattedNextReviewDate) / 間隔: \(intervalDays)日"
    }

    var formattedNextReviewDate: String {
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
