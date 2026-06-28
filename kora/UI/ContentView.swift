import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var showQueue = false

    var body: some View {
        NavigationSplitView {
            LibrarySidebar().navigationTitle("Kora")
        } detail: {
            NowPlayingView()
        }
        .frame(minWidth: 820, minHeight: 560)
        .inspector(isPresented: $showQueue) { QueueView() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { library.rescanAll() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Rescan all folders")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showQueue.toggle() } label: { Image(systemName: "list.bullet") }
                    .help("Up Next")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers); return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    if isDir.boolValue {
                        library.addFolder(url: url)
                    } else if MusicLibrary.audioExtensions.contains(url.pathExtension.lowercased()) {
                        let t = Track(url: url, folderID: UUID())
                        player.play(track: t, in: [t])
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MusicLibrary())
        .environmentObject(MusicPlayer())
}
