import AVFoundation
import Combine
import Foundation

@MainActor
final class MusicPlayer: ObservableObject {
    @Published private(set) var currentTrackName = "No track selected"
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var artist: String?
    @Published private(set) var artwork: Data?
    @Published private(set) var theme: ArtworkTheme = .neutral
    @Published private(set) var currentTrackID: UUID?
    @Published private(set) var queueTracks: [Track] = []
    @Published private(set) var queueIndex: Int = 0
    @Published var volume: Double {
        didSet {
            player?.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: "player.volume")
        }
    }

    var onTrackChange: ((Track?, Bool) -> Void)?

    private var player: AVPlayer?
    private var progressTimer: Timer?
    private var securityScopedURL: URL?
    private var queue = PlayQueue(tracks: [], startAt: 0)
    private var itemObservers: Set<AnyCancellable> = []
    private var durationTask: Task<Void, Never>?

    var hasTrack: Bool {
        player?.currentItem != nil
    }

    init() {
        let saved = UserDefaults.standard.object(forKey: "player.volume") as? Double
        self.volume = saved ?? 1.0
        configureRemoteCommands()   // defined in NowPlayingCenter.swift
    }

    func load(url: URL) {
        stopTimer()
        player?.pause()
        itemObservers.removeAll()
        durationTask?.cancel()
        releaseSecurityScopedURL()

        let didStartAccess = url.startAccessingSecurityScopedResource()
        if didStartAccess { securityScopedURL = url }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = Float(volume)

        player = avPlayer
        currentTrackName = url.deletingPathExtension().lastPathComponent
        currentTime = 0
        duration = 0
        isPlaying = false
        errorMessage = nil

        // AVPlayer doesn't throw at init; surface load failures via item status.
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.player === avPlayer else { return }
                if status == .failed { self.errorMessage = "Could not load that audio file." }
            }
            .store(in: &itemObservers)

        // AVPlayer posts this at the exact end — replaces the old polling heuristic.
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.player === avPlayer else { return }
                self.handlePlaybackFinished()
            }
            .store(in: &itemObservers)

        // Duration loads asynchronously; publish it when known (the seek bar tolerates 0).
        durationTask = Task { [weak self] in
            let loaded = try? await asset.load(.duration)
            guard let self, !Task.isCancelled, self.player === avPlayer else { return }
            let seconds = loaded?.seconds ?? 0
            self.duration = seconds.isFinite ? seconds : 0
            self.updateNowPlayingInfo()
        }
    }

    func playPause() {
        guard let player else {
            errorMessage = "Choose an audio file first."
            return
        }
        if player.timeControlStatus == .paused {
            player.play()
            isPlaying = true
            errorMessage = nil
            startTimer()
        } else {
            player.pause()
            isPlaying = false
            stopTimer()
        }
        updateNowPlayingInfo()
        onTrackChange?(queue.current, isPlaying)
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        currentTime = 0
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
        onTrackChange?(queue.current, false)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func reportFileSelectionFailure() {
        errorMessage = "Could not choose an audio file."
    }

    func play(track: Track, in tracks: [Track]) {
        let start = tracks.firstIndex(of: track) ?? 0
        queue = PlayQueue(tracks: tracks, startAt: start)
        loadAndPlayCurrent()
    }

    func next() {
        guard queue.next() != nil else { return }
        loadAndPlayCurrent()
    }

    func previous() {
        guard queue.previous() != nil else { return }
        loadAndPlayCurrent()
    }

    func jumpInQueue(to index: Int) {
        queue.jump(to: index)
        loadAndPlayCurrent()   // updates the published queue via syncQueue()
    }

    func moveInQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        syncQueue()
    }

    private func syncQueue() {
        queueTracks = queue.tracks
        queueIndex = queue.index
        currentTrackID = queue.current?.id
    }

    private func loadAndPlayCurrent() {
        guard let track = queue.current else { return }
        syncQueue()
        load(url: track.url)              // sets up AVPlayer/duration/observers
        currentTrackName = track.title
        artist = track.artist
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
        onTrackChange?(track, true)
        Task { await refreshMetadata(for: track) }
    }

    private func refreshMetadata(for track: Track) async {
        let meta = await track.loadMetadata()
        let art = await track.loadArtwork()
        // Guard against a newer track having started while we awaited.
        guard queue.current?.id == track.id else { return }
        currentTrackName = meta.title
        artist = meta.artist
        artwork = art
        theme = await ArtworkPalette.theme(for: art)
        updateNowPlayingInfo()
        onTrackChange?(queue.current, isPlaying)
    }

    private func handlePlaybackFinished() {
        if queue.hasNext {
            next()
        } else {
            stop()   // stop() already fires onTrackChange(false) + updateNowPlayingInfo()
        }
    }

    private func startTimer() {
        stopTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgress()
            }
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func syncProgress() {
        guard let player, player.currentItem != nil else {
            currentTime = 0
            isPlaying = false
            stopTimer()
            return
        }
        let t = player.currentTime().seconds
        if t.isFinite { currentTime = t }
        // Now Playing elapsed is set on state changes (play/pause/seek); the system
        // extrapolates between them from the playback rate, so no per-tick update here.
    }

    private func releaseSecurityScopedURL() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}
