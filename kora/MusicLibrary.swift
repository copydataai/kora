import Foundation
import Combine

@MainActor
final class MusicLibrary: ObservableObject {
    struct Folder: Identifiable, Hashable {
        let id: UUID
        let url: URL
        var name: String { url.lastPathComponent }
        var tracks: [Track]
    }

    @Published private(set) var folders: [Folder] = []
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
