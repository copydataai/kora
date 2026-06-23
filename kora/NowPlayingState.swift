import Foundation

// Mirror of NowPlayingSnapshot defined in koraWidget/KoraWidgetModels.swift.
// Property names and types must remain identical so the JSON round-trips.
private struct NowPlayingSnapshot: Codable {
    var title: String
    var artist: String?
    var isPlaying: Bool
    var artworkData: Data?
    var updatedAt: Date
}

private enum NowPlayingSharedStore {
    static let appGroup = "group.app.copydataai.kora"
    static let fileName = "nowplaying.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }
}

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
