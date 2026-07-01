import Foundation
import SwiftUI   // for Array.move(fromOffsets:toOffset:)

struct PlayQueue {
    private(set) var tracks: [Track]
    private(set) var index: Int
    private(set) var isShuffled = false
    private var originalTracks: [Track] = []

    /// `isShuffled: true` marks a queue already in shuffled order (a restored
    /// session); there's no original order to return to, which setShuffled(false)
    /// tolerates.
    init(tracks: [Track], startAt: Int = 0, isShuffled: Bool = false) {
        self.tracks = tracks
        self.index = tracks.isEmpty ? 0 : min(max(startAt, 0), tracks.count - 1)
        self.isShuffled = isShuffled
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

    mutating func jump(to newIndex: Int) {
        guard !tracks.isEmpty else { return }
        index = min(max(newIndex, 0), tracks.count - 1)
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let currentID = current?.id
        tracks.move(fromOffsets: source, toOffset: destination)
        if let currentID, let i = tracks.firstIndex(where: { $0.id == currentID }) {
            index = i
        }
    }

    /// Shuffling moves the current track to the front so playback never jumps;
    /// un-shuffling restores the pre-shuffle order and re-finds the current track.
    mutating func setShuffled(_ on: Bool) {
        guard on != isShuffled else { return }
        isShuffled = on
        if on {
            originalTracks = tracks
            guard let current else { return }
            var rest = tracks
            rest.removeAll { $0.id == current.id }
            rest.shuffle()
            tracks = [current] + rest
            index = 0
        } else {
            let currentID = current?.id
            // Guard: a session restored mid-shuffle has no original order to return to.
            if !originalTracks.isEmpty { tracks = originalTracks }
            originalTracks = []
            index = tracks.firstIndex { $0.id == currentID } ?? 0
        }
    }
}
