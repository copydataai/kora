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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
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
