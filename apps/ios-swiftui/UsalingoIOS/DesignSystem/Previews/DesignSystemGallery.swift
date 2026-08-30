#if DEBUG
import SwiftUI

/// Outline Wireframe Design System の全部品を一覧するギャラリー（仕様書 Section 4.1）。
struct DesignSystemGallery: View {
    @State private var text = ""
    @State private var selectedPill = 0

    private struct Step: Identifiable {
        let id: Int
        let title: String
    }

    private let steps = [
        Step(id: 0, title: "受付"),
        Step(id: 1, title: "準備中"),
        Step(id: 2, title: "完了")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                section("Typography") {
                    VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                        ForEach(WireFont.allCases, id: \.self) { role in
                            Text(String(describing: role)).wireFont(role)
                        }
                    }
                }

                section("Card") {
                    WireCard {
                        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                            Text("カード見出し").wireFont(.titleS)
                            WireTextBar(role: .title)
                            WireTextBar(role: .sub)
                            Text("補助テキスト").wireFont(.caption)
                        }
                    }
                }

                section("Container") {
                    WireContainer {
                        Text("画面レベルのコンテナ").wireFont(.body)
                    }
                }

                section("Button") {
                    VStack(spacing: WireMetrics.spacingM) {
                        Button("Primary") {}.buttonStyle(.wirePrimary)
                        Button("Secondary") {}.buttonStyle(.wireSecondary)
                        Button("Destructive") {}.buttonStyle(.wireDestructive)
                        Button("Disabled") {}.buttonStyle(.wirePrimary).disabled(true)
                    }
                }

                section("Text Field") {
                    VStack(spacing: WireMetrics.spacingM) {
                        TextField("検索", text: $text).textFieldStyle(.wire)
                        WireFieldBox {
                            SecureField("パスワード", text: $text)
                        }
                    }
                }

                section("Pill / Menu") {
                    VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
                        HStack(spacing: WireMetrics.spacingS) {
                            ForEach(0..<3, id: \.self) { index in
                                WirePill(title: "タグ \(index)", isSelected: selectedPill == index)
                                    .onTapGesture { selectedPill = index }
                            }
                        }
                        WireMenuItem(title: "選択中の項目", isSelected: true)
                        WireMenuItem(title: "未選択の項目")
                    }
                }

                section("Icon Button / Avatar") {
                    HStack(spacing: WireMetrics.spacingM) {
                        Button { } label: { Image(systemName: "plus") }
                            .buttonStyle(.wireIcon)
                            .accessibilityLabel("追加")
                        Button { } label: { Image(systemName: "star") }
                            .buttonStyle(.wireIcon(isSelected: true))
                            .accessibilityLabel("お気に入り")
                        WireAvatar(initials: "US")
                    }
                }

                section("Image Placeholder") {
                    WireImagePlaceholder()
                        .frame(height: 140)
                }

                section("Timeline") {
                    WireTimeline(items: steps) { step in
                        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                            Text(step.title).wireFont(.label)
                            Text("補助テキスト").wireFont(.caption)
                        }
                    }
                }

                section("Divider") {
                    WireDivider()
                }
            }
            .padding(WireMetrics.screenPadding)
        }
        .background(WireColor.background)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Text(title).wireFont(.titleL)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Design System Gallery") {
    DesignSystemGallery()
}

#Preview("Dynamic Type XXL") {
    DesignSystemGallery()
        .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
#endif
