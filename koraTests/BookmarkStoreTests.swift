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
}
