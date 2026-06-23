import Foundation

enum NowPlayingState {
    static func write(track: Track?, isPlaying: Bool) {
        guard let url = NowPlayingSharedStore.containerURL() else { return }
        guard let track else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let snap = NowPlayingSnapshot(
            title: track.title,
            artist: track.artist,
            isPlaying: isPlaying,
            artworkData: nil,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url)
        }
    }
}
