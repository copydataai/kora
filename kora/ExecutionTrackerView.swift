import SwiftUI

struct ExecutionTrackerView: View {
    @State private var selectedPhase = KoraPhase.planning
    @StateObject private var executionStore = PhaseExecutionStore()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPhase) {
                Section("Kora phased execution") {
                    ForEach(KoraPhase.allCases) { phase in
                        let firstMilestone = phase.milestones.first
                        HStack {
                            Label {
                                Text(phase.title)
                            } icon: {
                                if executionStore.isPhaseComplete(phase) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                } else if let firstMilestone, executionStore.isCompleted(firstMilestone.id) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .tag(phase)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 280)
            .toolbar {
                ToolbarItem {
                    Button("Reset all") {
                        executionStore.clearAll()
                    }
                }
            }
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                phaseHeader
                phaseProgressSection
                milestonesList
                nextActionSection
                Text("Keep this checklist local to this workspace for now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
    }

    private var phaseHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedPhase.title)
                .font(.title)
                .fontWeight(.semibold)

            Text(selectedPhase.goal)
                .foregroundStyle(.secondary)
        }
    }

    private var phaseProgressSection: some View {
        let milestones = selectedPhase.milestones
        return VStack(alignment: .leading) {
            ProgressView(
                value: phaseProgress(milestones: milestones),
                total: Double(max(milestones.count, 1))
            )
            .progressViewStyle(.linear)

            Text("\(Int(phaseProgress(milestones: milestones)))/\(milestones.count) milestones complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var milestonesList: some View {
        let milestones = selectedPhase.milestones
        return VStack(alignment: .leading, spacing: 8) {
            Text("Milestones")
                .font(.headline)

            List {
                ForEach(milestones) { milestone in
                    Toggle(isOn: binding(for: milestone.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(milestone.title)
                            HStack {
                                Text("Owner: \(milestone.ownerHint)")
                                Text("•")
                                Text(milestone.artifactHint)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 260)
        }
    }

    private var nextActionSection: some View {
        let next = executionStore.nextMilestone(for: selectedPhase)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Execution loop")
                .font(.headline)

            if let next {
                VStack(alignment: .leading) {
                    Text("Next action")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(next.title)
                        .fontWeight(.medium)

                    Button("Complete and continue") {
                        executionStore.complete(next.id)
                        goToNextPhaseIfDone()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("All milestones complete for this phase.")
                    .foregroundStyle(.secondary)

                if let nextPhase = nextPhase(after: selectedPhase) {
                    Button("Start next phase") {
                        selectedPhase = nextPhase
                    }
                }
            }
        }
    }

    private func phaseProgress(milestones: [KoraMilestone]) -> Double {
        guard !milestones.isEmpty else { return 0 }
        let done = milestones.filter { executionStore.isCompleted($0.id) }.count
        return Double(done)
    }

    private func binding(for milestoneID: String) -> Binding<Bool> {
        Binding(
            get: { executionStore.isCompleted(milestoneID) },
            set: { isDone in
                executionStore.setCompleted(milestoneID, isDone: isDone)
            }
        )
    }

    private func goToNextPhaseIfDone() {
        guard executionStore.isPhaseComplete(selectedPhase) else { return }
        if let nextPhase = nextPhase(after: selectedPhase) {
            selectedPhase = nextPhase
        }
    }

    private func nextPhase(after phase: KoraPhase) -> KoraPhase? {
        KoraPhase(rawValue: phase.rawValue + 1)
    }
}

#Preview {
    ExecutionTrackerView()
}
