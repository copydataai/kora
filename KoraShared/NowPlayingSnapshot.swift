import Foundation

struct NowPlayingSnapshot: Codable, Hashable {
    var title: String
    var artist: String?
    var isPlaying: Bool
    var artworkData: Data?
    var updatedAt: Date
}

enum NowPlayingSharedStore {
    static let appGroup = "group.app.copydataai.kora"
    static let fileName = "nowplaying.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }
}
