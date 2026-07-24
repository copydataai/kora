import SwiftUI
import WidgetKit

struct KoraNowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> KoraNowPlayingEntry {
        KoraNowPlayingEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (KoraNowPlayingEntry) -> Void) {
        completion(KoraNowPlayingEntry(date: Date(), snapshot: NowPlayingStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KoraNowPlayingEntry>) -> Void) {
        let now = Date()
        let entry = KoraNowPlayingEntry(date: now, snapshot: NowPlayingStore.read())
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct KoraNowPlayingEntry: TimelineEntry {
    let date: Date
    let snapshot: NowPlayingSnapshot?
}

struct KoraNowPlayingEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KoraNowPlayingEntry

    var body: some View {
        ZStack {
            if let data = entry.snapshot?.artworkData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
                    .overlay(.black.opacity(0.48))
            }
            VStack(alignment: .leading, spacing: 6) {
            Text("Kora")
                .font(.headline)

            Spacer(minLength: 0)

            if let snap = entry.snapshot {
                Text(snap.isPlaying ? "▶" : "▐▐")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(snap.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if let artist = snap.artist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No track playing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            }
            .foregroundStyle(entry.snapshot?.artworkData == nil ? Color.primary : Color.white)
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .containerBackground(Color.secondary.opacity(0.12), for: .widget)
    }
}

struct KoraNowPlayingWidget: Widget {
    let kind = "kora-now-playing-widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KoraNowPlayingProvider()) { entry in
            KoraNowPlayingEntryView(entry: entry)
        }
        .configurationDisplayName("Kora Now Playing")
        .description("See the current track playing in Kora.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct KoraWidgetBundle: WidgetBundle {
    var body: some Widget {
        KoraNowPlayingWidget()
    }
}
