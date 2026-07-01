import Testing
import Foundation
@testable import kora

struct PersistedSessionTests {
    @Test @MainActor func roundTripsThroughData() {
        let session = PersistedSession(paths: ["/m/a.mp3", "/m/b.mp3"], index: 1, elapsed: 42.5)
        #expect(PersistedSession.decode(session.encode()) == session)
    }

    @Test @MainActor func decodeRejectsGarbage() {
        #expect(PersistedSession.decode(Data("not json".utf8)) == nil)
    }

    // Restoring a queue whose current file vanished (or whose index is stale)
    // would resurrect a broken player; skip restore instead.
    @Test @MainActor func restorableOnlyWhenIndexValidAndCurrentFileExists() {
        let session = PersistedSession(paths: ["/m/a.mp3", "/m/b.mp3"], index: 1, elapsed: 0)
        #expect(session.isRestorable { _ in true })
        #expect(!session.isRestorable { _ in false })                       // file gone
        #expect(!PersistedSession(paths: ["/m/a.mp3"], index: 5, elapsed: 0)
            .isRestorable { _ in true })                                    // index out of bounds
        #expect(!PersistedSession(paths: [], index: 0, elapsed: 0)
            .isRestorable { _ in true })                                    // empty queue
    }
}
