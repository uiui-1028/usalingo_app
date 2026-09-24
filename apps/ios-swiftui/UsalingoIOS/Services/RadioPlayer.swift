import AVFoundation
import Foundation
import MediaPlayer

/// 自動で止まるまでの時間。
enum RadioSleep: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    var id: Int { rawValue }

    var title: String { self == .off ? "なし" : "\(rawValue)分" }
}

/// デッキを流し続けるラジオ。1語ぶんを「英単語 → 日本語訳 → 英語例文」の順に鳴らし、
/// 終わったら次の語へ進む。デッキを一周したら混ぜ直して、また流し続ける。
///
/// 画面を閉じても鳴り続けるので、音声セッションとロック画面の操作もここで持つ。
@MainActor
final class RadioPlayer: NSObject, ObservableObject {
    /// 再生の速さで許す範囲。`AVAudioPlayer` が素直に鳴らせる幅に合わせてある。
    static let minimumRate = 0.5
    static let maximumRate = 2.0
    /// 語と語のあいだに置く無音の長さ（秒）で許す範囲。
    static let minimumGap = 0.5
    static let maximumGap = 5.0

    @Published private(set) var currentCard: WordCard?
    /// カルーセルで前後に並べる札。鳴らしはしない。
    @Published private(set) var previousCard: WordCard?
    @Published private(set) var nextCard: WordCard?
    @Published private(set) var isPlaying = false
    @Published private(set) var rate = 1.0
    /// 語と語のあいだに置く無音の長さ（秒）。口に出して真似る間と、思い出す間を作る。
    @Published private(set) var gap = RadioPlayer.minimumGap
    @Published private(set) var sleep: RadioSleep = .off
    /// スリープで止まる時刻。画面の残り時間表示に使う。
    @Published private(set) var sleepDeadline: Date?
    /// 流せるカードが1枚も無かった。画面で案内を出す。
    @Published private(set) var hasNoPlayableCard = false
    /// 1語ぶんの音声が終わり、画面へ次のカード送りを頼む番号。
    @Published private(set) var automaticAdvanceRequest = 0

    private let cache: CardAudioCache
    private let synthesizer = AVSpeechSynthesizer()
    private var queue = RadioQueue(cards: [])
    private var steps: [RadioStep] = []
    private var stepIndex = 0
    private var player: AVAudioPlayer?
    /// 音源の取得と、無音のあいだの待ち。次の音を鳴らす前に必ず片付ける。
    private var stepTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
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

#if DEBUG
    static func preview(cards: [WordCard]) -> RadioPlayer {
        let player = RadioPlayer()
        player.queue = RadioQueue(cards: cards, shufflesEachLap: false)
        player.currentCard = player.queue.current
        return player
    }
#endif

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

    var playableCardCount: Int { queue.cards.count }
    var carouselIndex: Int { queue.index }

    func carouselCard(relativeOffset: Int) -> WordCard? {
        queue.card(relativeOffset: relativeOffset)
    }

    /// 手でカードを送る直前に音を止め、移動後に再開すべきだったかを返す。
    @discardableResult
    func pauseForCarouselTransition() -> Bool {
        let shouldResume = isPlaying
        if shouldResume { pause() }
        return shouldResume
    }

    /// 途中の札は鳴らさず、最後に止まった札だけを再生する。
    func moveCarousel(by offset: Int, shouldPlay: Bool) {
        guard offset != 0, !queue.isEmpty else { return }
        guard queue.cards.count > 1 else {
            beginCurrentCard(shouldPlay: shouldPlay)
            return
        }
        if offset > 0 {
            for _ in 0..<offset { queue.advance() }
        } else {
            for _ in 0..<(-offset) { queue.rewind() }
        }
        beginCurrentCard(shouldPlay: shouldPlay)
    }

    /// 速さを変える。指を滑らせている最中に読み直すと落ち着かないので、
    /// 収録音源だけその場で追従させ、読み上げの作り直しは `commitRate()` に任せる。
    func setRate(_ rate: Double) {
        let clamped = min(max(rate, Self.minimumRate), Self.maximumRate)
        guard clamped != self.rate else { return }
        self.rate = clamped
        player?.rate = Float(clamped)
        updateNowPlaying()
    }

    /// 速さを決め終えたときに呼ぶ。読み上げ中は速さを差し替えられないので、その語だけ読み直す。
    func commitRate() {
        guard speakingUtterance != nil else { return }
        playCurrentStep()
    }

    func setGap(_ gap: Double) {
        self.gap = min(max(gap, Self.minimumGap), Self.maximumGap)
    }

    func setSleep(_ sleep: RadioSleep) {
        sleepTask?.cancel()
        sleepTask = nil
        self.sleep = sleep
        guard sleep != .off else {
            sleepDeadline = nil
            return
        }
        let seconds = UInt64(sleep.rawValue) * 60
        sleepDeadline = Date().addingTimeInterval(TimeInterval(seconds))
        sleepTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.finishSleep()
        }
    }

    /// 画面を閉じるときに呼ぶ。鳴らしているものと、ロック画面の表示を片付ける。
    func stop() {
        generation += 1
        stepTask?.cancel()
        stepTask = nil
        sleepTask?.cancel()
        sleepTask = nil
        sleep = .off
        sleepDeadline = nil
        player?.stop()
        player = nil
        speakingUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentCard = nil
        previousCard = nil
        nextCard = nil
        clearRemoteCommands()
        NotificationCenter.default.removeObserver(self)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isConfigured = false
    }

    // MARK: - 再生

    private func beginCurrentCard(shouldPlay: Bool = true) {
        currentCard = queue.current
        previousCard = queue.previous
        nextCard = queue.next
        steps = queue.currentSteps
        stepIndex = 0
        prefetchNextCard()
        if shouldPlay {
            playCurrentStep()
        } else {
            stopCurrentSound()
            isPlaying = false
            updateNowPlaying()
        }
    }

    private func playCurrentStep() {
        generation += 1
        let generation = self.generation
        stepTask?.cancel()
        stepTask = nil
        player?.stop()
        player = nil
        speakingUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)

        guard stepIndex < steps.count else {
            automaticAdvanceRequest += 1
            return
        }

        isPlaying = true
        updateNowPlaying()

        switch steps[stepIndex] {
        case .word(let url), .sentence(let url):
            stepTask = Task { [cache] in
                let data = try? await cache.data(for: url)
                guard !Task.isCancelled, generation == self.generation else { return }
                self.stepTask = nil
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
        audioPlayer.rate = Float(rate)
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
        utterance.rate = min(
            max(AVSpeechUtteranceDefaultSpeechRate * Float(rate), AVSpeechUtteranceMinimumSpeechRate),
            AVSpeechUtteranceMaximumSpeechRate
        )
        // 訳のあとに例文がすぐ続くと切り替わりが速すぎるので、ひと呼吸置く。
        utterance.postUtteranceDelay = 0.3
        speakingUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// 次の音へ送る。設定した無音の長さだけ待ってから鳴らす。
    func advanceStep() {
        stepIndex += 1
        generation += 1
        let generation = self.generation
        stepTask?.cancel()
        stepTask = nil
        player = nil
        // 一時停止直後にも音声の終了通知は届く。次の位置だけ記録し、勝手に再開しない。
        guard isPlaying else { return }
        let seconds = gap
        stepTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, generation == self.generation else { return }
            self.playCurrentStep()
        }
    }

    private func pause() {
        isPlaying = false
        stepTask?.cancel()
        stepTask = nil
        player?.pause()
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        updateNowPlaying()
    }

    private func stopCurrentSound() {
        generation += 1
        stepTask?.cancel()
        stepTask = nil
        player?.stop()
        player = nil
        speakingUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
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

    private func finishSleep() {
        sleepTask = nil
        sleep = .off
        sleepDeadline = nil
        guard isPlaying else { return }
        pause()
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
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0
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
