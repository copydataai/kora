import Foundation
import Combine
import SwiftUI   // for Array.move(fromOffsets:toOffset:)

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

    /// A folder is available whenever its bookmark resolves to a URL. Staleness does
    /// not make it unavailable — a stale-but-resolvable bookmark is refreshed on restore.
    nonisolated static func isAvailable(resolvedURL: URL?) -> Bool {
        resolvedURL != nil
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
        // The window's .task re-runs on every reopen; restoring twice would
        // duplicate every folder.
        guard folders.isEmpty else { return }
        var refreshedAny = false
        for entry in loadPersisted() {
            var stale = false
            let url = try? URL(
                resolvingBookmarkData: entry.bookmark, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &stale
            )
            if MusicLibrary.isAvailable(resolvedURL: url), let url {
                let refreshed = ingest(url: url, bookmark: entry.bookmark,
                                       displayName: entry.displayName, refreshIfStale: stale)
                refreshedAny = refreshedAny || refreshed
            } else {
                // Truly unresolvable — keep a placeholder to re-link rather than vanish.
                folders.append(Folder(id: UUID(), url: nil, bookmark: entry.bookmark,
                                      displayName: entry.displayName, isAvailable: false, tracks: []))
            }
        }
        if refreshedAny { persistCurrent() }   // persist any regenerated bookmarks
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

    func rename(_ folder: Folder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].displayName = trimmed.isEmpty ? nil : trimmed
        persistCurrent()
    }

    func moveFolders(fromOffsets source: IndexSet, toOffset destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        persistCurrent()
    }

    // MARK: Internal

    @discardableResult
    private func ingest(url: URL, bookmark: Data, displayName: String?, refreshIfStale: Bool = false) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(url) }
        // A stale-but-resolvable bookmark is still usable; recreate it from the live URL
        // (Apple's documented fix) instead of forcing a manual re-link.
        var resolvedBookmark = bookmark
        var refreshed = false
        if refreshIfStale, let fresh = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            resolvedBookmark = fresh
            refreshed = true
        }
        let folderID = UUID()
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folderID) }
        folders.append(Folder(id: folderID, url: url, bookmark: resolvedBookmark,
                              displayName: displayName, isAvailable: true, tracks: tracks))
        return refreshed
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
    // ogg/opus intentionally absent: AVPlayer can't decode them, so scanning
    // them in produced tracks that silently failed to play.
    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "alac", "caf"
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

    /// Filename/title + artist search. Tags aren't indexed at scan time, so
    /// this is filename search in practice — good enough until it isn't.
    nonisolated static func matches(_ track: Track, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return false }
        if track.title.localizedCaseInsensitiveContains(q) { return true }
        if let artist = track.artist, artist.localizedCaseInsensitiveContains(q) { return true }
        return false
    }
}
