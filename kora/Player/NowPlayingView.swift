import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        ZStack {
            backdrop
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.5), value: player.theme)
        .animation(.easeInOut(duration: 0.5), value: player.currentTrackID)
    }

    // MARK: Backdrop — the blurred album art itself + a legibility scrim.
    private var backdrop: some View {
        ZStack {
            if let data = player.theme.artwork, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 60)          // ponytail: SwiftUI .blur on full-res art; pre-blur a thumbnail with CIGaussianBlur only if janky
                    .opacity(0.55)
                    .transition(.opacity)
                    .id(player.currentTrackID) // cross-fade on track change
            } else {
                LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.1)],
                               startPoint: .top, endPoint: .bottom)
            }
            Rectangle().fill(.black.opacity(0.35))   // scrim for contrast
        }
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 28) {
            artworkCard
            VStack(spacing: 6) {
                Text(player.hasTrack ? player.currentTrackName : "Nothing playing")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2)
                if let artist = player.artist, !artist.isEmpty {
                    Text(artist).font(.title3).opacity(0.85)
                } else if !player.hasTrack {
                    Text("Add a folder, then pick a track").font(.callout).opacity(0.7)
                }
            }
            .foregroundStyle(player.theme.textPrimary)
            seekBar
            transport
            volume
            if let errorMessage = player.errorMessage {
                Text(errorMessage).font(.callout).multilineTextAlignment(.center)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(maxWidth: 560)
        .tint(player.theme.accent)
    }

    private var artworkCard: some View {
        Group {
            if let data = player.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.25)
                    Image(systemName: "music.note").font(.system(size: 56))
                        .foregroundStyle(player.theme.textPrimary.opacity(0.7))
                }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                   in: 0...max(player.duration, 1))
                .disabled(player.duration == 0)
            HStack {
                Text(timeString(player.currentTime)); Spacer(); Text(timeString(player.duration))
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(player.theme.textPrimary.opacity(0.8))
        }
    }

    private var transport: some View {
        HStack(spacing: 24) {
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous")
            Button { player.playPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.largeTitle)
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.next() } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next")
        }
        .font(.title2)
        .foregroundStyle(player.theme.textPrimary)
        .buttonStyle(.plain)
        .disabled(!player.hasTrack)
    }

    private var volume: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").accessibilityHidden(true)
            Slider(value: $player.volume, in: 0...1).accessibilityLabel("Volume")
            Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
        }
        .foregroundStyle(player.theme.textPrimary.opacity(0.7))
        .frame(maxWidth: 260)
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let s = max(Int(value), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NowPlayingView().environmentObject(MusicPlayer())
}
