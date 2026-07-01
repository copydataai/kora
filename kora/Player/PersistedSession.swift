import Foundation

/// Snapshot of the play queue for resume-on-launch. Paths, not Tracks:
/// track UUIDs are regenerated every scan, but file paths are stable.
struct PersistedSession: Codable, Equatable {
    var paths: [String]
    var index: Int
    var elapsed: TimeInterval

    func encode() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> PersistedSession? {
        try? JSONDecoder().decode(PersistedSession.self, from: data)
    }

    /// Restorable only if the saved index is in bounds and the current file still exists.
    func isRestorable(fileExists: (String) -> Bool) -> Bool {
        paths.indices.contains(index) && fileExists(paths[index])
    }
}
