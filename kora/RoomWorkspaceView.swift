import SwiftUI

struct RoomWorkspaceView: View {
    @StateObject private var store = RoomStore()
    @State private var selectedRoomID: UUID?
    @State private var showCreateRoom = false
    @State private var showJoinRoom = false
    @State private var joinCode = ""
    @State private var joinName = ""
    @State private var createRoomName = ""
    @State private var createOwnerName = ""
    @State private var createPurpose = ""
    @State private var lastJoinResult: String?

    private var selectedRoom: KoraRoom? {
        store.room(by: selectedRoomID ?? store.activeRoomID)
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rooms")
                    .font(.headline)

                if store.rooms.isEmpty {
                    Text("No rooms yet. Create one to begin the multiplayer flow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                List(store.sortedRooms, selection: $selectedRoomID) { room in
                    roomRow(room)
                }
                .listStyle(.inset)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)

                VStack(alignment: .leading, spacing: 8) {
                    Button("Create room") {
                        showCreateRoom = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Join with invite code") {
                        joinCode = ""
                        joinName = ""
                        showJoinRoom = true
                    }
                    .buttonStyle(.bordered)

                    Button("Reset local data") {
                        store.clearAll()
                        selectedRoomID = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    if let lastJoinResult {
                        Text(lastJoinResult)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        } detail: {
            if let room = selectedRoom {
                RoomDetailView(room: room, store: store)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select a room to review or create a new room.")
                        .font(.headline)
                    Text("This surface is the multiplayer start point: room model + roles + invites.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showCreateRoom) {
            VStack(spacing: 16) {
                Text("Create a new room")
                    .font(.title2)
                    .fontWeight(.medium)

                TextField("Room name", text: $createRoomName)
                TextField("Your name", text: $createOwnerName)
                TextField("Purpose (optional)", text: $createPurpose, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)

                Button("Create room") {
                    let trimmedName = createRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedOwner = createOwnerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty, !trimmedOwner.isEmpty else {
                        store.lastError = "Room and owner names are required."
                        return
                    }
                    let room = store.createRoom(name: trimmedName, ownerName: trimmedOwner, purpose: createPurpose)
                    selectedRoomID = room.id
                    createRoomName = ""
                    createOwnerName = ""
                    createPurpose = ""
                    showCreateRoom = false
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel", role: .cancel) {
                    showCreateRoom = false
                }

                if let error = store.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
            .frame(minWidth: 360)
        }
        .sheet(isPresented: $showJoinRoom) {
            VStack(spacing: 16) {
                Text("Join room")
                    .font(.title2)
                    .fontWeight(.medium)

                TextField("Your display name", text: $joinName)
                TextField("Invite code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                HStack {
                    Button("Join") {
                        guard let room = store.joinRoom(code: joinCode, participantName: joinName) else {
                            return
                        }
                        selectedRoomID = room.id
                        lastJoinResult = "Joined room \(room.name)."
                        joinCode = ""
                        joinName = ""
                        showJoinRoom = false
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel", role: .cancel) {
                        showJoinRoom = false
                    }
                }

                if let error = store.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
            .frame(minWidth: 360)
        }
    }

    private func roomRow(_ room: KoraRoom) -> some View {
        VStack(alignment: .leading) {
            Text(room.name)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                Text(room.status.title)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("Owner: \(room.ownerDisplayName)")
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(room.participants.count) member(s)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

private struct RoomDetailView: View {
    let room: KoraRoom
    @ObservedObject var store: RoomStore
    @State private var generateRole: KoraRoomRole = .reviewer
    @State private var generatedInviteCode: String?
    @State private var nextActionDraft: String = ""
    @State private var showCopiedHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusPanel
            participantsPanel
            invitePanel
            assetPanel
            hintPanel
            Spacer()
        }
        .padding()
        .onAppear {
            nextActionDraft = room.nextActionHint
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(room.name)
                .font(.title2)
                .fontWeight(.semibold)

            if !room.purpose.isEmpty {
                Text(room.purpose)
                    .foregroundStyle(.secondary)
            }

            if let owner = room.participants.first(where: { $0.role == .owner }) {
                Text("Owner: \(owner.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workflow status")
                .font(.headline)

            Picker("Status", selection: Binding(
                get: { room.status },
                set: { store.setStatus(room.id, status: $0) }
            )) {
                ForEach(KoraRoomStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Next action hint: \(room.nextActionHint)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var participantsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Participants")
                .font(.headline)

            ForEach(room.participants) { participant in
                HStack {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(participant.role == .owner ? .blue : .green)
                    Text(participant.displayName)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(participant.role.title)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(participant.presenceState.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            if room.participants.isEmpty {
                Text("No participants yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var invitePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite")
                .font(.headline)

            Picker("Role", selection: $generateRole) {
                ForEach(KoraRoomRole.allCases) { role in
                    if role.supportsInviteGeneration {
                        Text(role.title).tag(role)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Button("Generate 1-hour invite code") {
                if let invite = store.createInvite(
                    for: room.id,
                    role: generateRole,
                    issuedBy: room.ownerDisplayName
                ) {
                    generatedInviteCode = invite.code
                }
            }
            .buttonStyle(.borderedProminent)

            if let generatedInviteCode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Invite code: \(generatedInviteCode)")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    Text("Invite expires in 60 minutes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(showCopiedHint ? "Copied" : "Copy code visually") {
                    showCopiedHint.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showCopiedHint = false
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            ForEach(store.activeInvites(for: room.id)) { invite in
                Text("Role \(invite.role.title) invite by \(invite.issuedByName), expires in \(invite.remainingMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var assetPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Media")
                .font(.headline)

            if room.mediaAssets.isEmpty {
                Text("No audio imported yet. (mvp-audio milestone in next step.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(room.mediaAssets) { asset in
                    HStack {
                        Text(asset.fileName)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(asset.codec)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(asset.supportTier.title)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var hintPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Self-service hint")
                .font(.headline)

            TextField("Set next action", text: $nextActionDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button("Save hint") {
                store.setNextActionHint(room.id, hint: nextActionDraft)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    RoomWorkspaceView()
}
