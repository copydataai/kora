import SwiftUI
import UniformTypeIdentifiers

struct LibrarySidebar: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var choosingFolder = false

    var body: some View {
        List {
            ForEach(library.folders) { folder in
                Section(folder.name) {
                    ForEach(folder.tracks) { track in
                        Button(track.title) { player.play(track: track, in: folder.tracks) }
                            .buttonStyle(.plain)
                    }
                }
                .contextMenu { Button("Forget Folder") { library.forget(folder) } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { choosingFolder = true } label: {
                Label("Add Folder", systemImage: "plus")
            }
            .padding(8)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { library.addFolder(url: url) }
        }
    }
}

#Preview {
    LibrarySidebar()
        .environmentObject(MusicLibrary())
        .environmentObject(MusicPlayer())
}
