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
}
