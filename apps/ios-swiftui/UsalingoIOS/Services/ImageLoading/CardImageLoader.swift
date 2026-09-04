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

    private static let prefetcher = ImagePrefetcher(
        pipeline: pipeline,
        destination: .diskCache,
        maxConcurrentRequestCount: 3
    )

    static func prefetch(urls: [URL]) {
        prefetcher.startPrefetching(with: urls)
    }

    static func removeAll() {
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
