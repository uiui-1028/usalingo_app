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

/// 絞り込みは並べ替えと対になる操作なので、同じツールバーの Menu で提供する。
/// タグ・学習状態・復習予定の3種類をセクションで束ねる。
struct WordListFilterMenu: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter

    var body: some View {
        Menu {
            if !tags.isEmpty {
                Section("タグ") {
                    Button {
                        selectedTag = nil
                    } label: {
                        Label("すべて", systemImage: selectedTag == nil ? "checkmark" : "tag")
                    }

                    ForEach(tags, id: \.self) { tag in
                        Button {
                            selectedTag = tag
                        } label: {
                            Label(tag, systemImage: selectedTag == tag ? "checkmark" : "tag")
                        }
                    }
                }
            }

            Section("学習状態") {
                ForEach(WordStatusFilter.allCases) { filter in
                    Button {
                        selectedStatusFilter = filter
                    } label: {
                        Label(filter.title, systemImage: selectedStatusFilter == filter ? "checkmark" : filter.symbol)
                    }
                }
            }

            Section("復習予定") {
                ForEach(WordDueFilter.allCases) { filter in
                    Button {
                        selectedDueFilter = filter
                    } label: {
                        Label(filter.title, systemImage: selectedDueFilter == filter ? "checkmark" : filter.symbol)
                    }
                }
            }

            if isFiltering {
                Section {
                    Button(role: .destructive) {
                        selectedTag = nil
                        selectedStatusFilter = .all
                        selectedDueFilter = .all
                    } label: {
                        Label("フィルターを解除", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            Image(systemName: isFiltering
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("フィルター")
    }

    private var isFiltering: Bool {
        selectedTag != nil || selectedStatusFilter != .all || selectedDueFilter != .all
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
