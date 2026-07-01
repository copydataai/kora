import SwiftUI
import AppKit

struct LibrarySidebar: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var renaming: MusicLibrary.Folder?
    @State private var draftName = ""
    @State private var searchText = ""

    var body: some View {
        Group {
            if !searchText.isEmpty {
                searchResultsList
            } else if library.folders.isEmpty {
                ContentUnavailableView("No folders yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a folder to start listening."))
            } else {
                folderList
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search tracks")
        .safeAreaInset(edge: .bottom) {
            Button {
                if let url = pickFolder() { library.addFolder(url: url) }
            } label: { Label("Add Folder", systemImage: "plus") }
                .padding(8)
        }
        .alert("Rename Folder", isPresented: Binding(get: { renaming != nil },
                                                     set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draftName)
            Button("Save") { if let f = renaming { library.rename(f, to: draftName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    /// Native folder chooser. Reliable on macOS and avoids SwiftUI's
    /// multiple-`.fileImporter`-per-view conflict that silently swallowed
    /// the "Add Folder" button. Synchronous modal is standard for a picker.
    private func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private var folderList: some View {
        List {
            ForEach(library.folders) { folder in
                Section {
                    if folder.isAvailable {
                        ForEach(folder.tracks) { track in trackRow(track, in: folder) }
                    } else {
                        Button("Locate…") {
                            if let url = pickFolder() { library.relink(folder, to: url) }
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text(folder.name).foregroundStyle(folder.isAvailable ? .primary : .secondary)
                        Spacer()
                        if folder.isAvailable {
                            Text("\(folder.tracks.count)").foregroundStyle(.secondary).font(.caption)
                        } else {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                        }
                    }
                }
                .contextMenu { folderMenu(folder) }
            }
            .onMove { library.moveFolders(fromOffsets: $0, toOffset: $1) }
        }
    }

    /// Flat cross-folder results; each row plays within its folder's queue,
    /// exactly like clicking the track in the folder tree.
    private var searchResultsList: some View {
        let results = library.folders.filter(\.isAvailable).flatMap { folder in
            folder.tracks.filter { MusicLibrary.matches($0, query: searchText) }
                .map { (track: $0, folder: folder) }
        }
        return List {
            if results.isEmpty {
                Text("No matches").foregroundStyle(.secondary)
            } else {
                ForEach(results, id: \.track.id) { result in
                    trackRow(result.track, in: result.folder)
                }
            }
        }
    }

    private func trackRow(_ track: Track, in folder: MusicLibrary.Folder) -> some View {
        let isPlaying = player.currentTrackID == track.id
        return Button {
            player.play(track: track, in: folder.tracks)
        } label: {
            HStack(spacing: 8) {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(player.theme.accent)
                }
                Text(track.title).foregroundStyle(isPlaying ? player.theme.accent : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([track.url])
            }
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: MusicLibrary.Folder) -> some View {
        if folder.isAvailable {
            Button("Rescan") { library.rescan(folder) }
            Button("Reveal in Finder") {
                if let url = folder.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        } else {
            Button("Locate…") {
                if let url = pickFolder() { library.relink(folder, to: url) }
            }
        }
        Button("Rename…") { renaming = folder; draftName = folder.name }
        Button("Forget Folder", role: .destructive) { library.forget(folder) }
    }
}

#Preview {
    LibrarySidebar()
        .environmentObject(MusicLibrary())
        .environmentObject(MusicPlayer())
}
