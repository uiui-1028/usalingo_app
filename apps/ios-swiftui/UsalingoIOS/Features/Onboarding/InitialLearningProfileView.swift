import SwiftUI

struct InitialLearningProfileView: View {
    @State private var purpose: LearningPurpose?
    @State private var level: EnglishLevel?
    @State private var dailyStudyDuration: DailyStudyDuration?
    @State private var availableDecks: [Deck]
    @State private var deckCatalogErrorMessage: String?
    @State private var errorMessage = ""
    @State private var showsError = false

    private let catalogLoader: any InitialDeckCatalogLoading
    private let resolver: InitialDeckResolver
    private let onComplete: (InitialLearningProfile) throws -> Void

    init(
        catalogLoader: any InitialDeckCatalogLoading = BundledInitialDeckCatalogLoader(),
        resolver: InitialDeckResolver = InitialDeckResolver(),
        initialPurpose: LearningPurpose? = nil,
        initialLevel: EnglishLevel? = nil,
        initialDailyStudyDuration: DailyStudyDuration? = nil,
        onComplete: @escaping (InitialLearningProfile) throws -> Void
    ) {
        self.catalogLoader = catalogLoader
        self.resolver = resolver
        _purpose = State(initialValue: initialPurpose)
        _level = State(initialValue: initialLevel)
        _dailyStudyDuration = State(initialValue: initialDailyStudyDuration)
        do {
            let decks = try catalogLoader.load()
            _availableDecks = State(initialValue: decks)
            _deckCatalogErrorMessage = State(
                initialValue: decks.isEmpty ? "利用できるデッキが見つからないため、標準デッキを設定します。" : nil
            )
        } catch {
            _availableDecks = State(initialValue: [])
            _deckCatalogErrorMessage = State(
                initialValue: "デッキを読み込めませんでした。標準デッキを設定します。"
            )
        }
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            GridBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    question(
                        title: "英語を学ぶ目的",
                        options: LearningPurpose.allCases,
                        selection: $purpose,
                        titleForOption: \.title,
                        identifierPrefix: "learning-purpose"
                    )

                    if let deckNotice {
                        deckNoticeView(deckNotice)
                    }

                    question(
                        title: "現在の英語レベル",
                        options: EnglishLevel.allCases,
                        selection: $level,
                        titleForOption: \.title,
                        identifierPrefix: "english-level"
                    )

                    question(
                        title: "1日にどれくらい学習したいか",
                        options: DailyStudyDuration.allCases,
                        selection: $dailyStudyDuration,
                        titleForOption: \.title,
                        identifierPrefix: "daily-study-duration"
                    )

                    Button(action: complete) {
                        Text("この内容で始める")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppStyle.accentDark)
                    .disabled(!canComplete)
                    .accessibilityIdentifier("complete-initial-learning-profile")
                    .accessibilityHint(canComplete ? "初期デッキを設定します" : "3つの質問すべてに回答してください")
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("保存できませんでした", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("あなたに合う学習を準備します")
                .font(.largeTitle.bold())
                .foregroundStyle(AppStyle.ink)
                .accessibilityAddTraits(.isHeader)
            Text("3つ選ぶだけで、最初のデッキと毎日の学習時間を設定できます。")
                .font(.body)
                .foregroundStyle(AppStyle.muted)
        }
    }

    private var canComplete: Bool {
        purpose != nil && level != nil && dailyStudyDuration != nil
    }

    private var deckNotice: String? {
        if let deckCatalogErrorMessage {
            return deckCatalogErrorMessage
        }
        guard let purpose, let level else { return nil }
        let resolution = resolver.resolution(
            purpose: purpose,
            level: level,
            availableDecks: availableDecks
        )
        guard resolution.usedFallback else { return nil }
        return "条件に合うデッキが見つからないため、「\(resolution.deck.deckName)」を設定します。"
    }

    private func deckNoticeView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppStyle.ink)
            Button("デッキを再読み込み", action: reloadDeckCatalog)
                .font(.callout.bold())
                .accessibilityHint("利用できる初期デッキをもう一度確認します")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
    }

    private func reloadDeckCatalog() {
        do {
            availableDecks = try catalogLoader.load()
            deckCatalogErrorMessage = availableDecks.isEmpty
                ? "利用できるデッキが見つからないため、標準デッキを設定します。"
                : nil
        } catch {
            availableDecks = []
            deckCatalogErrorMessage = "デッキを読み込めませんでした。標準デッキを設定します。"
        }
    }

    @ViewBuilder
    private func question<Option: CaseIterable & Hashable & Identifiable>(
        title: String,
        options: Option.AllCases,
        selection: Binding<Option?>,
        titleForOption: KeyPath<Option, String>,
        identifierPrefix: String
    ) -> some View where Option.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppStyle.ink)
                .accessibilityAddTraits(.isHeader)

            ForEach(options) { option in
                let optionTitle = option[keyPath: titleForOption]
                selectionButton(
                    title: optionTitle,
                    isSelected: selection.wrappedValue == option,
                    accessibilityIdentifier: "\(identifierPrefix)-\(option.id)"
                ) {
                    selection.wrappedValue = option
                }
            }
        }
        .padding(18)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppStyle.line, lineWidth: 1)
        }
    }

    private func selectionButton(
        title: String,
        isSelected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? AppStyle.accentDark : AppStyle.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? AppStyle.accentDark : AppStyle.muted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? AppStyle.accent.opacity(0.12) : AppStyle.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppStyle.accentDark : AppStyle.line, lineWidth: isSelected ? 3 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func complete() {
        guard let purpose, let level, let dailyStudyDuration else { return }
        let deck = resolver.resolve(purpose: purpose, level: level, availableDecks: availableDecks)
        let profile = InitialLearningProfile(
            purpose: purpose,
            level: level,
            dailyStudyDuration: dailyStudyDuration,
            initialDeckID: deck.id,
            initialDeckName: deck.deckName,
            ruleVersion: InitialLearningProfile.currentRuleVersion
        )

        do {
            try onComplete(profile)
        } catch {
            errorMessage = error.localizedDescription
            showsError = true
        }
    }
}

#Preview {
    InitialLearningProfileView { _ in }
}
