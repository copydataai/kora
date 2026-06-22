import SwiftUI

struct ContentView: View {
    @State private var selectedPhase = KoraPhase.planning
    @State private var completedMilestones: Set<String> = []

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPhase) {
                Section("Kora phased execution") {
                    ForEach(KoraPhase.allCases) { phase in
                        Text(phase.title)
                            .tag(phase)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 280)
            .toolbar {
                ToolbarItem {
                    Button("Reset completions") {
                        completedMilestones.removeAll()
                    }
                }
            }
        } detail: {
            let milestones = selectedPhase.milestones

            VStack(alignment: .leading, spacing: 16) {
                Text(selectedPhase.title)
                    .font(.title)
                    .fontWeight(.semibold)

                Text(selectedPhase.goal)
                    .foregroundStyle(.secondary)

                ProgressView(
                    value: phaseProgress(milestones: milestones),
                    total: Double(max(milestones.count, 1))
                )
                .progressViewStyle(.linear)

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

                Text("Keep this checklist local to this workspace for now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
        }
    }

    private func phaseProgress(milestones: [KoraMilestone]) -> Double {
        guard !milestones.isEmpty else { return 0 }
        let done = milestones.filter { completedMilestones.contains($0.id) }.count
        return Double(done)
    }

    private func binding(for milestoneID: String) -> Binding<Bool> {
        Binding(
            get: { completedMilestones.contains(milestoneID) },
            set: { isDone in
                if isDone {
                    completedMilestones.insert(milestoneID)
                } else {
                    completedMilestones.remove(milestoneID)
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
