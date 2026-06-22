import Foundation

enum KoraWidgetStateFileSource {
    static let fileManager = FileManager.default
    static let supportRoot = "Kora"
    static let hostBundleIdentifier = "app.copydataai.kora"

    static func loadPayload() -> KoraWidgetPayload? {
        guard let data = loadStateData(fileName: "widget-state.json") else { return nil }
        return try? JSONDecoder().decode(KoraWidgetPayload.self, from: data)
    }

    static func loadStateData(fileName: String) -> Data? {
        guard let sourceURL = resolveStateSource(fileName: fileName) else { return nil }
        return try? Data(contentsOf: sourceURL)
    }

    private static func resolveStateSource(fileName: String) -> URL? {
        for candidate in candidateStateURLs(fileName) where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private static func candidateStateURLs(_ fileName: String) -> [URL] {
        let canonicalURL = supportDirectory()
            .appendingPathComponent(supportRoot)
            .appendingPathComponent(hostBundleIdentifier)
            .appendingPathComponent(fileName)

        let extensionBundleIdentifier = Bundle.main.bundleIdentifier ?? "app.copydataai.koraWidget"
        let extensionURL = supportDirectory()
            .appendingPathComponent(supportRoot)
            .appendingPathComponent(extensionBundleIdentifier)
            .appendingPathComponent(fileName)

        let legacyRoot = supportDirectory().appendingPathComponent(supportRoot)
        var candidates: [URL] = [canonicalURL, extensionURL, legacyRoot.appendingPathComponent(fileName)]
        var seenPaths = Set(candidates.map(\.path))

        if let nested = try? fileManager.contentsOfDirectory(
            at: legacyRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for folder in nested {
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

    private static func supportDirectory() -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}

struct KoraWidgetSnapshotQuery {
    static func loadLatestPayload() -> KoraWidgetPayload? {
        KoraWidgetStateFileSource.loadPayload()
    }

    static func isPayloadStale(_ payload: KoraWidgetPayload, asOf date: Date, maxAgeMinutes: Double = 30) -> Bool {
        let maxAge = TimeInterval(maxAgeMinutes * 60)
        return date.timeIntervalSince(payload.generatedAt) > maxAge
    }

    static func formatAge(_ date: Date, reference: Date = Date()) -> String {
        let interval = max(0, Int(reference.timeIntervalSince(date)))
        if interval < 60 {
            return "just now"
        }

        let minutes = interval / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }

        let days = hours / 24
        return "\(days)d"
    }
}
