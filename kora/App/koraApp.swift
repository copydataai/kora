import SwiftUI

@main
struct koraApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .task {
                    library.restore()
                    player.onTrackChange = { track, playing in NowPlayingState.write(track: track, isPlaying: playing) }
                }
        }
    }
}
