import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        VStack(spacing: 28) {
            artwork
            VStack(spacing: 6) {
                Text(player.hasTrack ? player.currentTrackName : "Nothing playing")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2)
                if let artist = player.artist, !artist.isEmpty {
                    Text(artist).font(.title3).foregroundStyle(.secondary)
                }
            }
            seekBar
            transport
            volume
        }
        .padding(40)
        .frame(maxWidth: 560, maxHeight: .infinity)
    }

    private var artwork: some View {
        Group {
            if let data = player.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "music.note").font(.system(size: 56)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                   in: 0...max(player.duration, 1))
                .disabled(player.duration == 0)
            HStack {
                Text(timeString(player.currentTime)); Spacer(); Text(timeString(player.duration))
            }
            .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 20) {
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.playPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title)
            }
            .keyboardShortcut(.space, modifiers: [])
            Button { player.next() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain)
        .disabled(!player.hasTrack)
    }

    private var volume: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: $player.volume, in: 0...1)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .frame(maxWidth: 260)
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let s = max(Int(value), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(MusicPlayer())
}
