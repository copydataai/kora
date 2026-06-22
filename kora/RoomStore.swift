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

    func currentWidgetPayload() -> KoraWidgetPayload {
        buildWidgetPayload()
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
        rooms[roomIndex].qualityIssues = []
        rooms[roomIndex].qualityCanExport = false
        rooms[roomIndex].qualityLastCheckedAt = nil

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

    func runQualityChecks(for roomID: UUID) -> Bool {
        guard let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) else {
            lastError = "Room not found."
            return false
        }

        let issues = evaluateQuality(for: rooms[roomIndex])
        rooms[roomIndex].qualityIssues = issues
        rooms[roomIndex].qualityLastCheckedAt = Date()
        rooms[roomIndex].qualityCanExport = issues.allSatisfy { $0.severity != .hardStop }
        rooms[roomIndex].updatedAt = Date()

        if issues.isEmpty {
            rooms[roomIndex].status = .readyToExport
            rooms[roomIndex].nextActionHint = "Quality checks passed. Export when ready."
        } else if rooms[roomIndex].qualityCanExport {
            rooms[roomIndex].status = .readyToExport
            rooms[roomIndex].nextActionHint = "Warnings only. You can export, but review the risks."
        } else {
            rooms[roomIndex].status = .blocked
            rooms[roomIndex].nextActionHint = "Quality hard-stop detected. Resolve checks before export."
        }

        let blockerCount = issues.filter { $0.severity == .hardStop }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        if let actor = rooms[roomIndex].participants.first(where: { $0.role == .owner })?.displayName
            ?? rooms[roomIndex].participants.first?.displayName {
            rooms[roomIndex].comments.append(
                KoraRoomComment(
                    text: "Quality check complete: \(blockerCount) hard-stop, \(warningCount) warning.",
                    authorName: actor
                )
            )
        }
        persist()
        return rooms[roomIndex].qualityCanExport
    }

    func attemptExport(roomID: UUID) -> Bool {
        guard let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) else {
            lastError = "Room not found."
            return false
        }

        let canExport = runQualityChecks(for: rooms[roomIndex].id)
        guard canExport else {
            lastError = "Export blocked by quality hard-stops."
            return false
        }

        rooms[roomIndex].status = .exported
        rooms[roomIndex].nextActionHint = "Export completed. Start a new review session or export variant."
        let actor = rooms[roomIndex].participants.first(where: { $0.role == .owner })?.displayName
            ?? rooms[roomIndex].participants.first?.displayName
            ?? "system"
        rooms[roomIndex].comments.append(
            KoraRoomComment(
                text: "Export completed by \(actor).",
                authorName: actor
            )
        )
        rooms[roomIndex].updatedAt = Date()
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
            saveWidgetPayload(buildWidgetPayload())
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
        let qualitySignal = analyzeQualitySignal(from: fileURL)

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
            durationSeconds: durationSeconds,
            peakDb: qualitySignal?.peakDb,
            loudnessDb: qualitySignal?.loudnessDb,
            hasClipping: qualitySignal?.hasClipping,
            sourceURL: fileURL.absoluteString
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

    private func evaluateQuality(for room: KoraRoom) -> [KoraQualityIssue] {
        guard room.status != .collecting else {
            return [
                KoraQualityIssue(
                    severity: .hardStop,
                    code: "no_asset",
                    title: "No media imported",
                    message: "Import at least one audio file before export."
                )
            ]
        }

        if room.mediaAssets.isEmpty {
            return [
                KoraQualityIssue(
                    severity: .hardStop,
                    code: "no_asset",
                    title: "No media imported",
                    message: "Import at least one audio file before export."
                )
            ]
        }

        var issues: [KoraQualityIssue] = []
        for asset in room.mediaAssets {
            if asset.durationSeconds == nil || asset.durationSeconds! <= 0 {
                issues.append(
                    KoraQualityIssue(
                        severity: .hardStop,
                        code: "duration",
                        title: "Invalid duration",
                        message: "\(asset.fileName) has invalid or unavailable duration."
                    )
                )
            }

            if asset.supportTier == .fallback {
                issues.append(
                    KoraQualityIssue(
                        severity: .hardStop,
                        code: "fallback",
                        title: "Fallback codec",
                        message: "\(asset.fileName) requires fallback/transcode path not yet enabled."
                    )
                )
            }

            if let sampleRate = asset.sampleRate, sampleRate < 22050 {
                issues.append(
                    KoraQualityIssue(
                        severity: .hardStop,
                        code: "sample_rate_low",
                        title: "Low sample rate",
                        message: "\(asset.fileName) is below 22.05kHz and may export poorly."
                    )
                )
            } else if asset.sampleRate == nil {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "sample_rate_missing",
                        title: "Sample rate missing",
                        message: "\(asset.fileName) metadata missing sample rate."
                    )
                )
            }

            if let loudnessDb = asset.loudnessDb, loudnessDb < -32 {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "low_loudness",
                        title: "Low loudness",
                        message: "\(asset.fileName) is significantly quieter than typical session targets."
                    )
                )
            } else if asset.loudnessDb == nil {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "loudness_missing",
                        title: "Loudness estimate unavailable",
                        message: "Unable to estimate \(asset.fileName) loudness."
                    )
                )
            }

            if let hasClipping = asset.hasClipping, hasClipping {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "clipping",
                        title: "Possible clipping",
                        message: "\(asset.fileName) may clip. Consider gain control before export."
                    )
                )
            }

            if let peakDb = asset.peakDb, peakDb > -0.1 {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "peak",
                        title: "High peak",
                        message: "\(asset.fileName) peak is \(String(format: "%.1f", peakDb)) dB and may distort."
                    )
                )
            }
        }

        let supportedSampleRates = Set(room.mediaAssets.compactMap(\.sampleRate))
        if supportedSampleRates.count > 1 {
            issues.append(
                KoraQualityIssue(
                    severity: .warning,
                    code: "sample_rate_mismatch",
                    title: "Sample-rate mismatch",
                    message: "Session contains mixed sample rates. Normalize for consistent rendering."
                )
            )
        }

        let channelCounts = Set(room.mediaAssets.compactMap(\.channels))
        if channelCounts.count > 1 {
            issues.append(
                KoraQualityIssue(
                    severity: .warning,
                    code: "channel_mismatch",
                    title: "Channel mismatch",
                    message: "Assets have mixed channel layouts; export result may be inconsistent."
                )
            )
        } else if let channels = channelCounts.first, channels > 2 {
            issues.append(
                KoraQualityIssue(
                    severity: .warning,
                    code: "multichannel",
                    title: "Multichannel source",
                    message: "Source has \(channels) channels. Verify your render target supports this."
                )
            )
        }

        let loudnessRange = room.mediaAssets.compactMap(\.loudnessDb)
        if loudnessRange.count > 1 {
            let maxL = loudnessRange.max() ?? 0
            let minL = loudnessRange.min() ?? 0
            if maxL - minL > 5 {
                issues.append(
                    KoraQualityIssue(
                        severity: .warning,
                        code: "loudness_mismatch",
                        title: "Loudness consistency warning",
                        message: "Loudness varies by more than 5 dB across assets."
                    )
                )
            }
        }

        return issues
    }

    private func analyzeQualitySignal(
        from fileURL: URL
    ) -> (peakDb: Double, loudnessDb: Double, hasClipping: Bool)? {
        let asset = AVURLAsset(url: fileURL)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return nil
        }

        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsPackedKey: true
            ]
        )
        reader.add(output)
        reader.startReading()

        var maxAbs: Float = 0
        var sumSquares: Double = 0
        var totalSamples = 0
        let sampleLimit = 1_048_576

        while let sampleBuffer = output.copyNextSampleBuffer(), reader.status == .reading {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            var lengthAtOffset = 0
            var rawData: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: nil,
                dataPointerOut: &rawData
            )
            if status != kCMBlockBufferNoErr || rawData == nil { continue }

            let sampleCount = lengthAtOffset / 4
            for sampleOffset in 0..<sampleCount {
                let value = rawData!.advanced(by: sampleOffset * 4).assumingMemoryBound(to: Float.self).pointee
                let absValue = abs(value)
                maxAbs = max(maxAbs, absValue)
                sumSquares += Double(absValue * absValue)
                totalSamples += 1
                if totalSamples >= sampleLimit {
                    break
                }
            }

            CMSampleBufferInvalidate(sampleBuffer)
            if totalSamples >= sampleLimit { break }
        }

        if totalSamples == 0 {
            return nil
        }

        let meanSquare = sumSquares / Double(max(totalSamples, 1))
        let rms = sqrt(meanSquare)
        let peakDb = 20 * log10(Double(max(maxAbs, 0.0000001)))
        let loudnessDb = 20 * log10(max(rms, 0.0000000001))
        let hasClipping = maxAbs >= 0.985
        return (peakDb, loudnessDb, hasClipping)
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

    private func widgetFileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let base = appSupport?.appendingPathComponent("Kora") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("widget-state.json")
    }

    private func saveWidgetPayload(_ payload: KoraWidgetPayload) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(payload) {
            try? data.write(to: widgetFileURL(), options: .atomic)
        }
    }

    private func buildWidgetPayload() -> KoraWidgetPayload {
        let snapshots: [KoraRoomWidgetSnapshot] = sortedRooms.prefix(4).map { room in
            let hardStops = room.qualityIssues.filter { $0.severity == .hardStop }.count
            let warnings = room.qualityIssues.filter { $0.severity == .warning }.count
            return KoraRoomWidgetSnapshot(
                id: room.id,
                roomName: room.name,
                ownerDisplayName: room.ownerDisplayName,
                status: room.status,
                memberCount: room.participants.count,
                mediaCount: room.mediaAssets.count,
                qualityHardStops: hardStops,
                qualityWarnings: warnings,
                nextActionHint: room.nextActionHint,
                updatedAt: room.updatedAt
            )
        }
        return KoraWidgetPayload(
            activeRoomID: activeRoomID,
            rooms: snapshots,
            generatedAt: Date()
        )
    }

    private func loadFromFileFallback() -> RoomStoreState? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        return try? JSONDecoder().decode(RoomStoreState.self, from: data)
    }
}
