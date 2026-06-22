import Foundation

enum KoraRoomStatus: String, Codable, CaseIterable, Identifiable {
    case collecting
    case reviewing
    case blocked
    case readyToExport
    case exported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .collecting:
            "Collecting"
        case .reviewing:
            "Review"
        case .blocked:
            "Blocked"
        case .readyToExport:
            "Ready"
        case .exported:
            "Exported"
        }
    }
}

struct KoraRoomWidgetSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var roomName: String
    var ownerDisplayName: String
    var status: KoraRoomStatus
    var memberCount: Int
    var mediaCount: Int
    var qualityHardStops: Int
    var qualityWarnings: Int
    var nextActionHint: String
    var updatedAt: Date
}

struct KoraWidgetPayload: Codable, Hashable {
    var activeRoomID: UUID?
    var rooms: [KoraRoomWidgetSnapshot]
    var generatedAt: Date
}
