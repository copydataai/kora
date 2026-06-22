import Foundation

enum KoraRoomRole: String, Codable, CaseIterable, Identifiable {
    case owner
    case editor
    case reviewer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner:
            "Owner"
        case .editor:
            "Editor"
        case .reviewer:
            "Reviewer"
        }
    }

    var supportsInviteGeneration: Bool {
        self == .owner || self == .editor
    }
}

enum KoraPresenceState: String, Codable {
    case active
    case away
    case offline

    var title: String {
        switch self {
        case .active:
            "Active"
        case .away:
            "Away"
        case .offline:
            "Offline"
        }
    }
}

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

    var severityColor: String {
        switch self {
        case .collecting:
            "blue"
        case .reviewing:
            "yellow"
        case .blocked:
            "red"
        case .readyToExport:
            "green"
        case .exported:
            "secondary"
        }
    }
}

enum KoraFormatSupportTier: String, Codable {
    case native
    case transcoded
    case fallback
    case unsupported

    var title: String {
        switch self {
        case .native:
            "Native"
        case .transcoded:
            "Transcoded"
        case .fallback:
            "Fallback"
        case .unsupported:
            "Unsupported"
        }
    }
}

struct KoraRoomAsset: Identifiable, Codable, Hashable {
    var id = UUID()
    var fileName: String
    var codec: String
    var supportTier: KoraFormatSupportTier = .native
    var sampleRate: Int?
    var durationSeconds: Int?
    var addedAt = Date()
}

struct KoraRoomComment: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var authorName: String
    var createdAt = Date()
}

struct KoraParticipant: Identifiable, Codable, Hashable {
    var id = UUID()
    var displayName: String
    var role: KoraRoomRole
    var presenceState: KoraPresenceState = .active
    var joinedAt = Date()
    var lastSeenAt = Date()
}

struct KoraInvite: Identifiable, Codable, Hashable {
    var id: String { code }
    var code: String
    var roomID: UUID
    var role: KoraRoomRole
    var issuedByName: String
    var issuedAt: Date
    var expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }

    var remainingMinutes: Int {
        let seconds = max(0, Int(expiresAt.timeIntervalSinceNow))
        return Int(ceil(Double(seconds) / 60))
    }
}

struct KoraRoom: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var ownerDisplayName: String
    var purpose: String
    var status: KoraRoomStatus = .collecting
    var createdAt = Date()
    var updatedAt = Date()
    var nextActionHint: String = "Import an audio file and open for review."
    var participants: [KoraParticipant] = []
    var mediaAssets: [KoraRoomAsset] = []
    var comments: [KoraRoomComment] = []
}
