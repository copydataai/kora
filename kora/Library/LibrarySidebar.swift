import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LibrarySidebar: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var choosingFolder = false
    @State private var locating: MusicLibrary.Folder?
    @State private var renaming: MusicLibrary.Folder?
    @State private var draftName = ""

    var body: some View {
        Group {
            if library.folders.isEmpty {
                ContentUnavailableView("No folders yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a folder to start listening."))
            } else {
                folderList
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { choosingFolder = true } label: { Label("Add Folder", systemImage: "plus") }
                .padding(8)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { library.addFolder(url: url) }
        }
        .fileImporter(isPresented: Binding(get: { locating != nil },
                                           set: { if !$0 { locating = nil } }),
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result, let folder = locating {
                library.relink(folder, to: url)
            }
            locating = nil
        }
        .alert("Rename Folder", isPresented: Binding(get: { renaming != nil },
                                                     set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draftName)
            Button("Save") { if let f = renaming { library.rename(f, to: draftName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var folderList: some View {
        List {
            ForEach(library.folders) { folder in
                Section {
                    if folder.isAvailable {
                        ForEach(folder.tracks) { track in trackRow(track, in: folder) }
                    } else {
                        Button("Locate…") { locating = folder }
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
            Button("Locate…") { locating = folder }
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
