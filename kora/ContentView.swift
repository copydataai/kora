import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = MusicPlayer()
    @State private var isChoosingFile = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Kora")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))

                Text("A simple local music player.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Text(player.currentTrackName)
                    .font(.title3.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)

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
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack(spacing: 12) {
                Button("Choose Audio") {
                    isChoosingFile = true
                }

                Button(player.isPlaying ? "Pause" : "Play") {
                    player.playPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!player.hasTrack)

                Button("Stop") {
                    player.stop()
                }
                .disabled(!player.hasTrack)
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage = player.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(minWidth: 520, minHeight: 420)
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

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let seconds = max(Int(value), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    ContentView()
}
