import SwiftUI

private enum WorkspaceSurface: String, CaseIterable, Identifiable {
    case rooms = "Room MVP"
    case execution = "Execution Loop"

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var navigationState: KoraNavigationState
    @State private var surface = WorkspaceSurface.rooms

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(WorkspaceSurface.allCases) { item in
                    Button(item.rawValue) {
                        surface = item
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(surface == item ? Color.accentColor.opacity(0.15) : Color.clear)
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
        .onChange(of: navigationState.route) { _ in
            surface = .rooms
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(KoraNavigationState())
}
