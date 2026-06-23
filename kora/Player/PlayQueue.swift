import Foundation

struct PlayQueue {
    private(set) var tracks: [Track]
    private(set) var index: Int

    init(tracks: [Track], startAt: Int = 0) {
        self.tracks = tracks
        self.index = tracks.isEmpty ? 0 : min(max(startAt, 0), tracks.count - 1)
    }

    var current: Track? {
        tracks.indices.contains(index) ? tracks[index] : nil
    }

    var hasNext: Bool { index + 1 < tracks.count }
    var hasPrevious: Bool { index > 0 }

    mutating func next() -> Track? {
        guard hasNext else { return nil }
        index += 1
        return tracks[index]
    }

    mutating func previous() -> Track? {
        guard hasPrevious else { return nil }
        index -= 1
        return tracks[index]
    }
}
