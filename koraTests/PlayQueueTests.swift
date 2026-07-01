import Testing
import Foundation
@testable import kora

@MainActor
private func track(_ name: String) -> Track {
    Track(url: URL(fileURLWithPath: "/tmp/\(name).mp3"), folderID: UUID())
}

struct PlayQueueTests {
    @Test @MainActor func startsAtRequestedIndex() {
        var q = PlayQueue(tracks: [track("a"), track("b"), track("c")], startAt: 1)
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func nextAdvancesAndStopsAtEnd() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 0)
        #expect(q.next()?.title == "b")
        #expect(q.next() == nil)          // no wrap past end
        #expect(q.current?.title == "b")  // stays on last
    }

    @Test @MainActor func previousStepsBackAndStopsAtStart() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 1)
        #expect(q.previous()?.title == "a")
        #expect(q.previous() == nil)
        #expect(q.current?.title == "a")
    }

    @Test @MainActor func emptyQueueHasNoCurrent() {
        var q = PlayQueue(tracks: [], startAt: 0)
        #expect(q.current == nil)
        #expect(q.next() == nil)
    }

    @Test @MainActor func jumpClampsIntoBounds() {
        var q = PlayQueue(tracks: [track("a"), track("b"), track("c")], startAt: 0)
        q.jump(to: 2)
        #expect(q.current?.title == "c")
        q.jump(to: 99)
        #expect(q.current?.title == "c")   // clamped to last
        q.jump(to: -5)
        #expect(q.current?.title == "a")   // clamped to first
    }

    @Test @MainActor func moveKeepsCurrentTrackWhenItShifts() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 0)   // current = a
        // Move "a" from front to the end; current must still be "a".
        q.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(q.tracks.map(\.title) == ["b", "c", "a"])
        #expect(q.current?.title == "a")
    }

    @Test @MainActor func moveOtherTrackLeavesCurrentUnchanged() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 1)   // current = b
        // Move "c" before "a"; current is still "b".
        q.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(q.tracks.map(\.title) == ["c", "a", "b"])
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func shuffleKeepsCurrentFirstAndPreservesTrackSet() {
        let a = track("a"), b = track("b"), c = track("c"), d = track("d")
        var q = PlayQueue(tracks: [a, b, c, d], startAt: 2)   // current = c
        q.setShuffled(true)
        #expect(q.isShuffled)
        #expect(q.current?.title == "c")                       // playback never jumps
        #expect(q.index == 0)                                  // current leads the shuffled order
        #expect(Set(q.tracks.map(\.title)) == ["a", "b", "c", "d"])
    }

    @Test @MainActor func unshuffleRestoresOriginalOrderAndCurrentTrack() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 1)       // current = b
        q.setShuffled(true)
        q.setShuffled(false)
        #expect(!q.isShuffled)
        #expect(q.tracks.map(\.title) == ["a", "b", "c"])
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func shuffleOnEmptyOrRedundantCallsIsSafe() {
        var empty = PlayQueue(tracks: [], startAt: 0)
        empty.setShuffled(true)
        #expect(empty.current == nil)

        var q = PlayQueue(tracks: [track("a")], startAt: 0)
        q.setShuffled(false)                                   // no-op: already off
        #expect(q.tracks.count == 1)                           // must not clobber tracks
        q.setShuffled(true)
        q.setShuffled(true)                                    // no-op: already on
        #expect(q.tracks.count == 1)
    }

    // A restored session is already in shuffled order with no original to return
    // to; un-shuffling must keep the tracks rather than clobber them.
    @Test @MainActor func unshuffleOnRestoredShuffledQueueKeepsTracks() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 1, isShuffled: true)
        #expect(q.isShuffled)
        q.setShuffled(false)
        #expect(!q.isShuffled)
        #expect(q.tracks.count == 2)
        #expect(q.current?.title == "b")
    }

    // End-of-track policy: this is WHY repeat modes exist — one loops the track,
    // all loops the queue, off stops at the end. Encoded as a pure function so
    // it's testable without AVPlayer.
    @Test func finishActionHonorsRepeatMode() {
        #expect(MusicPlayer.finishAction(repeatMode: .one, hasNext: true) == .replay)
        #expect(MusicPlayer.finishAction(repeatMode: .one, hasNext: false) == .replay)
        #expect(MusicPlayer.finishAction(repeatMode: .all, hasNext: true) == .advance)
        #expect(MusicPlayer.finishAction(repeatMode: .all, hasNext: false) == .wrapToStart)
        #expect(MusicPlayer.finishAction(repeatMode: .off, hasNext: true) == .advance)
        #expect(MusicPlayer.finishAction(repeatMode: .off, hasNext: false) == .stop)
    }
}
