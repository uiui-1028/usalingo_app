import SwiftUI
import WebKit

struct ProfileDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stats = StudyStats.empty
    @State private var profile = UserProfile(userId: "", nickname: nil, plan: "free")
    @State private var isAccountCardExpanded = false
    @State private var isEditingProfile = false
    @State private var isShowingAuth = false
    @State private var isShowingLegalInformation = false
    @State private var isConfirmingCacheRemoval = false
    @State private var message = ""

    private let studyService = StudyService()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    Button {
                        setAccountCardExpanded(true)
                    } label: {
                        ProfileSummaryCard(
                            displayName: displayName,
                            accountDetail: accountDetail,
                            plan: planLabel
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("プロフィール、\(displayName)、\(accountDetail)")
                    .accessibilityHint("アカウントの操作、利用規約、画像と音声のキャッシュの設定を開きます")
                    .padding(.horizontal, WireMetrics.screenPadding)
                    .padding(.top, WireMetrics.screenPadding)
                    .padding(.bottom, WireMetrics.spacingM)

                    learningRecordSheet
                }
                .background(WireColor.background)

                if isAccountCardExpanded {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture { setAccountCardExpanded(false) }
                        .accessibilityHidden(true)

                    ExpandedProfileCard(
                        displayName: displayName,
                        accountDetail: accountDetail,
                        plan: planLabel,
                        isGuest: appState.isGuest,
                        close: { setAccountCardExpanded(false) },
                        openAccount: openAccount,
                        openLegalInformation: openLegalInformation,
                        removeImageCache: confirmCacheRemoval
                    )
                    .frame(maxWidth: 520, maxHeight: max(320, proxy.size.height - (WireMetrics.spacingXL * 2)))
                    .padding(WireMetrics.screenPadding)
                    .transition(.scale(scale: 0.86, anchor: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: isAccountCardExpanded)
        }
        .task(id: appState.session?.user.id ?? "guest") { await load() }
        .task(id: appState.studyDataVersion) { await refreshStats() }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditSheet(
                nickname: profile.nickname ?? "",
                signOut: appState.signOut
            ) { nickname in
                await saveNickname(nickname)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingAuth) {
            AuthView()
        }
        .sheet(isPresented: $isShowingLegalInformation) {
            LegalInformationView()
        }
        .onChange(of: appState.isGuest) { _, isGuest in
            if !isGuest {
                isShowingAuth = false
            }
        }
        .alert("画像と音声のキャッシュを削除しますか？", isPresented: $isConfirmingCacheRemoval) {
            Button("削除", role: .destructive) {
                CardImageCache.removeAll()
                Task { await CardAudioCache.shared.removeAll() }
                message = "画像と音声のキャッシュを削除しました。必要な画像と音声は、次に使うときにもう一度読み込みます。"
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("この端末に保存したカード画像と音声だけを片付けます。カードや学習記録は消えません。")
        }
    }

    private var learningRecordSheet: some View {
        ScrollView {
            VStack(spacing: WireMetrics.spacingL) {
                if !message.isEmpty {
                    // 色相を使わずに異常を示す（破線 + 文言）。
                    Text(message)
                        .wireFont(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(WireMetrics.spacingM)
                        .outlineSurface(
                            radius: WireMetrics.radiusControl,
                            shadow: nil,
                            dashed: true,
                            fill: WireColor.groupL2
                        )
                }

                HeatmapTile(reviewedDays: stats.reviewedDays, tone: .l2)

                HStack(spacing: WireMetrics.spacingL) {
                    ProfileTile(
                        title: "\(stats.currentStreak)",
                        symbol: "flame",
                        caption: "連続日数",
                        tone: .l2
                    )
                    ProfileTile(
                        title: "\(stats.studiedCount)",
                        symbol: "sparkles",
                        caption: "学習した単語",
                        tone: .l2
                    )
                }

                LearningSummaryTile(stats: stats, tone: .l2)
            }
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.top, WireMetrics.spacingL)
            .padding(.bottom, WireMetrics.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: WireMetrics.radiusLarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: WireMetrics.radiusLarge,
                style: .continuous
            )
                .fill(WireColor.groupL2)
        )
        .overlay(
            ProfileBottomSheetBorder(
                radius: WireMetrics.radiusLarge,
                lineWidth: WireMetrics.strokeHeavy
            )
            .stroke(WireColor.ink, lineWidth: WireMetrics.strokeHeavy)
        )
    }

    private var displayName: String {
        if appState.isGuest {
            return "ログイン"
        }
        let nickname = profile.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        return appState.session?.user.email ?? "ユーザー名"
    }

    private var accountDetail: String {
        if appState.isGuest {
            return "ゲストアカウント"
        }
        return appState.session?.user.email ?? "ログイン済み"
    }

    private var planLabel: String {
        guard let plan = profile.plan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty else {
            return "Free"
        }
        return plan.localizedCapitalized
    }

    private func setAccountCardExpanded(_ isExpanded: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84)) {
            isAccountCardExpanded = isExpanded
        }
    }

    private func openAccount() {
        setAccountCardExpanded(false)
        if appState.isGuest {
            isShowingAuth = true
        } else {
            isEditingProfile = true
        }
    }

    private func openLegalInformation() {
        setAccountCardExpanded(false)
        isShowingLegalInformation = true
    }

    private func confirmCacheRemoval() {
        setAccountCardExpanded(false)
        isConfirmingCacheRemoval = true
    }

    private func load() async {
        do {
            stats = try await appState.studyDataSource.fetchStudyStats()
            message = ""
        } catch {
            stats = .empty
            message = "端末の学習記録を読み込めませんでした。"
        }

        guard let session = appState.session else {
            profile = UserProfile(userId: "", nickname: nil, plan: "free")
            return
        }
        do {
            profile = try await studyService.fetchUserProfile(session: session)
        } catch {
            // アカウント情報の通信失敗で、先に読めた端末の学習統計まで消さない。
            message = "アカウント情報は接続後に更新します。"
        }
    }

    private func refreshStats() async {
        do {
            stats = try await appState.studyDataSource.fetchStudyStats()
        } catch {
            stats = .empty
        }
    }

    private func saveNickname(_ nickname: String) async {
        guard let session = appState.session else { return }
        do {
            profile = try await studyService.saveUserProfile(nickname: nickname, session: session)
            message = ""
            isEditingProfile = false
        } catch {
            message = "ユーザー名を保存できませんでした。"
        }
    }
}

private struct ProfileSummaryCard: View {
    let displayName: String
    let accountDetail: String
    let plan: String

    var body: some View {
        HStack(spacing: WireMetrics.spacingL) {
            Image(systemName: "person.crop.circle")
                .resizable()
                .scaledToFit()
                .padding(WireMetrics.spacingL)
                .frame(width: 92, height: 92)
                .outlineSurface(
                    radius: WireMetrics.radiusCard,
                    stroke: WireMetrics.strokeHeavy,
                    shadow: nil,
                    fill: WireColor.groupL2
                )

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(displayName)
                    .wireFont(.titleL)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(accountDetail)
                    .wireFont(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                WirePill(title: plan, font: .caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .wireFont(.label)
                .accessibilityHidden(true)
        }
        .padding(WireMetrics.spacingM)
        // 変更前は 92pt のアバター + 上下12ptで116pt。カードだけを正確に2倍へ広げる。
        .frame(maxWidth: .infinity, minHeight: 232, alignment: .leading)
        .outlineSurface(
            radius: WireMetrics.radiusLarge,
            stroke: WireMetrics.strokeHeavy,
            shadow: .card
        )
    }
}

/// 上と左右だけを描く固定シートの枠。下端は画面外へ続く面として線を置かない。
private struct ProfileBottomSheetBorder: Shape {
    let radius: CGFloat
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = lineWidth / 2
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let top = rect.minY + inset
        let corner = min(radius, (right - left) / 2, rect.height)
        var path = Path()

        path.move(to: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: top + corner))
        path.addQuadCurve(
            to: CGPoint(x: left + corner, y: top),
            control: CGPoint(x: left, y: top)
        )
        path.addLine(to: CGPoint(x: right - corner, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: top + corner),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right, y: rect.maxY))

        return path
    }
}

private struct ExpandedProfileCard: View {
    let displayName: String
    let accountDetail: String
    let plan: String
    let isGuest: Bool
    let close: () -> Void
    let openAccount: () -> Void
    let openLegalInformation: () -> Void
    let removeImageCache: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: WireMetrics.spacingXL) {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                            .outlineCircleSurface(stroke: WireMetrics.strokeBase)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("プロフィールカードを閉じる")
                }

                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .padding(WireMetrics.spacingXL)
                    .frame(width: 132, height: 132)
                    .outlineSurface(
                        radius: WireMetrics.radiusLarge,
                        stroke: WireMetrics.strokeHeavy,
                        shadow: nil,
                        fill: WireColor.groupL2
                    )

                VStack(spacing: WireMetrics.spacingS) {
                    Text(displayName)
                        .wireFont(.titleL)
                        .multilineTextAlignment(.center)
                    Text(accountDetail)
                        .wireFont(.caption)
                        .multilineTextAlignment(.center)
                    WirePill(title: plan, font: .caption)
                }

                VStack(spacing: WireMetrics.spacingM) {
                    Button {
                        openAccount()
                    } label: {
                        Label(
                            isGuest ? "ログイン・アカウント作成" : "プロフィール・アカウント設定",
                            systemImage: isGuest ? "person.badge.plus" : "person.crop.circle.badge.checkmark"
                        )
                    }
                    .buttonStyle(.wirePrimary)

                    Button(action: openLegalInformation) {
                        Label("利用規約・プライバシー・ライセンス", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.wireSecondary)
                    .accessibilityHint("正式公開済みの文書とクレジットを開きます")

                    Button(action: removeImageCache) {
                        Label("画像と音声のキャッシュを削除", systemImage: "trash")
                    }
                    .buttonStyle(.wireDestructive)
                    .accessibilityHint("一度使ったカード画像と音声だけを端末から削除します")
                }
            }
            .padding(WireMetrics.spacingL)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(WireColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous)
                .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHeavy)
        )
        .offsetShadow(.container, radius: WireMetrics.radiusLarge)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }
}

private struct LegalInformationView: View {
    @Environment(\.dismiss) private var dismiss
    private let documents = LegalDocument.publishedDocuments

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    WireCard {
                        Text("正式に公開された文書と、利用しているコンテンツの出典をここで確認できます。公開前の草案は表示しません。")
                            .wireFont(.caption)
                            .accessibilityLabel("正式に公開された文書とコンテンツの出典を確認できます。公開前の草案は表示しません。")
                    }

                    section("法務文書") {
                        legalRow(.terms)
                        legalRow(.privacy)
                    }

                    section("ライセンスとクレジット") {
                        NavigationLink {
                            OpenSourceLicenseView()
                        } label: {
                            LegalTextRow(
                                title: LegalDocument.Kind.licenses.title,
                                detail: "このアプリが使っているオープンソースの一覧"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("オープンソースライセンスの一覧をアプリ内で開きます。")
                        legalRow(.credits)
                    }

                    section("お問い合わせ") {
                        if let mailURL = AppInfo.contactMailURL() {
                            Link(destination: mailURL) {
                                LegalTextRow(
                                    title: "問い合わせ先",
                                    detail: AppInfo.supportEmail
                                )
                            }
                            .accessibilityHint("メールアプリが開きます。本文にアプリの版と機種があらかじめ入ります。送信前に消せます。")
                        } else {
                            LegalTextRow(
                                title: "問い合わせ先",
                                detail: AppInfo.supportEmail
                            )
                        }
                    }

                    // 各文書は上の節から開く。ここで一覧を作り直すと同じ行が二度並び、
                    // どちらが入口か分からなくなる。空のときの説明だけを残す。
                    if documents.isEmpty {
                        ContentUnavailableView(
                            "公開済みの文書はまだありません",
                            systemImage: "clock",
                            description: Text("版、施行日、外部リンクを確認できる正式文書が登録されるまで、草案は表示しません。")
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("法務・ライセンス")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる").wireFont(.label)
                    }
                    .accessibilityLabel("法務・ライセンス画面を閉じる")
                }
            }
        }
    }

    /// 見出し + 中身のひとかたまり。`Form` の Section に相当する。
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

    @ViewBuilder
    private func legalRow(_ kind: LegalDocument.Kind) -> some View {
        if let document = documents.first(where: { $0.kind == kind }) {
            NavigationLink {
                LegalDocumentDetailView(document: document)
            } label: {
                LegalTextRow(
                    title: document.title,
                    detail: "\(document.version) ・施行日 \(document.effectiveDate)"
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("正式文書をアプリ内で開きます。")
        } else {
            LegalTextRow(title: kind.title, detail: "正式版は公開準備中です。")
        }
    }
}

/// 法務文書をアプリ内で表示する画面。外部Safariへは出ない。
private struct LegalDocumentDetailView: View {
    let document: LegalDocument
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            LegalWebView(url: document.url, isLoading: $isLoading, didFail: $loadFailed)
                .opacity(loadFailed ? 0 : 1)

            if isLoading {
                ProgressView()
            }

            if loadFailed {
                ContentUnavailableView(
                    "文書を読み込めませんでした",
                    systemImage: "wifi.slash",
                    description: Text("通信状態を確認して、もう一度開いてください。")
                )
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// WKWebView を SwiftUI から使うための薄いラッパー。
private struct LegalWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var didFail: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: LegalWebView

        init(_ parent: LegalWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.didFail = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.didFail = true
        }
    }
}

/// 正式公開済みの法務文書の台帳。表示内容をテストから確かめられるよう internal にしている。
struct LegalDocument: Identifiable {
    enum Kind: CaseIterable {
        case terms
        case privacy
        case licenses
        case credits

        var title: String {
            switch self {
            case .terms: "利用規約"
            case .privacy: "プライバシー"
            case .licenses: "ライセンス"
            case .credits: "クレジット"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let version: String
    let effectiveDate: String
    let url: URL

    // Add only legal-approved documents here. Drafts and unverified asset records stay hidden.
    // 正本は docs/legal/published/ にある。版と施行日を上げたら、ここも合わせる。
    // ライセンスは外部URLではなくアプリ内画面なので、ここには入れない。
    //
    // 版と施行日は文書ごとに持つ。3つまとめて1つの定数にすると、1文書だけ改訂したときに
    // 残りの2つまで新しい版として表示してしまう。実際、クレジットを第1.1版へ上げた際に
    // これが起きた。
    static let publishedDocuments: [LegalDocument] = [
        published(.terms, path: "terms", version: "第1.0版", effectiveDate: "2026年9月1日"),
        published(.privacy, path: "privacy", version: "第1.1版", effectiveDate: "2026年9月17日"),
        published(.credits, path: "credits", version: "第1.1版", effectiveDate: "2026年9月4日")
    ].compactMap { $0 }

    private static let publishedBaseURL = "https://usalingo-app.vercel.app"

    /// URLを組み立てられなかった行は一覧から落とす。落ちた行は「公開準備中」に戻るだけで、
    /// 壊れたリンクをタップさせるより安全。
    private static func published(
        _ kind: Kind,
        path: String,
        version: String,
        effectiveDate: String
    ) -> LegalDocument? {
        guard let url = URL(string: "\(publishedBaseURL)/\(path)") else { return nil }
        return LegalDocument(
            kind: kind,
            title: kind.title,
            version: version,
            effectiveDate: effectiveDate,
            url: url
        )
    }
}

/// 生成されたオープンソースライセンス一覧を表示する。
private struct OpenSourceLicenseView: View {
    private let text = OpenSourceLicenseCatalog.load()

    var body: some View {
        Group {
            if let text, !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "ライセンス一覧はまだありません",
                    systemImage: "shippingbox",
                    description: Text("外部パッケージを追加すると、生成された一覧がここに表示されます。")
                )
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// バンドルへ同梱したライセンス一覧を読む。
///
/// 一覧は `scripts/generate-licenses.sh` の生成物であり、依存がゼロのあいだは存在しない。
/// それが正しい状態なので、見つからないことを異常として扱わない。
enum OpenSourceLicenseCatalog {
    static func load(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(
            forResource: "Acknowledgements",
            withExtension: "md",
            subdirectory: "Licenses"
        ) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

private struct LegalTextRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
            Text(title)
                .wireFont(.titleS)
            Text(detail)
                .wireFont(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileTile: View {
    let title: String
    let symbol: String
    /// 数字だけでは何の値か分からないタイルに添える名前。
    var caption: String?
    /// まとまりの面。タイルの枠が浮かないよう、囲っている面と同じ濃さで塗る。
    var tone: BentoTone = .l1

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            Image(systemName: symbol)
                .wireFont(.titleL)
            Text(title)
                .wireFont(.titleS)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            if let caption {
                Text(caption)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
        .wireTile(tone: tone)
        // 「0 連続日数」ではなく「連続日数 0」と読ませる。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption.map { "\($0) \(title)" } ?? title)
    }
}

private extension View {
    /// プロフィールの正方形タイル。
    func wireTile(tone: BentoTone) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(WireMetrics.spacingM)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card, fill: tone.fill)
    }
}

private struct HeatmapTile: View {
    let reviewedDays: [Date]
    var tone: BentoTone = .l1

    var body: some View {
        HStack(spacing: WireMetrics.spacingL) {
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Image(systemName: "calendar")
                    .wireFont(.titleL)
                Text("最近の学習")
                    .wireFont(.titleS)
                Text("過去14日")
                    .wireFont(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 5), count: 7), spacing: 5) {
                ForEach(recentDays, id: \.self) { day in
                    // 学習した日は塗り、していない日は線だけ。色相は使わない。
                    heatmapCell(isReviewed: reviewedDaySet.contains(day))
                }
            }
        }
        .padding(WireMetrics.spacingL)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card, fill: tone.fill)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("最近14日間の学習日数 \(reviewedDaySet.count)日")
    }

    @ViewBuilder
    private func heatmapCell(isReviewed: Bool) -> some View {
        if isReviewed {
            Rectangle()
                .fill(WireColor.ink)
                .frame(width: 12, height: 12)
        } else {
            Rectangle()
                .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair)
                .frame(width: 12, height: 12)
        }
    }

    private var reviewedDaySet: Set<Date> {
        Set(reviewedDays.map { Calendar.current.startOfDay(for: $0) })
    }

    private var recentDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 13, to: today)
        }
    }
}

private struct LearningSummaryTile: View {
    let stats: StudyStats
    var tone: BentoTone = .l1

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Label("実績サマリー", systemImage: "trophy")
                .wireFont(.titleS)

            HStack(spacing: WireMetrics.spacingS) {
                summaryMetric(value: stats.totalReviews, label: "復習")
                WireDivider()
                    .frame(width: WireMetrics.strokeHair, height: 48)
                summaryMetric(value: stats.masteredCount, label: "定着")
                WireDivider()
                    .frame(width: WireMetrics.strokeHair, height: 48)
                summaryMetric(value: stats.dueCount, label: "今日の復習")
            }
        }
        .padding(WireMetrics.spacingL)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card, fill: tone.fill)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("実績サマリー、復習 \(stats.totalReviews)回、定着 \(stats.masteredCount)語、今日の復習 \(stats.dueCount)語")
    }

    private func summaryMetric(value: Int, label: String) -> some View {
        VStack(spacing: WireMetrics.spacingXS) {
            Text("\(value)")
                .wireFont(.titleL)
                .minimumScaleFactor(0.72)
            Text(label)
                .wireFont(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var nickname: String
    @State private var isManagingAccount = false
    let signOut: () -> Void
    let save: (String) async -> Void

    init(nickname: String, signOut: @escaping () -> Void, save: @escaping (String) async -> Void) {
        _nickname = State(initialValue: nickname)
        self.signOut = signOut
        self.save = save
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    WireSection("ユーザー名") {
                        TextField("ユーザー名", text: $nickname)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.wire)
                    }

                    WireSection("アカウント") {
                        Button("メールアドレス・パスワードを変更") {
                            isManagingAccount = true
                        }
                        .buttonStyle(.wireSecondary)
                    }

                    // サインアウトは破壊的操作。赤は使わず破線で示す。
                    Button {
                        signOut()
                        dismiss()
                    } label: {
                        Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.wireDestructive)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigationBar()
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
                        Task {
                            await save(nickname.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    } label: {
                        Text("保存").wireFont(.label)
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .wireDisabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $isManagingAccount) {
            AccountSecuritySheet()
                .environmentObject(appState)
        }
    }
}

/// 見出し + 中身のひとかたまり。`Form` の Section に相当する。
private struct WireSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            Text(title)
                .wireFont(.titleS)
            content
        }
    }
}

private struct AccountSecuritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var passwordNonce = ""
    @State private var newEmail = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var isDeletingAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    WireSection("パスワードを変更") {
                        WireFieldBox {
                            SecureField("今のパスワード", text: $currentPassword)
                        }
                        WireFieldBox {
                            SecureField("新しいパスワード（8文字以上）", text: $newPassword)
                        }
                        Button("古いログインにも確認コードを送る") {
                            Task { await requestReauthentication() }
                        }
                        .buttonStyle(.wireSecondary)
                        TextField("確認コード（届いたときだけ）", text: $passwordNonce)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.wire)
                        Button("パスワードを変更") {
                            Task { await changePassword() }
                        }
                        .buttonStyle(.wirePrimary)
                        .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty)
                    }

                    WireSection("メールアドレスを変更") {
                        Text("現在: \(appState.session?.user.email ?? "未設定")")
                            .wireFont(.body)
                        TextField("新しいメールアドレス", text: $newEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textFieldStyle(.wire)
                        if let suggestion = EmailInput.suggestion(for: newEmail) {
                            EmailSuggestionButton(suggestion: suggestion) {
                                newEmail = suggestion
                            }
                        }
                        WireFieldBox {
                            SecureField("今のパスワード", text: $currentPassword)
                        }
                        Button("メールアドレスを変更") {
                            Task { await changeEmail() }
                        }
                        .buttonStyle(.wirePrimary)
                        .disabled(isLoading || currentPassword.isEmpty || EmailInput.normalized(newEmail).isEmpty)
                        Text("今のメールと新しいメールの両方に届く確認メールを開くと、変更が完了します。")
                            .wireFont(.caption)
                    }

                    WireSection("退会") {
                        // 取り消せない操作。赤は使わず破線で示す。
                        Button {
                            isDeletingAccount = true
                        } label: {
                            Label("アカウントを削除", systemImage: "person.crop.circle.badge.minus")
                        }
                        .buttonStyle(.wireDestructive)
                        Text("アカウントと学習記録をその場で削除します。復元はできません。課金中のサービスがある場合、解約は別の操作です。")
                            .wireFont(.caption)
                    }

                    if !message.isEmpty {
                        Text(message)
                            .wireFont(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(WireMetrics.spacingM)
                            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("アカウントの安全")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる").wireFont(.label)
                    }
                }
            }
        }
        .sheet(isPresented: $isDeletingAccount) {
            AccountDeletionSheet()
                .environmentObject(appState)
        }
    }

    private func requestReauthentication() async {
        guard let token = appState.session?.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService().reauthenticate(accessToken: token)
            message = "確認コードをメールに送りました。届いたときだけ入力してください。"
        } catch {
            message = UserFacingError.message(for: error)
        }
    }

    private func changePassword() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.updatePassword(newPassword, currentPassword: currentPassword, nonce: passwordNonce)
            message = "パスワードを変更しました。"
            newPassword = ""
            passwordNonce = ""
        } catch {
            message = UserFacingError.message(for: error)
        }
    }

    private func changeEmail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            newEmail = EmailInput.normalized(newEmail)
            try await appState.updateEmail(newEmail, currentPassword: currentPassword)
            message = "2つのメールアドレスに確認メールを送りました。両方を開いてください。"
            newEmail = ""
        } catch {
            message = UserFacingError.message(for: error)
        }
    }
}

struct AccountDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var acknowledged = false
    @State private var message = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXL) {
                    WireSection("退会前に確認してください") {
                        WireCard {
                            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                                Text("退会すると、アカウントと学習記録・プロフィール・単語設定をその場ですべて削除します。")
                                    .wireFont(.body)
                                Text("復元はできません。取り消したくなっても元に戻せないため、必要な記録は先に控えてください。")
                                    .wireFont(.body)
                                Text("App Storeなどの課金契約がある場合、退会だけでは解約されません。課金元で別に解約してください。")
                                    .wireFont(.caption)
                            }
                        }
                    }

                    WireSection("本人確認") {
                        WireFieldBox {
                            SecureField("現在のパスワード", text: $password)
                                .textContentType(.password)
                        }
                        TextField("確認のため「退会」と入力", text: $confirmation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.wire)
                        Toggle("削除内容と元に戻せない条件を確認しました", isOn: $acknowledged)
                            .wireFont(.body)
                            .tint(WireColor.ink)
                    }

                    // 取り消せない操作。赤は使わず破線で示す。
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: WireMetrics.spacingS) {
                            if appState.isDeletingAccount {
                                ProgressView()
                                    .tint(WireColor.ink)
                            }
                            Text(appState.isDeletingAccount ? "削除しています…" : "最終確認して削除する")
                        }
                    }
                    .buttonStyle(.wireDestructive)
                    .disabled(!canSubmit)
                    .accessibilityHint("本人確認のあと、アカウントと学習記録をその場で削除します。取り消せません。")

                    if !message.isEmpty {
                        WireSection("結果") {
                            Text(message)
                                .wireFont(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(WireMetrics.spacingM)
                                .outlineSurface(
                                    radius: WireMetrics.radiusControl,
                                    shadow: nil,
                                    dashed: true
                                )
                                .accessibilityLabel("退会の結果。\(message)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.screenPadding)
            }
            .background(WireColor.background)
            .navigationTitle("アカウントを削除")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigationBar()
            .interactiveDismissDisabled(appState.isDeletingAccount)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる").wireFont(.label)
                    }
                    .disabled(appState.isDeletingAccount)
                    .wireDisabled(appState.isDeletingAccount)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !appState.isDeletingAccount && !password.isEmpty && confirmation == "退会" && acknowledged
    }

    @MainActor
    private func submit() async {
        message = ""
        do {
            try await appState.deleteAccount(
                password: password,
                confirmation: confirmation
            )
        } catch {
            message = UserFacingError.message(for: error)
        }
    }
}

#if DEBUG
#Preview("Profile Dashboard") {
    ProfileDashboardView()
    .environmentObject(AppState.preview)
    .environmentObject(DesignSettings())
}
#endif
