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

    private let studyService = StudyService()

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
            Form {
                Section("単語") {
                    TextField("英単語", text: $text)
                        .textInputAutocapitalization(.never)
                    TextField("意味", text: $meaning, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("例文") {
                    TextField("English", text: $sentenceEnglish, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("日本語", text: $sentenceJapanese, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("画像") {
                    TextField("image_asset_path", text: $imageAssetPath, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .lineLimit(2...3)
                }

                if !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                    }
                }
            }
            .navigationTitle("単語編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let session = appState.session else { return }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !trimmedMeaning.isEmpty else {
            message = "単語と意味は必須です。"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let override = UserWordOverride(
            userId: session.user.id,
            wordId: word.id,
            wordText: trimmedText,
            definitionJapanese: trimmedMeaning,
            sentenceEnglish: sentenceEnglish.trimmingCharacters(in: .whitespacesAndNewlines),
            sentenceJapanese: sentenceJapanese.trimmingCharacters(in: .whitespacesAndNewlines),
            imageAssetPath: imageAssetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let saved = try await studyService.saveWordOverride(override, session: session)
            onSaved?(saved)
            dismiss()
        } catch {
            message = "保存に失敗しました。"
        }
    }
}
