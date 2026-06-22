import SwiftUI
import WidgetKit

struct KoraRoomWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> KoraRoomWidgetEntry {
        KoraRoomWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (KoraRoomWidgetEntry) -> Void) {
        let payload = KoraWidgetSnapshotQuery.loadLatestPayload()
        completion(KoraRoomWidgetEntry.build(from: payload, date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KoraRoomWidgetEntry>) -> Void) {
        let now = Date()
        let payload = KoraWidgetSnapshotQuery.loadLatestPayload()
        let entry = KoraRoomWidgetEntry.build(from: payload, date: now)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now.addingTimeInterval(600)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct KoraRoomWidgetEntry: TimelineEntry {
    let date: Date
    let payload: KoraWidgetPayload?
    let isStale: Bool
    let loadError: String?

    static let placeholder: KoraRoomWidgetEntry = KoraRoomWidgetEntry(
        date: Date(),
        payload: nil,
        isStale: true,
        loadError: "No room state loaded yet."
    )

    static func build(from payload: KoraWidgetPayload?, date: Date) -> KoraRoomWidgetEntry {
        guard let payload else {
            return KoraRoomWidgetEntry(
                date: date,
                payload: nil,
                isStale: false,
                loadError: "No widget data yet. Open Kora to create or open a room."
            )
        }

        return KoraRoomWidgetEntry(
            date: date,
            payload: payload,
            isStale: KoraWidgetSnapshotQuery.isPayloadStale(payload, asOf: date),
            loadError: nil
        )
    }

    var activeRoom: KoraRoomWidgetSnapshot? {
        guard let payload else { return nil }
        if let activeID = payload.activeRoomID {
            return payload.rooms.first { $0.id == activeID } ?? payload.rooms.first
        }
        return payload.rooms.first
    }

    var orderedRooms: [KoraRoomWidgetSnapshot] {
        guard let payload else { return [] }
        return payload.rooms
    }

    var launchRoomID: String? {
        activeRoom?.id.uuidString
    }

    var launchURL: URL {
        let path = launchRoomID.map { "kora://room/\($0)" } ?? "kora://rooms"
        return URL(string: path) ?? URL(string: "kora://rooms")!
    }
}

struct KoraRoomWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KoraRoomWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let payload = entry.payload {
                if payload.rooms.isEmpty {
                    emptyState
                } else {
                    activeRoomCard
                    roomStrip()
                }
            } else {
                loadingState
            }

            Spacer(minLength: 0)

            footer
        }
        .widgetURL(entry.launchURL)
        .padding(12)
        .containerBackground(Color.secondary.opacity(0.12), for: .widget)
    }

    private var header: some View {
        HStack {
            Text("Kora")
                .font(.headline)
            Spacer()
            if entry.isStale {
                Text("stale")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.06))
                    .clipShape(Capsule())
            }
            if let payload = entry.payload {
                Text("\(payload.rooms.count) room\(payload.rooms.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.loadError ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("Open Kora once to write widget payload.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No active rooms yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Create a room and import local audio to begin.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activeRoomCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            guard let room = entry.activeRoom else {
                return AnyView(emptyState)
            }
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.roomName)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Owner: \(room.ownerDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        statusChip(room.status.title)
                        detailChip("\(room.memberCount) member\(room.memberCount == 1 ? "" : "s")")
                        detailChip("\(room.mediaCount) media")
                    }
                    if room.qualityHardStops > 0 {
                        statusChip("\(room.qualityHardStops) blocker\(room.qualityHardStops == 1 ? "" : "s")")
                    }
                    if room.qualityWarnings > 0 {
                        statusChip("\(room.qualityWarnings) warning\(room.qualityWarnings == 1 ? "" : "s")")
                    }
                    Text(room.nextActionHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let first = entry.payload {
                        Text("Updated \(KoraWidgetSnapshotQuery.formatAge(first.generatedAt, reference: entry.date)) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            )
        }
    }

    private func roomStrip() -> some View {
        if family == .systemSmall {
            return AnyView(EmptyView())
        }

        let others = entry.orderedRooms.filter { $0.id != entry.activeRoom?.id }
        if others.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Other rooms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(others.prefix(2)) { room in
                    HStack(spacing: 6) {
                        statusDot(room.status)
                        Text(room.roomName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(room.status.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }

    private var footer: some View {
        HStack {
            Text(entry.payload == nil ? "Install updates in app" : "Open room")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("•")
                .foregroundStyle(.secondary)
            Text("v1 widget")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white.opacity(0.7))
            .clipShape(Capsule())
    }

    private func detailChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.clear)
            .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }

    private func statusDot(_ status: KoraRoomStatus) -> some View {
        Circle()
            .fill(color(for: status))
            .frame(width: 6, height: 6)
    }

    private func color(for status: KoraRoomStatus) -> Color {
        switch status {
        case .collecting:
            return .blue
        case .reviewing:
            return .orange
        case .blocked:
            return .red
        case .readyToExport:
            return .green
        case .exported:
            return .gray
        }
    }
}

struct KoraRoomWidget: Widget {
    let kind = "kora-room-widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KoraRoomWidgetProvider()) { entry in
            KoraRoomWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kora Rooms")
        .description("Watch room blockers and resume from context.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct KoraWidgetBundle: WidgetBundle {
    var body: some Widget {
        KoraRoomWidget()
    }
}
