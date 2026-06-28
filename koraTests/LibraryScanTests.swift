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

    @Test @MainActor func trackTitleDefaultsToFilename() {
        let t = Track(url: URL(fileURLWithPath: "/m/Song Name.m4a"), folderID: UUID())
        #expect(t.title == "Song Name")
        #expect(t.artist == nil)
    }
}
