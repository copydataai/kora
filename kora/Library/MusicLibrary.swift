import Foundation
import Combine

@MainActor
final class MusicLibrary: ObservableObject {
    struct Folder: Identifiable, Hashable {
        let id: UUID
        let url: URL
        let bookmark: Data
        var name: String { url.lastPathComponent }
        var tracks: [Track]
    }

    @Published private(set) var folders: [Folder] = []

    private let defaults: UserDefaults
    private let bookmarksKey = "library.folderBookmarks"
    private var accessedURLs: [URL] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        for url in accessedURLs { url.stopAccessingSecurityScopedResource() }
    }

    // MARK: Pure persistence envelope (tested)

    nonisolated static func encodeBookmarks(_ data: [Data]) -> Data {
        (try? NSKeyedArchiver.archivedData(withRootObject: data as NSArray, requiringSecureCoding: true)) ?? Data()
    }

    nonisolated static func decodeBookmarks(_ data: Data) -> [Data] {
        let classes = [NSArray.self, NSData.self]
        let array = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? [Data]
        return array ?? []
    }

    // MARK: Public API

    func addFolder(url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        var saved = currentBookmarks()
        saved.append(bookmark)
        persist(saved)
        ingest(url: url, bookmark: bookmark)
    }

    func forget(_ folder: Folder) {
        folder.url.stopAccessingSecurityScopedResource()
        accessedURLs.removeAll { $0 == folder.url }
        folders.removeAll { $0.id == folder.id }
        persist(folders.map(\.bookmark))
    }

    func restore() {
        for bookmark in currentBookmarks() {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &stale
            ), !stale else { continue }   // drop stale silently
            ingest(url: url, bookmark: bookmark)
        }
    }

    // MARK: Internal

    private func ingest(url: URL, bookmark: Data) {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(url) }
        let folderID = UUID()
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folderID) }
        folders.append(Folder(id: folderID, url: url, bookmark: bookmark, tracks: tracks))
    }

    private func currentBookmarks() -> [Data] {
        guard let data = defaults.data(forKey: bookmarksKey) else { return [] }
        return MusicLibrary.decodeBookmarks(data)
    }

    private func persist(_ bookmarks: [Data]) {
        defaults.set(MusicLibrary.encodeBookmarks(bookmarks), forKey: bookmarksKey)
    }
}

extension MusicLibrary {
    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "alac", "caf", "ogg", "opus"
    ]

    /// Recursively collect audio files under `folder`, sorted by path for stable order.
    nonisolated static func audioFiles(in folder: URL, fileManager: FileManager = .default) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [URL] = []
        for case let url as URL in enumerator
        where audioExtensions.contains(url.pathExtension.lowercased()) {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }
}
