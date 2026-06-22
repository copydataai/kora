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

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var securityScopedURL: URL?

    var hasTrack: Bool {
        player != nil
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
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
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
        guard let player else {
            currentTime = 0
            isPlaying = false
            stopTimer()
            return
        }

        currentTime = player.currentTime

        if !player.isPlaying {
            isPlaying = false
            stopTimer()

            if duration > 0, currentTime >= duration - 0.25 {
                player.currentTime = 0
                currentTime = 0
            }
        }
    }

    private func releaseSecurityScopedURL() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}
