import SwiftUI

/// 表示切り替え（リスト / カード）。操作バーの横に、もう1本の小さなバーとして置く。
/// 文字は入れず、アイコンだけで表す。
struct WordListDisplayModeBar: View {
    @Binding var selectedMode: WordListDisplayMode

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            ForEach(WordListDisplayMode.allCases) { mode in
                let isSelected = selectedMode == mode
                Button {
                    selectedMode = mode
                } label: {
                    WordListActionBarIcon(symbol: mode.symbol, isActive: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .wordListBarChrome()
    }
}

/// 画面下端に浮かべる2本のバー。左が絞り込み・並べ替え・検索、右が表示切り替え。
/// 検索を開いている間は、左のバーが横いっぱいに広がるので右のバーは引っ込める。
struct WordListBottomBars: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter
    @Binding var selectedSort: WordSortOption
    @Binding var searchText: String
    @Binding var selectedDisplayMode: WordListDisplayMode
    let onBack: () -> Void

    @State private var isSearchExpanded = false

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            WordListActionBar(
                tags: tags,
                selectedTag: $selectedTag,
                selectedStatusFilter: $selectedStatusFilter,
                selectedDueFilter: $selectedDueFilter,
                selectedSort: $selectedSort,
                searchText: $searchText,
                isSearchExpanded: $isSearchExpanded,
                onBack: onBack
            )

            if !isSearchExpanded {
                WordListDisplayModeBar(selectedMode: $selectedDisplayMode)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingXL)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSearchExpanded)
    }
}

/// 絞り込み・並べ替え・検索をひとまとめにした、画面下端の浮動バー。
/// シェルのタブバーと同じ形・同じ位置に置き、検索は押した時だけバーの中を広げる。
struct WordListActionBar: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter
    @Binding var selectedSort: WordSortOption
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    let onBack: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            if !isSearchExpanded {
                // ヘッダーを消したので、前の画面へ戻る導線もこのバーが持つ。
                Button(action: onBack) {
                    WordListActionBarIcon(symbol: "chevron.left", isActive: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("戻る")

                WordListFilterMenu(
                    tags: tags,
                    selectedTag: $selectedTag,
                    selectedStatusFilter: $selectedStatusFilter,
                    selectedDueFilter: $selectedDueFilter
                )

                WordListSortMenu(selectedSort: $selectedSort)
            }

            searchControl
        }
        .wordListBarChrome()
    }

    /// 閉じている間はアイコン1つ。開くとバーの残りを押し広げて入力欄になる。
    private var searchControl: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button {
                if isSearchExpanded {
                    closeSearch()
                } else {
                    isSearchExpanded = true
                    isSearchFocused = true
                }
            } label: {
                Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                    .wireFont(.label, color: isSearching ? WireColor.surface : WireColor.ink)
                    .frame(minWidth: 48, minHeight: 48)
                    .background(Capsule().fill(isSearching ? WireColor.ink : WireColor.surface))
                    .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSearchExpanded ? "検索を閉じる" : "検索")

            if isSearchExpanded {
                TextField("英単語・意味・例文を検索", text: $searchText)
                    .wireFont(.label)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                    // 変換途中の文字は欄が消えた後に確定して戻ってくることがあるので、
                    // 閉じる時の消去は欄が消えたこの時点でもう一度行う。
                    .onDisappear { searchText = "" }
            }
        }
        .frame(maxWidth: isSearchExpanded ? .infinity : nil)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func closeSearch() {
        isSearchFocused = false
        isSearchExpanded = false
        searchText = ""
    }
}

/// 絞り込み。タグ・学習状態・復習予定の3種類をセクションで束ねる。
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
            WordListActionBarIcon(
                symbol: isFiltering
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle",
                isActive: isFiltering
            )
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
            WordListActionBarIcon(
                symbol: "arrow.up.arrow.down",
                isActive: selectedSort != .registered
            )
        }
        .accessibilityLabel("並び替え")
    }
}

/// 浮動バーの中のボタン1つ分の見た目。シェルのタブと同じ丸ピル。
struct WordListActionBarIcon: View {
    let symbol: String
    let isActive: Bool

    var body: some View {
        Image(systemName: symbol)
            .wireFont(.label, color: isActive ? WireColor.surface : WireColor.ink)
            .frame(minWidth: 48, minHeight: 48)
            .background(Capsule().fill(isActive ? WireColor.ink : WireColor.surface))
            .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            .contentShape(Capsule())
    }
}

extension View {
    /// 浮動バー1本分の枠。シェルのタブバーと同じ丸ピルだが、検索欄の文字が
    /// 一覧に重ならないよう中だけ地の色で塗る。
    func wordListBarChrome() -> some View {
        padding(WireMetrics.spacingM)
            .background(Capsule().fill(WireColor.background))
            .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            .offsetShadow(.card, in: Capsule())
    }
}
