import SwiftUI

struct TagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let word: WordCard
    let onSaved: ((WordCard) -> Void)?
    @State private var selectedTags: Set<String> = []
    @State private var message = ""
    @State private var isLoading = false
    @State private var isSaving = false

    private let studyService = StudyService()

    init(word: WordCard, onSaved: ((WordCard) -> Void)? = nil) {
        self.word = word
        self.onSaved = onSaved
        _selectedTags = State(initialValue: Set(word.tags))
    }

    private let tags = [
        ("重要", "star.fill", Color.yellow),
        ("復習", "arrow.clockwise", Color.orange),
        ("苦手", "exclamationmark.circle.fill", Color.red),
        ("お気に入り", "heart.fill", Color.pink),
        ("例文確認", "text.quote", Color.blue),
        ("発音確認", "waveform", Color.green)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(word.text)
                        .font(.largeTitle.bold())
                    Text("タグを選択")
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.muted)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(tags, id: \.0) { tag in
                        tagButton(title: tag.0, symbol: tag.1, color: tag.2)
                    }
                }
                .opacity(isLoading ? 0.45 : 1.0)
                .disabled(isLoading || isSaving)

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("タグを読み込み中")
                            .font(.footnote)
                            .foregroundStyle(AppStyle.muted)
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppStyle.muted)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("タグ")
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
                    .disabled(isLoading || isSaving)
                }
            }
            .task { await load() }
        }
    }

    private func tagButton(title: String, symbol: String, color: Color) -> some View {
        let isSelected = selectedTags.contains(title)
        return Button {
            if isSelected {
                selectedTags.remove(title)
            } else {
                selectedTags.insert(title)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard let session = appState.session else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            selectedTags = Set(try await studyService.fetchTags(wordId: word.id, session: session))
            message = ""
        } catch {
            message = "タグの読み込みに失敗しました。"
        }
    }

    private func save() async {
        guard let session = appState.session else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await studyService.saveTags(selectedTags, wordId: word.id, session: session)
            onSaved?(word.withTags(selectedTags.sorted()))
            dismiss()
        } catch {
            message = "タグの保存に失敗しました。"
        }
    }
}
