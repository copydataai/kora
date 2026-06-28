import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        Group {
            if player.queueTracks.isEmpty {
                ContentUnavailableView("Queue is empty", systemImage: "list.bullet")
            } else {
                List {
                    ForEach(Array(player.queueTracks.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 8) {
                            if index == player.queueIndex {
                                Image(systemName: "speaker.wave.2.fill").foregroundStyle(player.theme.accent)
                            }
                            Text(track.title)
                                .foregroundStyle(index == player.queueIndex ? player.theme.accent : .primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.jumpInQueue(to: index) }
                    }
                    .onMove { player.moveInQueue(fromOffsets: $0, toOffset: $1) }
                }
            }
        }
        .navigationTitle("Up Next")
    }
}

#Preview {
    QueueView().environmentObject(MusicPlayer())
}
