import SwiftUI

private enum WorkspaceSurface: String, CaseIterable, Identifiable {
    case rooms = "Room MVP"
    case execution = "Execution Loop"

    var id: String { rawValue }
}

struct ContentView: View {
    @State private var surface = WorkspaceSurface.rooms

    var body: some View {
        NavigationSplitView {
            List(WorkspaceSurface.allCases, selection: $surface) {
                ForEach(WorkspaceSurface.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 220)
        } detail: {
            switch surface {
            case .rooms:
                RoomWorkspaceView()
            case .execution:
                ExecutionTrackerView()
            }
        }
    }
}

#Preview {
    ContentView()
}
