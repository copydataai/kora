import Foundation
import Combine

@MainActor
final class MusicLibrary: ObservableObject {
    struct Folder: Identifiable, Hashable {
        let id: UUID
        var url: URL?
        let bookmark: Data
        var displayName: String?
        var isAvailable: Bool
        var tracks: [Track]
        var name: String { displayName ?? url?.lastPathComponent ?? "Unavailable folder" }
    }

    nonisolated struct PersistedFolder: Codable, Equatable {
        var bookmark: Data
        var displayName: String?
    }

    @Published private(set) var folders: [Folder] = []

    private let defaults: UserDefaults
    private let bookmarksKey = "library.folderBookmarks"   // legacy [Data] blob, read for migration
    private let foldersKey = "library.folders.v2"
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

    nonisolated static func encodePersisted(_ folders: [PersistedFolder]) -> Data {
        (try? JSONEncoder().encode(folders)) ?? Data()
    }

    nonisolated static func decodePersisted(_ data: Data) -> [PersistedFolder] {
        (try? JSONDecoder().decode([PersistedFolder].self, from: data)) ?? []
    }

    nonisolated static func migrate(legacy bookmarks: [Data]) -> [PersistedFolder] {
        bookmarks.map { PersistedFolder(bookmark: $0, displayName: nil) }
    }

    nonisolated static func isAvailable(resolvedURL: URL?, isStale: Bool) -> Bool {
        resolvedURL != nil && !isStale
    }

    // MARK: Public API

    func addFolder(url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        ingest(url: url, bookmark: bookmark, displayName: nil)
        persistCurrent()
    }

    func forget(_ folder: Folder) {
        folder.url?.stopAccessingSecurityScopedResource()
        if let url = folder.url { accessedURLs.removeAll { $0 == url } }
        folders.removeAll { $0.id == folder.id }
        persistCurrent()
    }

    func restore() {
        for entry in loadPersisted() {
            var stale = false
            let url = try? URL(
                resolvingBookmarkData: entry.bookmark, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &stale
            )
            if MusicLibrary.isAvailable(resolvedURL: url, isStale: stale), let url {
                ingest(url: url, bookmark: entry.bookmark, displayName: entry.displayName)
            } else {
                // Keep a placeholder instead of vanishing — re-link comes in a later task.
                folders.append(Folder(id: UUID(), url: nil, bookmark: entry.bookmark,
                                      displayName: entry.displayName, isAvailable: false, tracks: []))
            }
        }
    }

    func rescan(_ folder: Folder) {
        guard let url = folder.url else { return }
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folder.id) }
        if let i = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[i].tracks = tracks
        }
    }

    func rescanAll() {
        for folder in folders where folder.isAvailable { rescan(folder) }
    }

    func relink(_ folder: Folder, to newURL: URL) {
        guard let bookmark = try? newURL.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        let accessed = newURL.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(newURL) }
        let tracks = MusicLibrary.audioFiles(in: newURL).map { Track(url: $0, folderID: folder.id) }
        if let i = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[i] = Folder(id: folder.id, url: newURL, bookmark: bookmark,
                                displayName: folder.displayName, isAvailable: true, tracks: tracks)
        }
        persistCurrent()
    }

    // MARK: Internal

    private func ingest(url: URL, bookmark: Data, displayName: String?) {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(url) }
        let folderID = UUID()
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folderID) }
        folders.append(Folder(id: folderID, url: url, bookmark: bookmark,
                              displayName: displayName, isAvailable: true, tracks: tracks))
    }

    private func loadPersisted() -> [PersistedFolder] {
        if let data = defaults.data(forKey: foldersKey) {
            return MusicLibrary.decodePersisted(data)
        }
        // One-time migration from the legacy [Data] bookmark blob.
        guard let legacyData = defaults.data(forKey: bookmarksKey) else { return [] }
        let migrated = MusicLibrary.migrate(legacy: MusicLibrary.decodeBookmarks(legacyData))
        persistFolders(migrated)
        return migrated
    }

    private func persistFolders(_ entries: [PersistedFolder]) {
        defaults.set(MusicLibrary.encodePersisted(entries), forKey: foldersKey)
    }

    private func persistCurrent() {
        persistFolders(folders.map { PersistedFolder(bookmark: $0.bookmark, displayName: $0.displayName) })
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
