# Kora Daily-Driver v1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Kora usable as an only music player (resume, shuffle/repeat, search, windowless control, format fix) and ship v1.0 via a tag-triggered GitHub Actions release.

**Architecture:** All playback logic stays in `MusicPlayer` (@MainActor ObservableObject) + `PlayQueue` (pure struct); persistence goes through UserDefaults with small Codable blobs; decision logic is extracted into pure `nonisolated static` functions so it's unit-testable without AVPlayer. CD is a new GitHub Actions workflow on `v*` tags.

**Tech Stack:** Swift / SwiftUI / AVFoundation / Swift Testing (`@Test` + `#expect`), xcodebuild, GitHub Actions.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-01-daily-driver-design.md`.
- The Xcode project uses filesystem-synchronized groups (objectVersion 77): new `.swift` files under `kora/` and `koraTests/` join their targets automatically — do NOT edit `project.pbxproj`.
- Test command (run serially, never overlapping — a killed run wedges testmanagerd):
  `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
- Build check: `xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'`
- Micro commits: commit at the end of every task at minimum; split test/impl commits where marked.
- Never auto-play audio at app launch.
- Match existing style: 4-space indent, `// MARK:` sections, terse comments only where the code can't say it.

---

### Task 1: Drop undecodable formats (ogg/opus)

**Files:**
- Modify: `kora/Library/MusicLibrary.swift:186-188`
- Test: `koraTests/LibraryScanTests.swift`

**Interfaces:**
- Consumes: `MusicLibrary.audioExtensions`, `MusicLibrary.audioFiles(in:)` (existing).
- Produces: nothing new — `audioExtensions` no longer contains `"ogg"`/`"opus"`.

- [ ] **Step 1: Write the failing test**

Append to the `LibraryScanTests` struct in `koraTests/LibraryScanTests.swift`:

```swift
    @Test func skipsFormatsAVPlayerCannotDecode() {
        let root = tempDir()
        write("a.mp3", in: root)
        write("b.ogg", in: root)
        write("c.opus", in: root)

        // AVPlayer can't decode ogg/opus; scanning them in means silent play failures.
        #expect(MusicLibrary.audioFiles(in: root).map(\.lastPathComponent) == ["a.mp3"])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/LibraryScanTests`
Expected: FAIL — the list contains `b.ogg` and `c.opus`.

- [ ] **Step 3: Remove the extensions**

In `kora/Library/MusicLibrary.swift`, change:

```swift
    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "alac", "caf", "ogg", "opus"
    ]
```

to:

```swift
    // ogg/opus intentionally absent: AVPlayer can't decode them, so scanning
    // them in produced tracks that silently failed to play.
    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "alac", "caf"
    ]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add kora/Library/MusicLibrary.swift koraTests/LibraryScanTests.swift
git commit -m "fix: stop scanning ogg/opus files AVPlayer cannot play"
```

---

### Task 2: Menu-bar window control (survive the window)

**Files:**
- Modify: `kora/App/koraApp.swift`

**Interfaces:**
- Consumes: existing `MenuBarExtra` scene and `WindowGroup`.
- Produces: `WindowGroup(id: "main")` — later tasks don't depend on this.

No unit test — pure scene wiring; verified by build + manual run.

- [ ] **Step 1: Give the window an id and add menu-bar controls**

In `kora/App/koraApp.swift`, change `WindowGroup {` to:

```swift
        WindowGroup(id: "main") {
```

Add this helper struct at the bottom of the file (outside `koraApp`):

```swift
/// Lives inside the MenuBarExtra so it can reach the openWindow action;
/// the App struct itself has no environment.
private struct MenuBarWindowControls: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Divider()
        HStack {
            Button("Open Kora") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.link)
    }
}
```

`NSApplication` needs AppKit; SwiftUI re-exports it on macOS, so no new import.

In the `MenuBarExtra` content, after the transport `HStack { ... } .disabled(!player.hasTrack)` block, add:

```swift
                MenuBarWindowControls()
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verify**

Run the app, play a track, close the window: audio must keep playing. From the menu-bar extra: "Open Kora" reopens the window, "Quit" exits. Report the result honestly — if playback stops on window close, stop and investigate before continuing.

- [ ] **Step 4: Commit**

```bash
git add kora/App/koraApp.swift
git commit -m "feat: reopen window and quit from the menu-bar player"
```

---

### Task 3: Shuffle support in PlayQueue

**Files:**
- Modify: `kora/Player/PlayQueue.swift`
- Test: `koraTests/PlayQueueTests.swift`

**Interfaces:**
- Consumes: existing `PlayQueue` (`tracks`, `index`, `current`, `jump(to:)`).
- Produces: `var isShuffled: Bool { get }` and `mutating func setShuffled(_ on: Bool)` — Task 4 calls these from `MusicPlayer`.

- [ ] **Step 1: Write the failing tests**

Append to `PlayQueueTests` in `koraTests/PlayQueueTests.swift`:

```swift
    @Test @MainActor func shuffleKeepsCurrentFirstAndPreservesTrackSet() {
        let a = track("a"), b = track("b"), c = track("c"), d = track("d")
        var q = PlayQueue(tracks: [a, b, c, d], startAt: 2)   // current = c
        q.setShuffled(true)
        #expect(q.isShuffled)
        #expect(q.current?.title == "c")                       // playback never jumps
        #expect(q.index == 0)                                  // current leads the shuffled order
        #expect(Set(q.tracks.map(\.title)) == ["a", "b", "c", "d"])
    }

    @Test @MainActor func unshuffleRestoresOriginalOrderAndCurrentTrack() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 1)       // current = b
        q.setShuffled(true)
        q.setShuffled(false)
        #expect(!q.isShuffled)
        #expect(q.tracks.map(\.title) == ["a", "b", "c"])
        #expect(q.current?.title == "b")
    }

    @Test @MainActor func shuffleOnEmptyOrRedundantCallsIsSafe() {
        var empty = PlayQueue(tracks: [], startAt: 0)
        empty.setShuffled(true)
        #expect(empty.current == nil)

        var q = PlayQueue(tracks: [track("a")], startAt: 0)
        q.setShuffled(false)                                   // no-op: already off
        #expect(q.tracks.count == 1)                           // must not clobber tracks
        q.setShuffled(true)
        q.setShuffled(true)                                    // no-op: already on
        #expect(q.tracks.count == 1)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/PlayQueueTests`
Expected: FAIL to compile — `setShuffled`/`isShuffled` don't exist. That's the TDD failure signal for new API.

- [ ] **Step 3: Implement shuffle**

In `kora/Player/PlayQueue.swift`, add two stored properties after `index`:

```swift
    private(set) var isShuffled = false
    private var originalTracks: [Track] = []
```

Add after `move(fromOffsets:toOffset:)`:

```swift
    /// Shuffling moves the current track to the front so playback never jumps;
    /// un-shuffling restores the pre-shuffle order and re-finds the current track.
    mutating func setShuffled(_ on: Bool) {
        guard on != isShuffled else { return }
        isShuffled = on
        if on {
            originalTracks = tracks
            guard let current else { return }
            var rest = tracks
            rest.removeAll { $0.id == current.id }
            rest.shuffle()
            tracks = [current] + rest
            index = 0
        } else {
            let currentID = current?.id
            // Guard: a session restored mid-shuffle has no original order to return to.
            if !originalTracks.isEmpty { tracks = originalTracks }
            originalTracks = []
            index = tracks.firstIndex { $0.id == currentID } ?? 0
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add kora/Player/PlayQueue.swift koraTests/PlayQueueTests.swift
git commit -m "feat: PlayQueue shuffle that keeps the current track playing"
```

---

### Task 4: Repeat mode + shuffle/repeat UI

**Files:**
- Modify: `kora/Player/MusicPlayer.swift`
- Modify: `kora/Player/NowPlayingView.swift`
- Modify: `kora/App/koraApp.swift`
- Test: `koraTests/PlayQueueTests.swift` (finish-action tests live here with the other queue-decision tests)

**Interfaces:**
- Consumes: `PlayQueue.setShuffled(_:)`, `PlayQueue.isShuffled` (Task 3), `queue.jump(to: 0)` (existing).
- Produces:
  - `enum RepeatMode: String, CaseIterable { case off, all, one }` (top level in MusicPlayer.swift)
  - `MusicPlayer.repeatMode: RepeatMode` (`@Published var`, persisted)
  - `MusicPlayer.isShuffled: Bool` (`@Published private(set)`, persisted)
  - `MusicPlayer.toggleShuffle()`, `MusicPlayer.cycleRepeatMode()`
  - `MusicPlayer.finishAction(repeatMode:hasNext:) -> FinishAction` (pure, tested)
  - Task 5 reads `isShuffled` behavior notes; no new types consumed there.

- [ ] **Step 1: Write the failing tests for end-of-track decisions**

Append to `PlayQueueTests` in `koraTests/PlayQueueTests.swift`:

```swift
    // End-of-track policy: this is WHY repeat modes exist — one loops the track,
    // all loops the queue, off stops at the end. Encoded as a pure function so
    // it's testable without AVPlayer.
    @Test func finishActionHonorsRepeatMode() {
        #expect(MusicPlayer.finishAction(repeatMode: .one, hasNext: true) == .replay)
        #expect(MusicPlayer.finishAction(repeatMode: .one, hasNext: false) == .replay)
        #expect(MusicPlayer.finishAction(repeatMode: .all, hasNext: true) == .advance)
        #expect(MusicPlayer.finishAction(repeatMode: .all, hasNext: false) == .wrapToStart)
        #expect(MusicPlayer.finishAction(repeatMode: .off, hasNext: true) == .advance)
        #expect(MusicPlayer.finishAction(repeatMode: .off, hasNext: false) == .stop)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/PlayQueueTests`
Expected: FAIL to compile — `RepeatMode`, `FinishAction`, `finishAction` don't exist.

- [ ] **Step 3: Implement repeat + shuffle state in MusicPlayer**

In `kora/Player/MusicPlayer.swift`, add above the class:

```swift
enum RepeatMode: String, CaseIterable {
    case off, all, one
}
```

Add published state after the `volume` property:

```swift
    @Published var repeatMode: RepeatMode {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "player.repeatMode") }
    }
    @Published private(set) var isShuffled: Bool
```

In `init()`, before `configureRemoteCommands()`:

```swift
        let savedRepeat = UserDefaults.standard.string(forKey: "player.repeatMode")
        self.repeatMode = savedRepeat.flatMap(RepeatMode.init(rawValue:)) ?? .off
        self.isShuffled = UserDefaults.standard.bool(forKey: "player.shuffle")
```

Add the pure decision + public toggles after `moveInQueue(fromOffsets:toOffset:)`:

```swift
    enum FinishAction { case replay, advance, wrapToStart, stop }

    nonisolated static func finishAction(repeatMode: RepeatMode, hasNext: Bool) -> FinishAction {
        switch (repeatMode, hasNext) {
        case (.one, _): return .replay
        case (_, true): return .advance
        case (.all, false): return .wrapToStart
        default: return .stop
        }
    }

    func toggleShuffle() {
        isShuffled.toggle()
        UserDefaults.standard.set(isShuffled, forKey: "player.shuffle")
        queue.setShuffled(isShuffled)
        syncQueue()
    }

    func cycleRepeatMode() {
        let all = RepeatMode.allCases
        repeatMode = all[(all.firstIndex(of: repeatMode)! + 1) % all.count]
    }
```

Replace `handlePlaybackFinished()`:

```swift
    private func handlePlaybackFinished() {
        switch MusicPlayer.finishAction(repeatMode: repeatMode, hasNext: queue.hasNext) {
        case .replay:
            seek(to: 0)
            player?.play()
            isPlaying = true
            startTimer()
        case .advance:
            next()
        case .wrapToStart:
            queue.jump(to: 0)
            loadAndPlayCurrent()
        case .stop:
            stop()   // stop() already fires onTrackChange(false) + updateNowPlayingInfo()
        }
    }
```

In `play(track:in:)`, apply the persisted shuffle preference to the fresh queue:

```swift
    func play(track: Track, in tracks: [Track]) {
        let start = tracks.firstIndex(of: track) ?? 0
        queue = PlayQueue(tracks: tracks, startAt: start)
        if isShuffled { queue.setShuffled(true) }
        loadAndPlayCurrent()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 5: Commit the engine half**

```bash
git add kora/Player/MusicPlayer.swift koraTests/PlayQueueTests.swift
git commit -m "feat: repeat modes and shuffle state in MusicPlayer"
```

- [ ] **Step 6: Add transport UI + menu commands**

In `kora/Player/NowPlayingView.swift`, replace the `transport` computed property:

```swift
    private var transport: some View {
        HStack(spacing: 24) {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle").font(.body)
            }
            .foregroundStyle(player.isShuffled ? player.theme.accent : player.theme.textPrimary.opacity(0.5))
            .accessibilityLabel(player.isShuffled ? "Shuffle on" : "Shuffle off")
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous")
            Button { player.playPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.largeTitle)
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.next() } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next")
            Button { player.cycleRepeatMode() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat").font(.body)
            }
            .foregroundStyle(player.repeatMode == .off ? player.theme.textPrimary.opacity(0.5) : player.theme.accent)
            .accessibilityLabel("Repeat \(player.repeatMode.rawValue)")
        }
        .font(.title2)
        .foregroundStyle(player.theme.textPrimary)
        .buttonStyle(.plain)
        .disabled(!player.hasTrack)
    }
```

Note the shuffle/repeat buttons carry their own `.foregroundStyle`, which overrides the outer one — that's the on/off affordance.

In `kora/App/koraApp.swift`, extend the Playback menu (after the "Previous" button):

```swift
                Divider()
                Button(player.isShuffled ? "Shuffle Off" : "Shuffle On") { player.toggleShuffle() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                Picker("Repeat", selection: $player.repeatMode) {
                    Text("Off").tag(RepeatMode.off)
                    Text("All").tag(RepeatMode.all)
                    Text("One").tag(RepeatMode.one)
                }
```

`$player.repeatMode` requires `player` to be accessed as `@StateObject`'s projected value; it already is (`@StateObject private var player`), so `$player.repeatMode` works inside `commands` via the observed object binding. If the compiler rejects the binding in the commands context, use:

```swift
                Picker("Repeat", selection: Binding(get: { player.repeatMode },
                                                    set: { player.repeatMode = $0 })) {
                    Text("Off").tag(RepeatMode.off)
                    Text("All").tag(RepeatMode.all)
                    Text("One").tag(RepeatMode.one)
                }
```

- [ ] **Step 7: Build and manually verify**

Run: `xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED.

Run the app: shuffle button tints accent when on and reorders Up Next (current track stays); repeat cycles off → all → one with icon change; repeat-one replays the track at its end; repeat-all wraps from last to first; both survive relaunch.

- [ ] **Step 8: Commit the UI half**

```bash
git add kora/Player/NowPlayingView.swift kora/App/koraApp.swift
git commit -m "feat: shuffle and repeat controls in transport and Playback menu"
```

---

### Task 5: Resume playback session on launch

**Files:**
- Create: `kora/Player/PersistedSession.swift`
- Modify: `kora/Player/MusicPlayer.swift`
- Modify: `kora/App/koraApp.swift`
- Test: `koraTests/PersistedSessionTests.swift` (new)

**Interfaces:**
- Consumes: `PlayQueue`, `MusicPlayer.load(url:)`, `syncQueue()`, `refreshMetadata(for:)` (existing, private — new code lives inside MusicPlayer).
- Produces:
  - `struct PersistedSession: Codable, Equatable { var paths: [String]; var index: Int; var elapsed: TimeInterval }` with `encode() -> Data`, `static decode(Data) -> PersistedSession?`, `isRestorable(fileExists:) -> Bool`
  - `MusicPlayer.restoreSession(matching: [Track])` — called from `koraApp`.

- [ ] **Step 1: Write the failing tests**

Create `koraTests/PersistedSessionTests.swift`:

```swift
import Testing
import Foundation
@testable import kora

struct PersistedSessionTests {
    @Test func roundTripsThroughData() {
        let session = PersistedSession(paths: ["/m/a.mp3", "/m/b.mp3"], index: 1, elapsed: 42.5)
        #expect(PersistedSession.decode(session.encode()) == session)
    }

    @Test func decodeRejectsGarbage() {
        #expect(PersistedSession.decode(Data("not json".utf8)) == nil)
    }

    // Restoring a queue whose current file vanished (or whose index is stale)
    // would resurrect a broken player; skip restore instead.
    @Test func restorableOnlyWhenIndexValidAndCurrentFileExists() {
        let session = PersistedSession(paths: ["/m/a.mp3", "/m/b.mp3"], index: 1, elapsed: 0)
        #expect(session.isRestorable { _ in true })
        #expect(!session.isRestorable { _ in false })                       // file gone
        #expect(!PersistedSession(paths: ["/m/a.mp3"], index: 5, elapsed: 0)
            .isRestorable { _ in true })                                    // index out of bounds
        #expect(!PersistedSession(paths: [], index: 0, elapsed: 0)
            .isRestorable { _ in true })                                    // empty queue
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/PersistedSessionTests`
Expected: FAIL to compile — `PersistedSession` doesn't exist.

- [ ] **Step 3: Implement PersistedSession**

Create `kora/Player/PersistedSession.swift`:

```swift
import Foundation

/// Snapshot of the play queue for resume-on-launch. Paths, not Tracks:
/// track UUIDs are regenerated every scan, but file paths are stable.
struct PersistedSession: Codable, Equatable {
    var paths: [String]
    var index: Int
    var elapsed: TimeInterval

    func encode() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> PersistedSession? {
        try? JSONDecoder().decode(PersistedSession.self, from: data)
    }

    /// Restorable only if the saved index is in bounds and the current file still exists.
    func isRestorable(fileExists: (String) -> Bool) -> Bool {
        paths.indices.contains(index) && fileExists(paths[index])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 5: Commit the model half**

```bash
git add kora/Player/PersistedSession.swift koraTests/PersistedSessionTests.swift
git commit -m "feat: PersistedSession model for resume-on-launch"
```

- [ ] **Step 6: Wire session save/restore into MusicPlayer**

In `kora/Player/MusicPlayer.swift`, add private state after `durationTask`:

```swift
    private let sessionKey = "player.session.v1"
    private var lastSessionWrite: Date = .distantPast
```

Add after `moveInQueue(fromOffsets:toOffset:)` (next to the other queue API):

```swift
    /// Restore the last session, paused, at the saved position. Called after
    /// MusicLibrary.restore() so folder security scopes are already active.
    func restoreSession(matching libraryTracks: [Track]) {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = PersistedSession.decode(data),
              session.isRestorable(fileExists: { FileManager.default.fileExists(atPath: $0) })
        else { return }

        // Prefer the library's Track for a path (keeps folderID); fall back to a
        // bare Track for files that left the library but still exist on disk.
        var byPath: [String: Track] = [:]
        for track in libraryTracks where byPath[track.url.path] == nil {
            byPath[track.url.path] = track
        }
        let tracks = session.paths.map { path in
            byPath[path] ?? Track(url: URL(fileURLWithPath: path), folderID: UUID())
        }

        queue = PlayQueue(tracks: tracks, startAt: session.index)
        guard let track = queue.current else { return }
        syncQueue()
        load(url: track.url)
        currentTrackName = track.title
        artist = track.artist
        // Seek directly: seek(to:) clamps to `duration`, which is still 0 here.
        // AVPlayer queues the seek and applies it once the item is ready.
        player?.seek(to: CMTime(seconds: session.elapsed, preferredTimescale: 600))
        currentTime = session.elapsed
        updateNowPlayingInfo()
        onTrackChange?(track, false)   // stays paused — never auto-play at launch
        Task { await refreshMetadata(for: track) }
    }

    private func persistSession(force: Bool = false) {
        guard force || Date.now.timeIntervalSince(lastSessionWrite) > 5 else { return }
        lastSessionWrite = .now
        let session = PersistedSession(paths: queue.tracks.map(\.url.path),
                                       index: queue.index, elapsed: currentTime)
        UserDefaults.standard.set(session.encode(), forKey: sessionKey)
    }
```

Call it from the three write points:

1. End of `syncQueue()` (covers track changes, jumps, moves, shuffle):

```swift
    private func syncQueue() {
        queueTracks = queue.tracks
        queueIndex = queue.index
        currentTrackID = queue.current?.id
        persistSession(force: true)
    }
```

2. End of `playPause()` (position is exact when the user pauses), add before the closing brace:

```swift
        persistSession(force: true)
```

3. End of `syncProgress()`, after `if t.isFinite { currentTime = t }` (throttled to ~5s by `persistSession`):

```swift
        persistSession()
```

- [ ] **Step 7: Call restore at launch**

In `kora/App/koraApp.swift`, in the `.task` modifier after `library.restore()` and the `onTrackChange` assignment:

```swift
                    player.restoreSession(matching: library.folders.flatMap(\.tracks))
```

- [ ] **Step 8: Run all tests + build**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 9: Manual verify**

Play a track mid-folder, seek to ~1:00, quit (⌘Q), relaunch: same track shown paused near 1:00, Up Next shows the same queue, pressing play resumes. Also verify launch with no saved session still shows "Nothing playing".

Known limitation (by design, note only): a session saved while shuffled restores in shuffled order and can't un-shuffle back to the original order — the original order isn't persisted.

- [ ] **Step 10: Commit**

```bash
git add kora/Player/MusicPlayer.swift kora/App/koraApp.swift
git commit -m "feat: resume last queue, track, and position on launch (paused)"
```

---

### Task 6: Library search

**Files:**
- Modify: `kora/Library/MusicLibrary.swift` (pure filter function)
- Modify: `kora/Library/LibrarySidebar.swift` (searchable + results list)
- Test: `koraTests/LibraryScanTests.swift`

**Interfaces:**
- Consumes: `Track.title`, `Track.artist`, `MusicLibrary.Folder.tracks`, `trackRow(_:in:)` (existing private view helper).
- Produces: `MusicLibrary.matches(_ track: Track, query: String) -> Bool` (nonisolated static).

- [ ] **Step 1: Write the failing tests**

Append to `LibraryScanTests` in `koraTests/LibraryScanTests.swift`:

```swift
    // Search is filename/title search by design: tags aren't indexed at scan,
    // so `title` (filename-derived) is what the user can actually match on.
    @Test @MainActor func searchMatchesTitleAndArtistCaseInsensitively() {
        let t = Track(url: URL(fileURLWithPath: "/m/Blue Train.mp3"), folderID: UUID(),
                      artist: "John Coltrane")
        #expect(MusicLibrary.matches(t, query: "blue"))
        #expect(MusicLibrary.matches(t, query: "TRAIN"))
        #expect(MusicLibrary.matches(t, query: "coltrane"))
        #expect(!MusicLibrary.matches(t, query: "miles"))
    }

    @Test @MainActor func emptyOrWhitespaceQueryMatchesNothing() {
        let t = Track(url: URL(fileURLWithPath: "/m/a.mp3"), folderID: UUID())
        #expect(!MusicLibrary.matches(t, query: ""))
        #expect(!MusicLibrary.matches(t, query: "   "))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/LibraryScanTests`
Expected: FAIL to compile — `matches` doesn't exist.

- [ ] **Step 3: Implement the filter**

In `kora/Library/MusicLibrary.swift`, add to the existing `extension MusicLibrary` (after `audioFiles(in:)`):

```swift
    /// Filename/title + artist search. Tags aren't indexed at scan time, so
    /// this is filename search in practice — good enough until it isn't.
    nonisolated static func matches(_ track: Track, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return false }
        if track.title.localizedCaseInsensitiveContains(q) { return true }
        if let artist = track.artist, artist.localizedCaseInsensitiveContains(q) { return true }
        return false
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS (all).

- [ ] **Step 5: Commit the filter**

```bash
git add kora/Library/MusicLibrary.swift koraTests/LibraryScanTests.swift
git commit -m "feat: case-insensitive title/artist track filter"
```

- [ ] **Step 6: Wire search into the sidebar**

In `kora/Library/LibrarySidebar.swift`:

Add state next to `renaming`:

```swift
    @State private var searchText = ""
```

In `body`, replace the `Group { ... }` contents:

```swift
        Group {
            if !searchText.isEmpty {
                searchResultsList
            } else if library.folders.isEmpty {
                ContentUnavailableView("No folders yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a folder to start listening."))
            } else {
                folderList
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search tracks")
```

(keep the existing `.safeAreaInset` and `.alert` modifiers after `.searchable`).

Add the results view after `folderList`:

```swift
    /// Flat cross-folder results; each row plays within its folder's queue,
    /// exactly like clicking the track in the folder tree.
    private var searchResultsList: some View {
        let results = library.folders.filter(\.isAvailable).flatMap { folder in
            folder.tracks.filter { MusicLibrary.matches($0, query: searchText) }
                .map { (track: $0, folder: folder) }
        }
        return List {
            if results.isEmpty {
                Text("No matches").foregroundStyle(.secondary)
            } else {
                ForEach(results, id: \.track.id) { result in
                    trackRow(result.track, in: result.folder)
                }
            }
        }
    }
```

- [ ] **Step 7: Build and manually verify**

Run: `xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED.

Run the app: ⌘F focuses search; typing filters across folders; clicking a result starts playback and Up Next shows that track's folder; clearing the query restores the folder tree.

- [ ] **Step 8: Commit**

```bash
git add kora/Library/LibrarySidebar.swift
git commit -m "feat: sidebar track search across all folders"
```

---

### Task 7: Release CD — tag-triggered signed build

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `README.md` (Release section + features list)

**Interfaces:**
- Consumes: existing `ci.yml` conventions (macos-15, xcode-select, scheme `kora`).
- Produces: a GitHub Release with a notarized DMG on every `v*` tag.
- Required repo secrets (documented in README): `MACOS_CERTIFICATE` (base64 .p12 of a Developer ID Application cert), `MACOS_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Import Developer ID certificate
        env:
          MACOS_CERTIFICATE: ${{ secrets.MACOS_CERTIFICATE }}
          MACOS_CERTIFICATE_PASSWORD: ${{ secrets.MACOS_CERTIFICATE_PASSWORD }}
        run: |
          KEYCHAIN_PASSWORD="$(uuidgen)"
          echo "$MACOS_CERTIFICATE" | base64 --decode > certificate.p12
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security set-keychain-settings -lut 3600 build.keychain
          security import certificate.p12 -k build.keychain \
            -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "$KEYCHAIN_PASSWORD" build.keychain
          rm certificate.p12

      - name: Archive
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcodebuild archive \
            -project kora.xcodeproj \
            -scheme kora \
            -configuration Release \
            -destination 'generic/platform=macOS' \
            -archivePath build/kora.xcarchive \
            DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
            CODE_SIGN_STYLE=Automatic

      - name: Export signed app
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          cat > ExportOptions.plist <<EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key><string>developer-id</string>
            <key>teamID</key><string>${APPLE_TEAM_ID}</string>
          </dict>
          </plist>
          EOF
          xcodebuild -exportArchive \
            -archivePath build/kora.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath build/export

      - name: Notarize and staple
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
        run: |
          ditto -c -k --keepParent build/export/kora.app build/kora.zip
          xcrun notarytool submit build/kora.zip --wait \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_PASSWORD"
          xcrun stapler staple build/export/kora.app

      - name: Package DMG
        run: |
          mkdir -p build/dmg
          cp -R build/export/kora.app build/dmg/
          ln -s /Applications build/dmg/Applications
          hdiutil create -volname "Kora" -srcfolder build/dmg \
            -ov -format UDZO "build/Kora-${GITHUB_REF_NAME}.dmg"

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" \
            "build/Kora-${GITHUB_REF_NAME}.dmg" \
            --title "Kora $GITHUB_REF_NAME" \
            --generate-notes
```

- [ ] **Step 2: Validate the workflow syntax**

Run: `gh workflow list >/dev/null 2>&1 && echo gh-ok; ruby -ryaml -e 'YAML.load_file(".github/workflows/release.yml"); puts "yaml-ok"'`
Expected: `yaml-ok` (gh-ok if authenticated).

The full pipeline can only be proven by pushing a tag with the secrets configured — say so honestly in the final report rather than claiming it's verified.

- [ ] **Step 3: Update README**

In `README.md`:

1. Features list — update these bullets:
   - Change the play bullet to: `- Play/pause, previous/next, seek, volume, **shuffle & repeat**, and auto-advance through a folder.`
   - Add after the Up Next bullet: `- **Search** (⌘F) across every folder from the sidebar.`
   - Add: `- **Resumes where you left off**: last queue, track, and position restore (paused) on launch.`
   - Add: `- Close the window and the music keeps playing; reopen or quit from the menu bar.`

2. Add a `## Release` section before `## Project layout`:

```markdown
## Release

Tagging `vX.Y.Z` on `main` triggers `.github/workflows/release.yml`, which
archives, signs, notarizes, and staples the app, then attaches a DMG to a
GitHub Release:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Required repository secrets (Settings → Secrets → Actions):

- `MACOS_CERTIFICATE` — base64 of a Developer ID Application `.p12`
  (`base64 -i cert.p12 | pbcopy`)
- `MACOS_CERTIFICATE_PASSWORD` — the `.p12` password
- `APPLE_ID` — Apple ID email of the developer account
- `APPLE_TEAM_ID` — 10-character team ID
- `APPLE_APP_PASSWORD` — app-specific password (appleid.apple.com)
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml README.md
git commit -m "ci: tag-triggered release workflow (sign, notarize, DMG)"
```

---

### Task 8: Final verification sweep

**Files:**
- None new; fixes only if something fails.

- [ ] **Step 1: Full test suite**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests`
Expected: PASS. If testmanagerd wedges (hung run), reset it and rerun serially.

- [ ] **Step 2: Clean release-configuration build**

Run: `xcodebuild build -project kora.xcodeproj -scheme kora -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED (this is what the release workflow will compile).

- [ ] **Step 3: End-to-end manual pass**

One session: add folder → search a track → play it → shuffle on → repeat all → close window (audio continues) → reopen from menu bar → quit → relaunch → session restored paused. Report each check's actual result.

- [ ] **Step 4: Push**

```bash
git push origin main
```

Then watch CI: `gh run watch` (or `gh run list --limit 1`). Expected: CI green.

Tagging v1.0.0 is the user's call once they've added the icon and the five repo secrets — don't tag in this plan.
