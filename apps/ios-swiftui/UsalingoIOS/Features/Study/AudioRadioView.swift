import SwiftUI

/// 音源再生モード。デッキを1語ずつ「英単語 → 日本語訳 → 英語例文」の順に流し続ける。
///
/// 学習の記録は付けない。聞き流し専用と割り切り、復習間隔の計算を動かさない。
struct AudioRadioView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @StateObject private var player = RadioPlayer()
    @State private var isLoading = true
    @State private var loadErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                if isLoading {
                    ProgressView()
                } else if let loadErrorMessage {
                    StudyStatusView(
                        symbol: "wifi.exclamationmark",
                        title: "カードを読み込めませんでした",
                        message: loadErrorMessage,
                        actionTitle: "もう一度試す"
                    ) {
                        Task { await load() }
                    }
                } else if player.hasNoPlayableCard {
                    StudyStatusView(
                        symbol: "speaker.slash",
                        title: "流せる音源がありません",
                        message: "単語と例文の音声がそろったカードが、このデッキにはありません。",
                        actionTitle: "デッキに戻る"
                    ) {
                        dismiss()
                    }
                } else {
                    nowPlaying
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isLoading, loadErrorMessage == nil, !player.hasNoPlayableCard {
                controls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear {
            player.stop()
            appState.isShellChromeHidden = false
        }
    }

    private var header: some View {
        HStack(spacing: WireMetrics.spacingM) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.wireIcon(diameter: 40))
            .accessibilityLabel("デッキに戻る")

            Text(deck.deckName)
                .wireFont(.label)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.vertical, WireMetrics.spacingM)
    }

    /// いま鳴っている語。ロック画面と同じ並び（単語・訳・例文）にしてある。
    @ViewBuilder
    private var nowPlaying: some View {
        if let card = player.currentCard {
            VStack(spacing: WireMetrics.spacingL) {
                Text(card.text)
                    .wireFont(.titleL)
                    .multilineTextAlignment(.center)
                Text(card.primaryMeaning)
                    .wireFont(.body)
                    .multilineTextAlignment(.center)
                if let sentence = card.sentenceEnglish {
                    Text(sentence)
                        .wireFont(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(WireMetrics.spacingXL)
            .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
            .padding(.horizontal, WireMetrics.screenPadding)
            .accessibilityElement(children: .combine)
        }
    }

    private var controls: some View {
        VStack(spacing: WireMetrics.spacingM) {
            HStack(spacing: WireMetrics.spacingXL) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.wireIcon(diameter: 48))
                .accessibilityLabel("前の単語へ")

                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.wireIcon(diameter: 64))
                .accessibilityLabel(player.isPlaying ? "一時停止" : "再生")

                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.wireIcon(diameter: 48))
                .accessibilityLabel("次の単語へ")
            }

            rateBar
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.screenPadding)
    }

    private var rateBar: some View {
        HStack(spacing: WireMetrics.spacingXS) {
            ForEach(RadioRate.allCases) { rate in
                let isSelected = player.rate == rate
                Button {
                    player.setRate(rate)
                } label: {
                    Text(rate.title)
                        .wireFont(.label, color: isSelected ? WireColor.surface : WireColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(isSelected ? WireColor.ink : WireColor.surface))
                        .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("速さ \(rate.title)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(WireMetrics.spacingXS)
        .background(Capsule().fill(WireColor.surface))
        .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            let cards = try await appState.studyDataSource.fetchStudyQueue(deckId: deck.id, mode: .all)
            player.start(cards: cards, deckName: deck.deckName)
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }
}
