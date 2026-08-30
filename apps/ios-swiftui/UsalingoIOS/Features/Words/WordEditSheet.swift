import SwiftUI

struct WordEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let word: WordCard
    let onSaved: ((WordCard) -> Void)?

    @State private var text: String
    @State private var meaning: String
    @State private var sentenceEnglish: String
    @State private var sentenceJapanese: String
    @State private var imageAssetPath: String
    @State private var message = ""
    @State private var isSaving = false

    init(word: WordCard, onSaved: ((WordCard) -> Void)? = nil) {
        self.word = word
        self.onSaved = onSaved
        _text = State(initialValue: word.text)
        _meaning = State(initialValue: word.meaning)
        _sentenceEnglish = State(initialValue: word.sentenceEnglish ?? "")
        _sentenceJapanese = State(initialValue: word.sentenceJapanese ?? "")
        _imageAssetPath = State(initialValue: word.imageAssetPath ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    section("単語") {
                        TextField("英単語", text: $text)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.wire)
                        TextField("意味", text: $meaning, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.wire)
                    }

                    section("例文") {
                        TextField("English", text: $sentenceEnglish, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.wire)
                        TextField("日本語", text: $sentenceJapanese, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.wire)
                    }

                    section("画像") {
                        TextField("image_asset_path", text: $imageAssetPath, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .lineLimit(2...3)
                            .textFieldStyle(.wire)
                    }

                    if !message.isEmpty {
                        // 色相を使わずに異常を示す（破線 + 文言）。
                        Text(message)
                            .wireFont(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(WireMetrics.spacingM)
                            .outlineSurface(
                                radius: WireMetrics.radiusControl,
                                shadow: nil,
                                dashed: true
                            )
                    }
                }
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("単語編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WireColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる").wireFont(.label)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        Text("保存").wireFont(.label)
                    }
                    .disabled(isSaving)
                    .wireDisabled(isSaving)
                }
            }
        }
    }

    /// 見出し + 枠付きのひとかたまり。`Form` の Section に相当する。
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Text(title)
                .wireFont(.titleS)
            content()
        }
    }

    private func save() async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !trimmedMeaning.isEmpty else {
            message = "単語と意味は必須です。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let payload = WordOverridePayload(
            wordId: word.wordId,
            wordText: trimmedText,
            definitionJapanese: trimmedMeaning,
            sentenceEnglish: sentenceEnglish.trimmingCharacters(in: .whitespacesAndNewlines),
            sentenceJapanese: sentenceJapanese.trimmingCharacters(in: .whitespacesAndNewlines),
            imageAssetPath: imageAssetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let saved = try await appState.studyDataSource.saveWordOverride(payload)
            onSaved?(saved)
            dismiss()
        } catch {
            message = "保存に失敗しました。"
        }
    }
}
