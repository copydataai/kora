import Foundation

@MainActor
final class PhaseExecutionStore: ObservableObject {
    @Published private(set) var completedMilestones: Set<String> = []

    private let storageKey = "kora.phase.completedMilestones"
    private let stateFileName = "milestone-state.json"

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

    private func saveToFile(_ values: [String]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        KoraAppStateMigration.saveStateData(data, fileName: stateFileName)
    }

    private func loadFromFileFallback() -> Set<String>? {
        guard let data = KoraAppStateMigration.loadStateData(fileName: stateFileName) else { return nil }
        let decoded = try? JSONDecoder().decode([String].self, from: data)
        return decoded.map(Set.init)
    }
}
