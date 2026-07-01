import Testing
import Foundation
@testable import kora

struct LibraryScanTests {
    private func tempDir() -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("korascan-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    private func write(_ name: String, in dir: URL) {
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data())
    }

    @Test func findsNestedAudioAndSkipsNonAudio() {
        let root = tempDir()
        write("a.mp3", in: root)
        write("notes.txt", in: root)
        write("cover.jpg", in: root)
        let sub = root.appendingPathComponent("album")
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        write("b.flac", in: sub)

        let files = MusicLibrary.audioFiles(in: root).map { $0.lastPathComponent }
        #expect(files.contains("a.mp3"))
        #expect(files.contains("b.flac"))   // two levels deep
        #expect(!files.contains("notes.txt"))
        #expect(!files.contains("cover.jpg"))
        #expect(files.count == 2)
    }

    @Test func audioFilesReflectsAddedAndRemovedFiles() {
        let root = tempDir()
        write("a.mp3", in: root)
        #expect(MusicLibrary.audioFiles(in: root).count == 1)

        write("b.mp3", in: root)
        #expect(MusicLibrary.audioFiles(in: root).count == 2)   // rescan would pick this up

        try? FileManager.default.removeItem(at: root.appendingPathComponent("a.mp3"))
        #expect(MusicLibrary.audioFiles(in: root).map(\.lastPathComponent) == ["b.mp3"])
    }

    @Test func skipsFormatsAVPlayerCannotDecode() {
        let root = tempDir()
        write("a.mp3", in: root)
        write("b.ogg", in: root)
        write("c.opus", in: root)

        // AVPlayer can't decode ogg/opus; scanning them in means silent play failures.
        #expect(MusicLibrary.audioFiles(in: root).map(\.lastPathComponent) == ["a.mp3"])
    }

    @Test @MainActor func trackTitleDefaultsToFilename() {
        let t = Track(url: URL(fileURLWithPath: "/m/Song Name.m4a"), folderID: UUID())
        #expect(t.title == "Song Name")
        #expect(t.artist == nil)
    }

    // Search is filename/title search by design: tags aren't indexed at scan,
    // so `title` (filename-derived) is what the user can actually match on.
    @Test @MainActor func searchMatchesTitleAndArtistCaseInsensitively() {
        let t = Track(url: URL(fileURLWithPath: "/m/Blue Train.mp3"), folderID: UUID(),
                      artist: "John Coltrane")
        #expect(MusicLibrary.matches(t, query: "blue"))
        #expect(MusicLibrary.matches(t, query: "TRAIN"))
        #expect(MusicLibrary.matches(t, query: "coltrane"))
        #expect(!MusicLibrary.matches(t, query: "miles"))
    }

    @Test @MainActor func emptyOrWhitespaceQueryMatchesNothing() {
        let t = Track(url: URL(fileURLWithPath: "/m/a.mp3"), folderID: UUID())
        #expect(!MusicLibrary.matches(t, query: ""))
        #expect(!MusicLibrary.matches(t, query: "   "))
    }
}
