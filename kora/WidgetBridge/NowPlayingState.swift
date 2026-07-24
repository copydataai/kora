import Foundation
import WidgetKit

enum NowPlayingState {
    static func write(track: Track?, title: String, artist: String?, artwork: Data?, isPlaying: Bool) {
        guard let url = NowPlayingSharedStore.containerURL() else { return }
        guard let track else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let snap = NowPlayingSnapshot(
            title: title,
            artist: artist,
            isPlaying: isPlaying,
            artworkData: artwork,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url)
            WidgetCenter.shared.reloadTimelines(ofKind: "kora-now-playing-widget")
        }
    }
}
