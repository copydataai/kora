import Foundation
import AVFoundation

@MainActor
final class RoomStore: ObservableObject {
    @Published private(set) var rooms: [KoraRoom] = []
    @Published private(set) var invites: [KoraInvite] = []
    @Published var activeRoomID: UUID?
    @Published var lastError: String?

    private let fileManager = FileManager.default
    private let storageKey = "kora.rooms.state"

    private struct RoomStoreState: Codable {
        let rooms: [KoraRoom]
        let invites: [KoraInvite]
        let activeRoomID: UUID?
    }

    init() {
        load()
    }

    var activeRoom: KoraRoom? {
        guard let activeRoomID else { return nil }
        return rooms.first(where: { $0.id == activeRoomID })
    }

    var sortedRooms: [KoraRoom] {
        rooms.sorted { $0.updatedAt > $1.updatedAt }
    }

    func room(by id: UUID?) -> KoraRoom? {
        guard let id else { return nil }
        return rooms.first(where: { $0.id == id })
    }

    func setActiveRoom(_ roomID: UUID?) {
        activeRoomID = roomID
        persist()
    }

    func createRoom(name: String, ownerName: String, purpose: String = "") -> KoraRoom {
        let owner = KoraParticipant(displayName: ownerName, role: .owner)
        let room = KoraRoom(
            name: name,
            ownerDisplayName: ownerName,
            purpose: purpose,
            status: .collecting,
            participants: [owner],
            nextActionHint: "Import an audio file and open for review."
        )
        rooms.append(room)
        activeRoomID = room.id
        persist()
        return room
    }

    func createInvite(for roomID: UUID, role: KoraRoomRole, issuedBy: String) -> KoraInvite? {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return nil }

        let room = rooms[index]
        guard room.participants.contains(where: { $0.role == .owner && $0.displayName == issuedBy }) else {
            lastError = "Only room owner can issue invites."
            return nil
        }

        cleanupExpiredInvites()
        let invite = KoraInvite(
            code: generateInviteCode(),
            roomID: roomID,
            role: role,
            issuedByName: issuedBy,
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        invites.append(invite)
        persist()
        return invite
    }

    func activeInvites(for roomID: UUID) -> [KoraInvite] {
        cleanupExpiredInvites()
        return invites
            .filter { $0.roomID == roomID && !$0.isExpired }
            .sorted(by: { $0.expiresAt > $1.expiresAt })
    }

    func joinRoom(code: String, participantName: String) -> KoraRoom? {
        cleanupExpiredInvites()
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = invites.firstIndex(where: { $0.code == normalized }) else {
            lastError = "Invite code not found."
            return nil
        }

        let invite = invites[index]
        if invite.isExpired {
            invites.remove(at: index)
            persist()
            lastError = "Invite code has expired."
            return nil
        }

        guard let roomIndex = rooms.firstIndex(where: { $0.id == invite.roomID }) else {
            lastError = "Room no longer exists."
            return nil
        }

        let trimmedName = participantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastError = "Participant name is required."
            return nil
        }

        if let participantIndex = rooms[roomIndex].participants.firstIndex(where: {
            $0.displayName.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            rooms[roomIndex].participants[participantIndex].role = invite.role
            rooms[roomIndex].participants[participantIndex].lastSeenAt = Date()
            rooms[roomIndex].participants[participantIndex].presenceState = .active
        } else {
            let newParticipant = KoraParticipant(displayName: trimmedName, role: invite.role)
            rooms[roomIndex].participants.append(newParticipant)
        }

        rooms[roomIndex].comments.append(
            KoraRoomComment(
                text: "\(trimmedName) joined as \(invite.role.title)",
                authorName: "system"
            )
        )
        rooms[roomIndex].updatedAt = Date()
        invites.remove(at: index)
        activeRoomID = rooms[roomIndex].id
        persist()
        return rooms[roomIndex]
    }

    func setStatus(_ roomID: UUID, status: KoraRoomStatus) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].status = status
        rooms[index].updatedAt = Date()
        persist()
    }

    func setNextActionHint(_ roomID: UUID, hint: String) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].nextActionHint = hint
        rooms[index].updatedAt = Date()
        persist()
    }

    func importAudio(fileURL: URL, into roomID: UUID) -> Bool {
        guard let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) else {
            lastError = "Room not found."
            return false
        }

        guard let asset = buildAudioAsset(from: fileURL) else {
            return false
        }

        rooms[roomIndex].mediaAssets.append(asset)
        let actorName = rooms[roomIndex].participants.first(where: { $0.role == .owner })?.displayName
            ?? rooms[roomIndex].participants.first?.displayName
            ?? "system"

        rooms[roomIndex].comments.append(
            KoraRoomComment(
                text: "Imported \(asset.fileName)",
                authorName: actorName
            )
        )
        if rooms[roomIndex].status == .collecting {
            rooms[roomIndex].status = .reviewing
        }
        rooms[roomIndex].nextActionHint = "Validate metadata and invite a reviewer before export."
        rooms[roomIndex].updatedAt = Date()
        if asset.supportTier == .fallback {
            rooms[roomIndex].status = .blocked
            rooms[roomIndex].comments.append(
                KoraRoomComment(
                    text: "Asset format is \(asset.supportTier.title). Export blocked until transcode path is set.",
                    authorName: "system"
                )
            )
        }
        lastError = nil
        persist()
        return true
    }

    func clearAll() {
        rooms = []
        invites = []
        activeRoomID = nil
        lastError = nil
        persist()
    }

    private func load() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let restored = try? JSONDecoder().decode(RoomStoreState.self, from: savedData) {
            rooms = restored.rooms
            invites = restored.invites
            activeRoomID = restored.activeRoomID
            cleanupExpiredInvites()
            return
        }

        if let restored = loadFromFileFallback() {
            rooms = restored.rooms
            invites = restored.invites
            activeRoomID = restored.activeRoomID
            cleanupExpiredInvites()
            persist()
        }
    }

    private func persist() {
        let state = RoomStoreState(rooms: rooms, invites: invites, activeRoomID: activeRoomID)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
            saveToFile(data)
        }
    }

    private func cleanupExpiredInvites() {
        invites.removeAll(where: { $0.isExpired })
    }

    private func buildAudioAsset(from fileURL: URL) -> KoraRoomAsset? {
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileURL.isFileURL else {
            lastError = "Only local files are supported."
            return nil
        }

        let asset = AVURLAsset(url: fileURL)
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard let track = audioTracks.first else {
            lastError = "Selected file is not a recognized audio file."
            return nil
        }

        let extensionHint = fileURL.pathExtension.lowercased()
        let mediaType = extensionHint.isEmpty ? "audio" : extensionHint
        let tier = supportTier(for: mediaType)
        if tier == .unsupported {
            lastError = "Unsupported audio format for MVP import."
            return nil
        }

        var fileSize: Int64?
        if let fileSizeValue = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            fileSize = Int64(fileSizeValue)
        }

        let sampleRate = trackAudioSampleRate(track)
        let channels = trackChannelCount(track)

        let codec = resolvedAudioCodec(from: track.formatDescriptions)
        let durationSeconds = Int(CMTimeGetSeconds(asset.duration).rounded())

        if durationSeconds < 0 || (asset.duration.seconds).isInfinite || asset.duration.seconds.isNaN {
            lastError = "Unable to read audio duration."
            return nil
        }

        if durationSeconds <= 0 {
            lastError = "Duration unavailable; please verify file integrity."
            return nil
        }

        return KoraRoomAsset(
            fileName: fileURL.lastPathComponent,
            codec: codec,
            fileType: mediaType,
            supportTier: tier,
            sampleRate: sampleRate,
            channels: channels,
            fileSizeBytes: fileSize,
            durationSeconds: durationSeconds
        )
    }

    private func supportTier(for fileType: String) -> KoraFormatSupportTier {
        let nativeCodecs: Set<String> = [
            "wav", "aiff", "aif", "flac", "alac", "mp3", "aac", "m4a", "ogg", "opus", "caf", "aifc"
        ]
        let fallbackCodecs: Set<String> = ["dts", "wma", "amr", "adpcm", "hev1", "he-aac", "avc"]
        if nativeCodecs.contains(fileType) { return .native }
        if fallbackCodecs.contains(fileType) { return .fallback }
        return .unsupported
    }

    private func resolvedAudioCodec(from descriptions: [Any]) -> String {
        guard let formatDescription = descriptions.first as? CMAudioFormatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return "audio"
        }
        let formatID = asbd.pointee.mFormatID
        return fourCCString(formatID)
    }

    private func trackAudioSampleRate(_ track: AVAssetTrack) -> Int? {
        guard let formatDescription = track.formatDescriptions.first as? CMAudioFormatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }
        let sampleRate = Int(asbd.pointee.mSampleRate)
        return sampleRate > 0 ? sampleRate : nil
    }

    private func trackChannelCount(_ track: AVAssetTrack) -> Int? {
        guard let formatDescription = track.formatDescriptions.first as? CMAudioFormatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }
        let channels = Int(asbd.pointee.mChannelsPerFrame)
        return channels > 0 ? channels : nil
    }

    private func fourCCString(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        return String(decoding: bytes, as: UTF8.self)
    }

    private func generateInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        while true {
            let code = (0..<8).map { _ in String(alphabet.randomElement() ?? "A") }.joined()
            if !invites.contains(where: { $0.code == code }) {
                return code
            }
        }
    }

    private func fileURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("Kora")
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("room-state.json")
    }

    private func saveToFile(_ data: Data) {
        try? data.write(to: fileURL(), options: .atomic)
    }

    private func loadFromFileFallback() -> RoomStoreState? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        return try? JSONDecoder().decode(RoomStoreState.self, from: data)
    }
}
