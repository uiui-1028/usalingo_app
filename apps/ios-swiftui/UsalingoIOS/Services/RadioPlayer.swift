import AVFoundation
import Foundation
import MediaPlayer

/// 読み上げと再生の速さ。
enum RadioRate: Double, CaseIterable, Identifiable {
    case slow = 0.75
    case normal = 1.0
    case fast = 1.25

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .slow: return "0.75x"
        case .normal: return "1.0x"
        case .fast: return "1.25x"
        }
    }
}

/// デッキを流し続けるラジオ。1語ぶんを「英単語 → 日本語訳 → 英語例文」の順に鳴らし、
/// 終わったら次の語へ進む。デッキを一周したら混ぜ直して、また流し続ける。
///
/// 画面を閉じても鳴り続けるので、音声セッションとロック画面の操作もここで持つ。
@MainActor
final class RadioPlayer: NSObject, ObservableObject {
    @Published private(set) var currentCard: WordCard?
    @Published private(set) var isPlaying = false
    @Published private(set) var rate: RadioRate = .normal
    /// 流せるカードが1枚も無かった。画面で案内を出す。
    @Published private(set) var hasNoPlayableCard = false

    private let cache: CardAudioCache
    private let synthesizer = AVSpeechSynthesizer()
    private var queue = RadioQueue(cards: [])
    private var steps: [RadioStep] = []
    private var stepIndex = 0
    private var player: AVAudioPlayer?
    private var loadTask: Task<Void, Never>?
    private var speakingUtterance: AVSpeechUtterance?
    private var deckName = ""
    private var isConfigured = false
    /// 止めたあとに届いた古い終了通知で、次の音を巻き込まないための世代番号。
    private var generation = 0

    init(cache: CardAudioCache = .shared) {
        self.cache = cache
        super.init()
        synthesizer.delegate = self
    }

    func start(cards: [WordCard], deckName: String) {
        guard !isConfigured else { return }
        isConfigured = true
        self.deckName = deckName
        queue = RadioQueue(cards: cards)
        hasNoPlayableCard = queue.isEmpty
        guard !queue.isEmpty else { return }

        activateSession()
        observeInterruptions()
        registerRemoteCommands()
        beginCurrentCard()
    }

    func togglePlay() {
        isPlaying ? pause() : resume()
    }

    func next() {
        queue.advance()
        beginCurrentCard()
    }

    func previous() {
        // 数秒だけ聞き逃したときに、いまの語の頭へ戻せるようにする。
        if stepIndex > 0 || (player?.currentTime ?? 0) > 2 {
            beginCurrentCard()
            return
        }
        queue.rewind()
        beginCurrentCard()
    }

    func setRate(_ rate: RadioRate) {
        guard rate != self.rate else { return }
        self.rate = rate
        player?.rate = Float(rate.rawValue)
        // 読み上げ中は速さを差し替えられないので、その語だけ読み直す。
        if speakingUtterance != nil {
            playCurrentStep()
        }
    }

    /// 画面を閉じるときに呼ぶ。鳴らしているものと、ロック画面の表示を片付ける。
    func stop() {
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        player?.stop()
        player = nil
        speakingUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentCard = nil
        clearRemoteCommands()
        NotificationCenter.default.removeObserver(self)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isConfigured = false
    }

    // MARK: - 再生

    private func beginCurrentCard() {
        currentCard = queue.current
        steps = queue.currentSteps
        stepIndex = 0
        prefetchNextCard()
        playCurrentStep()
    }

    private func playCurrentStep() {
        generation += 1
        let generation = self.generation
        loadTask?.cancel()
        loadTask = nil
        player?.stop()
        player = nil
        speakingUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)

        guard stepIndex < steps.count else {
            queue.advance()
            beginCurrentCard()
            return
        }

        isPlaying = true
        updateNowPlaying()

        switch steps[stepIndex] {
        case .word(let url), .sentence(let url):
            loadTask = Task { [cache] in
                let data = try? await cache.data(for: url)
                guard !Task.isCancelled, generation == self.generation else { return }
                self.loadTask = nil
                self.startFile(data: data, generation: generation)
            }
        case .meaning(let text):
            speak(text)
        }
    }

    private func startFile(data: Data?, generation: Int) {
        guard generation == self.generation else { return }
        guard let data, let audioPlayer = try? AVAudioPlayer(data: data) else {
            // 1本取れなくてもラジオは止めない。次へ送る。
            advanceStep()
            return
        }
        audioPlayer.delegate = self
        audioPlayer.enableRate = true
        audioPlayer.rate = Float(rate.rawValue)
        player = audioPlayer
        if audioPlayer.play() {
            updateNowPlaying()
        } else {
            advanceStep()
        }
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(rate.rawValue)
        // 訳のあとに例文がすぐ続くと切り替わりが速すぎるので、ひと呼吸置く。
        utterance.postUtteranceDelay = 0.3
        speakingUtterance = utterance
        synthesizer.speak(utterance)
    }

    private func advanceStep() {
        stepIndex += 1
        playCurrentStep()
    }

    private func pause() {
        isPlaying = false
        loadTask?.cancel()
        loadTask = nil
        player?.pause()
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        updateNowPlaying()
    }

    private func resume() {
        isPlaying = true
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else if let player {
            player.play()
        } else {
            playCurrentStep()
        }
        updateNowPlaying()
    }

    private func prefetchNextCard() {
        var lookahead = queue
        lookahead.advance()
        let urls = lookahead.currentSteps.compactMap { step -> URL? in
            switch step {
            case .word(let url), .sentence(let url): return url
            case .meaning: return nil
            }
        }
        guard !urls.isEmpty else { return }
        Task { await cache.prefetch(urls: urls) }
    }

    // MARK: - 音声セッションとロック画面

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private nonisolated func handleInterruption(_ notification: Notification) {
        guard
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: raw) == .began
        else { return }
        // 電話などで割り込まれたら止める。再開は利用者の操作に任せる。
        Task { @MainActor in self.pause() }
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayIfNeeded(shouldPlay: true) }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayIfNeeded(shouldPlay: false) }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
    }

    private func togglePlayIfNeeded(shouldPlay: Bool) {
        guard shouldPlay != isPlaying else { return }
        togglePlay()
    }

    private func clearRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.nextTrackCommand, center.previousTrackCommand] {
            command.removeTarget(nil)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func updateNowPlaying() {
        guard let currentCard else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentCard.text,
            MPMediaItemPropertyArtist: currentCard.primaryMeaning,
            MPMediaItemPropertyAlbumTitle: deckName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate.rawValue : 0.0
        ]
        // 長さと経過は、収録音源を鳴らしている間だけ出せる。読み上げ中は伏せる。
        if let player {
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}

extension RadioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish(player) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.finish(player) }
    }

    private func finish(_ finished: AVAudioPlayer) {
        guard finished === player else { return }
        player = nil
        advanceStep()
    }
}

extension RadioPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard utterance === self.speakingUtterance else { return }
            self.speakingUtterance = nil
            self.advanceStep()
        }
    }
}
