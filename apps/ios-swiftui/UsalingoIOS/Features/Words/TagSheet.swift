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

    init(word: WordCard, onSaved: ((WordCard) -> Void)? = nil) {
        self.word = word
        self.onSaved = onSaved
        _selectedTags = State(initialValue: Set(word.tags))
    }

    private let tags = [
        ("重要", "star.fill"),
        ("復習", "arrow.clockwise"),
        ("苦手", "exclamationmark.circle.fill"),
        ("お気に入り", "heart.fill"),
        ("例文確認", "text.quote"),
        ("発音確認", "waveform")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: WireMetrics.spacingL) {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text(word.text)
                        .wireFont(.titleL)
                    Text("タグを選択")
                        .wireFont(.caption)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: WireMetrics.spacingM
                ) {
                    ForEach(tags, id: \.0) { tag in
                        tagButton(title: tag.0, symbol: tag.1)
                    }
                }
                .wireDisabled(isLoading)
                .disabled(isLoading || isSaving)

                if isLoading {
                    HStack(spacing: WireMetrics.spacingS) {
                        ProgressView()
                            .tint(WireColor.ink)
                        Text("タグを読み込み中")
                            .wireFont(.caption)
                    }
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

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WireMetrics.screenPadding)
            .background(WireColor.background)
            .navigationTitle("タグ")
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
                    .disabled(isLoading || isSaving)
                    .wireDisabled(isLoading || isSaving)
                }
            }
            .task { await load() }
        }
    }

    /// タグの選択状態は黒ベタ反転ではなく、枠線の昇格と太字で示す（Section 3.2）。
    private func tagButton(title: String, symbol: String) -> some View {
        let isSelected = selectedTags.contains(title)
        return Button {
            if isSelected {
                selectedTags.remove(title)
            } else {
                selectedTags.insert(title)
            }
        } label: {
            HStack(spacing: WireMetrics.spacingS) {
                Image(systemName: symbol)
                Text(title)
            }
            .wireFont(.label)
            .fontWeight(isSelected ? .bold : .semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, WireMetrics.spacingM)
            .outlineSurface(
                radius: WireMetrics.radiusSmall,
                stroke: isSelected ? WireMetrics.strokeHeavy : WireMetrics.strokeBase,
                shadow: nil
            )
            .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let savedTags = try await appState.studyDataSource.fetchTags(wordId: word.wordId) {
                selectedTags = Set(savedTags)
            }
            message = ""
        } catch {
            message = "タグの読み込みに失敗しました。"
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.studyDataSource.saveTags(selectedTags, wordId: word.wordId)
            onSaved?(word.withTags(selectedTags.sorted()))
            dismiss()
        } catch {
            message = "タグの保存に失敗しました。"
        }
    }
}
