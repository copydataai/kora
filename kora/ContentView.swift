import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        NavigationSplitView {
            LibrarySidebar().navigationTitle("Kora")
        } detail: {
            NowPlayingView()
        }
        .frame(minWidth: 760, minHeight: 520)
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
                        // ponytail: dropped loose file plays as a one-off; not added to the library, so the synthetic folderID is never used for lookup.
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
