import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = MusicPlayer()
    @State private var isChoosingFile = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(alignment: .center, spacing: 34) {
                titleBlock
                playback
                metadata
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 42)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 440)
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                player.load(url: url)
            case .failure:
                player.reportFileSelectionFailure()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Kora")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(player.isPlaying ? "Playing" : player.hasTrack ? "Ready" : "No track")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                isChoosingFile = true
            } label: {
                Text(player.hasTrack ? "Change Track" : "Choose Track")
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var titleBlock: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(player.hasTrack ? player.currentTrackName : "Review audio locally.")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
                .foregroundStyle(.primary)

            Text(player.hasTrack ? "Use the timeline and transport controls below." : "Choose one audio file to begin.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var playback: some View {
        VStack(alignment: .center, spacing: 18) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .disabled(player.duration == 0)

            HStack {
                Text(timeString(player.currentTime))
                Spacer()
                Text(timeString(player.duration))
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    player.playPause()
                } label: {
                    Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PrimaryProductButtonStyle())
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!player.hasTrack)

                Button {
                    player.stop()
                } label: {
                    Text("Stop")
                }
                .buttonStyle(QuietButtonStyle())
                .disabled(!player.hasTrack)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let errorMessage = player.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            Text(player.hasTrack ? "Local audio" : "Audio")
            Text("/")
            Text(player.hasTrack ? timeString(player.duration) : "0:00")
            Text("/")
            Text(player.isPlaying ? "Playing" : player.hasTrack ? "Ready" : "Idle")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = max(Int(value), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PrimaryProductButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isEnabled ? (colorScheme == .dark ? .black : .white) : .secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isEnabled ? Color.primary : Color.secondary.opacity(0.25))
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(configuration.isPressed ? 0.62 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
