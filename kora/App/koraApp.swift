import SwiftUI

@main
struct koraApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .task {
                    library.restore()
                    player.onTrackChange = { track, playing in NowPlayingState.write(track: track, isPlaying: playing) }
                    player.restoreSession(matching: library.folders.flatMap(\.tracks))
                }
        }
        .commands {
            CommandMenu("Playback") {
                Button(player.isPlaying ? "Pause" : "Play") { player.playPause() }
                Button("Next") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Divider()
                Button(player.isShuffled ? "Shuffle Off" : "Shuffle On") { player.toggleShuffle() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                Picker("Repeat", selection: $player.repeatMode) {
                    Text("Off").tag(RepeatMode.off)
                    Text("All").tag(RepeatMode.all)
                    Text("One").tag(RepeatMode.one)
                }
            }
        }

        MenuBarExtra("Kora", systemImage: "music.note") {
            VStack(alignment: .leading, spacing: 10) {
                if player.hasTrack {
                    HStack(spacing: 10) {
                        if let data = player.artwork, let image = NSImage(data: data) {
                            Image(nsImage: image).resizable().frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading) {
                            Text(player.currentTrackName).font(.headline).lineLimit(1)
                            if let artist = player.artist, !artist.isEmpty {
                                Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                } else {
                    Text("Nothing playing").foregroundStyle(.secondary)
                }
                HStack(spacing: 20) {
                    Button { player.previous() } label: { Image(systemName: "backward.fill") }
                    Button { player.playPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button { player.next() } label: { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .disabled(!player.hasTrack)
                MenuBarWindowControls()
            }
            .padding(12)
            .frame(width: 260)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Lives inside the MenuBarExtra so it can reach the openWindow action;
/// the App struct itself has no environment.
private struct MenuBarWindowControls: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Divider()
        HStack {
            Button("Open Kora") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.link)
    }
}
