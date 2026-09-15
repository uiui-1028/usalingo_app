import AVFoundation
import Foundation
import Nuke

/// 学習音声を端末へ保存し、2回目からは通信せずに渡す。
///
/// 保存先は画像と同じ Nuke の `DataCache`。容量を超えた分は、最後に使った日時が古いものから
/// `DataCache` が自動で片付ける。1本約30KB × 約2000本（約60MB）が収まる上限にしている。
actor CardAudioCache {
    typealias Loader = @Sendable (URL) async throws -> Data

    static let diskCacheSizeLimit = 100 * 1024 * 1024
    static let shared = CardAudioCache()

    private let storage: DataCache?
    private let load: Loader
    private var inFlight: [URL: Task<Data, Error>] = [:]
    private var prefetchTask: Task<Void, Never>?

    init(storage: DataCache? = CardAudioCache.makeStorage(), load: @escaping Loader = CardAudioCache.download) {
        self.storage = storage
        self.load = load
    }

    /// 保存済みならそれを返し、無ければ取得して保存する。同じ URL の同時取得は1本にまとめる。
    func data(for url: URL) async throws -> Data {
        let key = url.absoluteString
        if let cached = storage?.cachedData(for: key) {
            return cached
        }
        if let running = inFlight[url] {
            return try await running.value
        }

        let task = Task { try await load(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let data = try await task.value
        storage?.storeData(data, for: key)
        return data
    }

    /// 画像と同じく、次に来るカードの音声を先に取っておく。前の先読みは打ち切る。
    func prefetch(urls: [URL]) {
        prefetchTask?.cancel()
        prefetchTask = Task {
            for url in urls {
                guard !Task.isCancelled else { return }
                _ = try? await data(for: url)
            }
        }
    }

    func stopPrefetching() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    func removeAll() {
        stopPrefetching()
        storage?.removeAll()
    }

    /// 保存箱を作れない端末でも再生は止めない。そのときは毎回取得する。
    private static func makeStorage() -> DataCache? {
        let cache = try? DataCache(name: "jp.usalingo.card-audio")
        cache?.sizeLimit = diskCacheSizeLimit
        return cache
    }

    /// エラー応答の本文を音声として保存しないよう、2xx 以外は失敗にする。
    private static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return data
    }
}

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject {
    /// 再生中（または読み込み中）の音声。単語と例文のどちらが鳴っているかを画面で見分ける。
    @Published private(set) var playingURL: URL?

    private let cache: CardAudioCache
    private var player: AVAudioPlayer?
    private var loadTask: Task<Void, Never>?
    private var queuedURLs: [URL] = []

    init(cache: CardAudioCache = .shared) {
        self.cache = cache
    }

    /// 同じ音声をもう一度押すと止める。別の音声を押すと、今の音声を止めてから鳴らす。
    func togglePlayback(url: URL) {
        let wasPlayingSameURL = playingURL == url
        stop()
        guard !wasPlayingSameURL else { return }

        playSequence(urls: [url])
    }

    /// カード表面の音声を指定順に1回ずつ鳴らす。取得や再生に失敗した音声は飛ばす。
    func playSequence(urls: [URL]) {
        stop()
        queuedURLs = urls
        playNext()
    }

    private func playNext() {
        guard player == nil, loadTask == nil else { return }
        guard !queuedURLs.isEmpty else {
            playingURL = nil
            return
        }

        let url = queuedURLs.removeFirst()
        playingURL = url
        loadTask = Task { [cache] in
            let data = try? await cache.data(for: url)
            guard !Task.isCancelled else { return }
            loadTask = nil
            guard playingURL == url else { return }
            guard let data, let audioPlayer = try? AVAudioPlayer(data: data) else {
                finishCurrentPlayback()
                return
            }
            audioPlayer.delegate = self
            player = audioPlayer
            if !audioPlayer.play() {
                finishCurrentPlayback()
            }
        }
    }

    func stop() {
        queuedURLs.removeAll()
        loadTask?.cancel()
        loadTask = nil
        player?.stop()
        player = nil
        playingURL = nil
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish(player) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.finish(player) }
    }

    /// 止めたあとに届いた古い終了通知で、次に鳴らした音声を止めない。
    private func finish(_ finished: AVAudioPlayer) {
        guard finished === player else { return }
        finishCurrentPlayback()
    }

    private func finishCurrentPlayback() {
        player?.stop()
        player = nil
        playingURL = nil
        playNext()
    }
}
