import SwiftUI

/// セグメント表示は既製の見た目なので、ピルの並びに置き換える（Section 3）。
struct WordListDisplayModePicker: View {
    @Binding var selectedMode: WordListDisplayMode

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            ForEach(WordListDisplayMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.title, systemImage: mode.symbol)
                        .wireFont(.label)
                        .fontWeight(selectedMode == mode ? .bold : .semibold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, WireMetrics.spacingS)
                        .outlineSurface(
                            radius: WireMetrics.radiusSmall,
                            stroke: selectedMode == mode
                                ? WireMetrics.strokeHeavy
                                : WireMetrics.strokeBase,
                            shadow: nil
                        )
                        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
    }
}

/// 選択は黒ベタ反転ではなく、枠線の昇格と太字で示す（Section 3.2）。
struct WordFilterPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WirePill(title: title, isSelected: isSelected, font: .caption)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct WordListTagFilterBar: View {
    let tags: [String]
    @Binding var selectedTag: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                WordFilterPillButton(title: "すべて", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }

                ForEach(tags, id: \.self) { tag in
                    WordFilterPillButton(title: tag, isSelected: selectedTag == tag) {
                        selectedTag = tag
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }
}

struct WordListStatusFilterBar: View {
    @Binding var selectedFilter: WordStatusFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(WordStatusFilter.allCases) { filter in
                    WordFilterPillButton(title: filter.title, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }
}

struct WordListDueFilterBar: View {
    @Binding var selectedFilter: WordDueFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingS) {
                ForEach(WordDueFilter.allCases) { filter in
                    WordFilterPillButton(title: filter.title, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.vertical, WireMetrics.spacingXS)
        }
    }
}

struct WordListSortMenu: View {
    @Binding var selectedSort: WordSortOption

    var body: some View {
        Menu {
            ForEach(WordSortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    Label(option.title, systemImage: selectedSort == option ? "checkmark" : option.symbol)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("並び替え")
    }
}
