import Nuke
import NukeUI
import SwiftUI

/// カード用イラストの読み込みを、アプリ側の約束だけで包む。
///
/// Nuke の型やキャッシュ設定を画面へ漏らさないため、外部パッケージを差し替えるときも
/// このファイルだけを直せばよい。画像は最大 200 MB まで端末へ保存し、容量を超えた
/// 古い画像は Nuke の LRU キャッシュが自動で片付ける。
enum CardImageCache {
    static let diskCacheSizeLimit = 200 * 1024 * 1024

    static let pipeline: ImagePipeline = {
        ImagePipeline(
            configuration: .withDataCache(
                name: "jp.usalingo.card-images",
                sizeLimit: diskCacheSizeLimit
            )
        )
    }()

    /// 現在のカードを基準に、いくつ先まで完成させて待たせておくか。
    static let prefetchWindow = 6

    /// 行き先はディスクではなくメモリ。ディスクまでで止めると表示時に読み直しとデコードが
    /// 残り、連続でめくったときに一瞬 ProgressView が出てしまう。
    private static let prefetcher = ImagePrefetcher(
        pipeline: pipeline,
        destination: .memoryCache,
        maxConcurrentRequestCount: 4
    )

    /// すでにメモリに載っているものは要求自体を作らない。残りは Nuke 側が同じ URL の
    /// 実行中タスクをまとめるので、何度呼ばれても取得は重複しない。
    static func prefetch(urls: [URL]) {
        let missing = urls.filter { pipeline.cache[$0] == nil }
        guard !missing.isEmpty else { return }
        prefetcher.startPrefetching(with: missing)
    }

    /// 学習画面を離れるときなど、もう使わない先読みを止める。
    static func stopPrefetching() {
        prefetcher.stopPrefetching()
    }

    static func removeAll() {
        prefetcher.stopPrefetching()
        pipeline.cache.removeAll()
    }
}

/// カード用イラストを、ディスクキャッシュ付きで表示する薄い View。
///
/// View 側は画像の見た目と空のときの表示だけを決め、通信・キャッシュ・先読みの仕組みは
/// `CardImageCache` に任せる。
struct CardImage<Placeholder: View>: View {
    enum ContentMode {
        case fit
        case fill
    }

    let url: URL?
    let contentMode: ContentMode
    let showsLoadingIndicator: Bool
    @ViewBuilder let placeholder: () -> Placeholder

    init(
        url: URL?,
        contentMode: ContentMode = .fit,
        showsLoadingIndicator: Bool = true,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.showsLoadingIndicator = showsLoadingIndicator
        self.placeholder = placeholder
    }

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                switch contentMode {
                case .fit:
                    image.resizable().scaledToFit()
                case .fill:
                    image.resizable().scaledToFill()
                }
            } else {
                ZStack {
                    placeholder()
                    if state.isLoading, showsLoadingIndicator {
                        ProgressView()
                            .tint(WireColor.ink)
                    }
                }
            }
        }
        .pipeline(CardImageCache.pipeline)
    }
}
