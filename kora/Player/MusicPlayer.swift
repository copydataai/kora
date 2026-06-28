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
    @Published var volume: Double {
        didSet {
            player?.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: "player.volume")
        }
    }

    var onTrackChange: ((Track?, Bool) -> Void)?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var securityScopedURL: URL?
    private var queue = PlayQueue(tracks: [], startAt: 0)

    var hasTrack: Bool {
        player != nil
    }

    init() {
        let saved = UserDefaults.standard.object(forKey: "player.volume") as? Double
        self.volume = saved ?? 1.0
    }

    func load(url: URL) {
        stopTimer()
        player?.stop()
        releaseSecurityScopedURL()

        let didStartAccess = url.startAccessingSecurityScopedResource()

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()

            if didStartAccess {
                securityScopedURL = url
            }

            player = audioPlayer
            currentTrackName = url.deletingPathExtension().lastPathComponent
            currentTime = 0
            duration = audioPlayer.duration
            isPlaying = false
            errorMessage = nil
        } catch {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }

            player = nil
            currentTrackName = "No track selected"
            currentTime = 0
            duration = 0
            isPlaying = false
            errorMessage = "Could not load that audio file."
        }
    }

    func playPause() {
        guard let player else {
            errorMessage = "Choose an audio file first."
            return
        }

        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            errorMessage = nil
            startTimer()
        }
        onTrackChange?(queue.current, isPlaying)
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
        onTrackChange?(queue.current, false)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }

        let clampedTime = min(max(time, 0), duration)
        player.currentTime = clampedTime
        currentTime = clampedTime
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

    private func loadAndPlayCurrent() {
        guard let track = queue.current else { return }
        currentTrackID = track.id
        load(url: track.url)              // existing method sets player/duration/etc.
        player?.volume = Float(volume)
        currentTrackName = track.title
        artist = track.artist
        player?.play()
        isPlaying = true
        startTimer()
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
        onTrackChange?(queue.current, isPlaying)
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

    // Timer-based finish detection keeps playback simple; use AVAudioPlayerDelegate if precision becomes necessary.
    nonisolated static func shouldAdvanceOnFinish(wasPlaying: Bool, isPlayerPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) -> Bool {
        guard wasPlaying, !isPlayerPlaying, duration > 0 else { return false }
        return currentTime >= duration - 0.25
    }

    private func syncProgress() {
        guard let player else {
            currentTime = 0
            isPlaying = false
            stopTimer()
            return
        }

        let wasPlaying = isPlaying
        currentTime = player.currentTime

        if !player.isPlaying {
            isPlaying = false
            stopTimer()

            if MusicPlayer.shouldAdvanceOnFinish(wasPlaying: wasPlaying, isPlayerPlaying: player.isPlaying, currentTime: currentTime, duration: duration) {
                if queue.hasNext {
                    next()
                } else {
                    stop()
                    onTrackChange?(queue.current, false)
                }
            }
        }
    }

    private func releaseSecurityScopedURL() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}
