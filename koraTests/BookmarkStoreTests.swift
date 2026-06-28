import Testing
import Foundation
@testable import kora

struct BookmarkStoreTests {
    // Verifies the persistence envelope round-trips: a corrupted decode here would
    // silently drop every saved folder on next launch.
    @Test func bookmarkArrayRoundTrips() throws {
        let a = Data([1, 2, 3])
        let b = Data([9, 8, 7, 6])
        let encoded = MusicLibrary.encodeBookmarks([a, b])
        let decoded = MusicLibrary.decodeBookmarks(encoded)
        #expect(decoded == [a, b])
    }

    @Test func decodeOfGarbageReturnsEmpty() {
        #expect(MusicLibrary.decodeBookmarks(Data([0xFF, 0x00])) == [])
    }

    @Test func persistedFoldersRoundTrip() {
        let folders = [
            MusicLibrary.PersistedFolder(bookmark: Data([1, 2, 3]), displayName: "Jazz"),
            MusicLibrary.PersistedFolder(bookmark: Data([4, 5]), displayName: nil),
        ]
        let decoded = MusicLibrary.decodePersisted(MusicLibrary.encodePersisted(folders))
        #expect(decoded == folders)
    }

    @Test func decodePersistedGarbageReturnsEmpty() {
        #expect(MusicLibrary.decodePersisted(Data([0xFF, 0x00])) == [])
    }

    @Test func migrateLegacyBookmarksKeepsOrderAndDropsNames() {
        let legacy = [Data([1]), Data([2]), Data([3])]
        let migrated = MusicLibrary.migrate(legacy: legacy)
        #expect(migrated.map(\.bookmark) == legacy)
        #expect(migrated.allSatisfy { $0.displayName == nil })
    }

    @Test func availabilityRequiresResolvableURL() {
        // A resolvable URL is available even if the bookmark was stale — staleness
        // triggers a bookmark refresh on restore, not a disappearing folder.
        #expect(MusicLibrary.isAvailable(resolvedURL: URL(fileURLWithPath: "/tmp/x")))
        #expect(!MusicLibrary.isAvailable(resolvedURL: nil))   // only unresolvable → unavailable
    }
}
