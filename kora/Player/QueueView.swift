import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        Group {
            if player.queueTracks.isEmpty {
                ContentUnavailableView("Queue is empty", systemImage: "list.bullet")
            } else {
                List {
                    Section("Now Playing") {
                        queueRow(player.queueTracks[player.queueIndex], index: player.queueIndex)
                    }
                    let upcoming = Array(player.queueTracks.dropFirst(player.queueIndex + 1))
                    if !upcoming.isEmpty {
                        Section("Up Next") {
                            ForEach(Array(upcoming.enumerated()), id: \.element.id) { offset, track in
                                queueRow(track, index: player.queueIndex + 1 + offset)
                            }
                            .onDelete(perform: player.removeUpcoming)
                        }
                    }
                }
            }
        }
        .navigationTitle("Up Next")
        .toolbar {
            Button("Clear", role: .destructive) { player.clearUpcoming() }
                .disabled(player.queueIndex + 1 >= player.queueTracks.count)
        }
    }

    private func queueRow(_ track: Track, index: Int) -> some View {
        HStack(spacing: 8) {
            if index == player.queueIndex {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(player.theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).lineLimit(1)
                    .foregroundStyle(index == player.queueIndex ? player.theme.accent : .primary)
                if let artist = track.artist, !artist.isEmpty {
                    Text(artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { player.jumpInQueue(to: index) }
    }
}

#Preview {
    QueueView().environmentObject(MusicPlayer())
}
