import Foundation

enum KoraAppStateMigration {
    private static let fileManager = FileManager.default
    private static let supportRoot = "Kora"

    static var canonicalNamespace: String {
        Bundle.main.bundleIdentifier ?? supportRoot
    }

    static func stateFileURL(for fileName: String) -> URL {
        currentDirectory().appendingPathComponent(fileName)
    }

    static func loadStateData(fileName: String) -> Data? {
        guard let sourceURL = resolveStateSource(fileName) else { return nil }
        if sourceURL != stateFileURL(for: fileName) {
            migrate(sourceURL, to: stateFileURL(for: fileName))
        }
        return try? Data(contentsOf: sourceURL)
    }

    static func saveStateData(_ data: Data, fileName: String) {
        let destination = stateFileURL(for: fileName)
        let directory = destination.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: destination, options: .atomic)
    }

    private static func resolveStateSource(_ fileName: String) -> URL? {
        for candidate in candidateStateURLs(fileName) {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func migrate(_ source: URL, to destination: URL) {
        let destinationFolder = destination.deletingLastPathComponent()
        try? fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            return
        }
        try? fileManager.copyItem(at: source, to: destination)
    }

    private static func candidateStateURLs(_ fileName: String) -> [URL] {
        let currentURL = stateFileURL(for: fileName)
        let legacyRoot = legacyRootURL()
        var candidates = [currentURL, legacyRoot.appendingPathComponent(fileName)]
        var seenPaths = Set(candidates.map(\.path))

        if let nestedFolders = try? fileManager.contentsOfDirectory(
            at: legacyRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for folder in nestedFolders {
                guard let isDirectory = try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      isDirectory == true else {
                    continue
                }
                let candidate = folder.appendingPathComponent(fileName)
                if !seenPaths.contains(candidate.path) {
                    candidates.append(candidate)
                    seenPaths.insert(candidate.path)
                }
            }
        }
        return candidates
    }

    private static func currentDirectory() -> URL {
        let base = supportDirectory()
        return base
            .appendingPathComponent(supportRoot)
            .appendingPathComponent(canonicalNamespace)
    }

    private static func legacyRootURL() -> URL {
        supportDirectory().appendingPathComponent(supportRoot)
    }

    private static func supportDirectory() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}
