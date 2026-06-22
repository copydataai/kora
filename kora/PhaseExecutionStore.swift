import Foundation

@MainActor
final class PhaseExecutionStore: ObservableObject {
    @Published private(set) var completedMilestones: Set<String> = []

    private let storageKey = "kora.phase.completedMilestones"
    private let fileManager = FileManager.default

    init() {
        load()
    }

    func isCompleted(_ milestoneID: String) -> Bool {
        completedMilestones.contains(milestoneID)
    }

    func setCompleted(_ milestoneID: String, isDone: Bool) {
        if isDone {
            completedMilestones.insert(milestoneID)
        } else {
            completedMilestones.remove(milestoneID)
        }
        persist()
    }

    func nextMilestone(for phase: KoraPhase) -> KoraMilestone? {
        phase.milestones.first { !isCompleted($0.id) }
    }

    func complete(_ milestoneID: String) {
        guard !isCompleted(milestoneID) else { return }
        setCompleted(milestoneID, isDone: true)
    }

    func isPhaseComplete(_ phase: KoraPhase) -> Bool {
        phase.milestones.allSatisfy { isCompleted($0.id) }
    }

    func clearAll() {
        completedMilestones.removeAll()
        persist()
    }

    private func load() {
        if let data = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            completedMilestones = Set(data)
            return
        }

        if let restored = loadFromFileFallback() {
            completedMilestones = restored
            persist()
        }
    }

    private func persist() {
        let values = Array(completedMilestones)
        UserDefaults.standard.set(values, forKey: storageKey)
        saveToFile(values)
    }

    private func fileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let base = appSupport?.appendingPathComponent("Kora") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("milestone-state.json")
    }

    private func saveToFile(_ values: [String]) {
        let data = try? JSONEncoder().encode(values)
        guard let data else { return }
        try? data.write(to: fileURL(), options: .atomic)
    }

    private func loadFromFileFallback() -> Set<String>? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        let decoded = try? JSONDecoder().decode([String].self, from: data)
        return decoded.map(Set.init)
    }
}
