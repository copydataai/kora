# Kora Playback Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three reported defects — the "Add Folder" button does nothing, long (>1hr) files stall ~3s before playing, and hardware/system media keys are ignored.

**Architecture:** (1) Replace SwiftUI's conflicting stacked `.fileImporter` modifiers with a native `NSOpenPanel`. (2) Swap the player engine from `AVAudioPlayer` (which scans the whole file on the main thread before playback) to `AVPlayer` (streams, starts near-instantly), moving finish-detection from a polling timer to AVPlayer's end-of-item notification. (3) Register `MPRemoteCommandCenter` handlers and publish `MPNowPlayingInfoCenter` so macOS routes media keys / Control Center / AirPods controls to the app.

**Tech Stack:** Swift, SwiftUI, AppKit (`NSOpenPanel`), AVFoundation (`AVPlayer`), MediaPlayer (`MPRemoteCommandCenter`, `MPNowPlayingInfoCenter`), Combine.

## Global Constraints

- Target platform: macOS app, sandboxed. Entitlements present: `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-only`, `com.apple.security.files.bookmarks.app-scope`. Do not add entitlements — `NSOpenPanel` and MediaPlayer need none of the above changed.
- `MusicPlayer` is `@MainActor` and an `ObservableObject` `@StateObject` owned by `koraApp`; it lives for the whole app session. Preserve its entire public surface — UI binds to it: `currentTrackName`, `currentTime`, `duration`, `isPlaying`, `errorMessage`, `artist`, `artwork`, `theme`, `currentTrackID`, `queueTracks`, `queueIndex`, `volume`, `hasTrack`, `onTrackChange`, and methods `load(url:)`, `playPause()`, `stop()`, `seek(to:)`, `reportFileSelectionFailure()`, `play(track:in:)`, `next()`, `previous()`, `jumpInQueue(to:)`, `moveInQueue(fromOffsets:toOffset:)`.
- Existing tests that MUST still pass: `PlayQueueTests`, `BookmarkStoreTests`, `LibraryScanTests`, `ArtworkThemeTests`. `PlayerFinishTests` is intentionally removed in Task 2 (see note there).
- Build: `xcodebuild -scheme kora -destination 'platform=macOS' build`
- Test: `xcodebuild -scheme kora -destination 'platform=macOS' -parallel-testing-enabled NO test` (serial per the project's known testmanagerd flake).
- Each task ends with a commit. Commit message footer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

> **Testing note (read once):** All three fixes are AppKit/AVFoundation/MediaPlayer *integration* code — file pickers, real audio playback, and OS media-key routing. None is meaningfully unit-testable without mocking entire system frameworks (over-engineering). So these tasks verify via **build + existing-test-suite green + a scripted manual run**, not new XCTest cases. This is deliberate; do not fabricate unit tests that only assert wiring. The one pure helper that *was* unit-tested (`shouldAdvanceOnFinish`) is being deleted because the engine swap obsoletes it; the behavior it guarded (advance-on-finish) is now covered structurally by `PlayQueueTests` (`hasNext`/`next`) plus the manual run.

---

### Task 1: Fix "Add Folder" (and "Locate…") with NSOpenPanel

**Root cause:** `LibrarySidebar.swift` attaches **two** `.fileImporter` modifiers to the same view (`$choosingFolder` for Add, and the `locating`-bound one for Locate). SwiftUI reliably drives only one file-importer per view; the first ("Add Folder") is silently swallowed. Drag-drop works only because it bypasses `.fileImporter` entirely (`ContentView.handleDrop` → `library.addFolder`).

**Fix:** Remove both `.fileImporter`s and the `choosingFolder`/`locating` state. Use a synchronous `NSOpenPanel` (native, no per-view-importer limit) for both Add and Locate. `library.addFolder(url:)` / `library.relink(_:to:)` are unchanged and already proven by the working drag-drop path.

**Files:**
- Modify: `kora/Library/LibrarySidebar.swift`

**Interfaces:**
- Consumes: `library.addFolder(url: URL)`, `library.relink(_ folder: MusicLibrary.Folder, to: URL)` (both already exist, unchanged).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Replace the imports, state, body modifiers, and Locate buttons**

Edit `kora/Library/LibrarySidebar.swift`.

Change the import block at the top — drop `UniformTypeIdentifiers` (only `.fileImporter`'s `[.folder]` used it):

```swift
import SwiftUI
import AppKit
```

Remove these two `@State` declarations (delete the lines entirely):

```swift
    @State private var choosingFolder = false
    @State private var locating: MusicLibrary.Folder?
```

Replace the whole `body` with this (drops both `.fileImporter` modifiers; wires the bottom button to `pickFolder()`):

```swift
    var body: some View {
        Group {
            if library.folders.isEmpty {
                ContentUnavailableView("No folders yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a folder to start listening."))
            } else {
                folderList
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if let url = pickFolder() { library.addFolder(url: url) }
            } label: { Label("Add Folder", systemImage: "plus") }
                .padding(8)
        }
        .alert("Rename Folder", isPresented: Binding(get: { renaming != nil },
                                                     set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draftName)
            Button("Save") { if let f = renaming { library.rename(f, to: draftName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    /// Native folder chooser. Reliable on macOS and avoids SwiftUI's
    /// multiple-`.fileImporter`-per-view conflict that silently swallowed
    /// the "Add Folder" button. Synchronous modal is standard for a picker.
    private func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        return panel.runModal() == .OK ? panel.url : nil
    }
```

In `folderList`, replace the section-body Locate button:

```swift
                        Button("Locate…") { locating = folder }
                            .foregroundStyle(.secondary)
```

with:

```swift
                        Button("Locate…") {
                            if let url = pickFolder() { library.relink(folder, to: url) }
                        }
                        .foregroundStyle(.secondary)
```

In `folderMenu`, replace the Locate button:

```swift
            Button("Locate…") { locating = folder }
```

with:

```swift
            Button("Locate…") {
                if let url = pickFolder() { library.relink(folder, to: url) }
            }
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' build`
Expected: `BUILD SUCCEEDED`. No "unused variable `locating`" or missing-symbol errors.

- [ ] **Step 3: Run the existing test suite (nothing should regress)**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' -parallel-testing-enabled NO test`
Expected: `TEST SUCCEEDED`. (No tests target this UI; this is a regression gate.)

- [ ] **Step 4: Manual verification**

Launch the app. Click **Add Folder** in the sidebar → the macOS folder chooser opens → pick a folder with audio → it appears as a section with its tracks. Previously this button did nothing. Drag-drop a folder from Finder still works.

- [ ] **Step 5: Commit**

```bash
git add kora/Library/LibrarySidebar.swift
git commit -m "fix: Add Folder button uses NSOpenPanel instead of conflicting fileImporters

Two stacked .fileImporter modifiers on one view made SwiftUI swallow the
Add Folder importer; only drag-drop worked. Replace both with a native
NSOpenPanel for Add and Locate.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Migrate MusicPlayer from AVAudioPlayer to AVPlayer (fix long-file stall)

**Root cause:** `MusicPlayer.load(url:)` calls `try AVAudioPlayer(contentsOf:)` + `prepareToPlay()` **synchronously on `@MainActor`**. For a 1+hr file (esp. VBR MP3) AVAudioPlayer scans the entire file to compute duration / build a seek table — ~3s — and because it's on the main thread the whole UI and keyboard freeze during it.

**Fix:** Use `AVPlayer`, which streams and begins playback near-instantly without a full-file scan. Load `duration` asynchronously (`asset.load(.duration)`) and publish it when ready (the seek bar already tolerates `duration == 0`). Surface load failures via `AVPlayerItem.status == .failed` (AVPlayer doesn't throw at init). Replace the polling-timer finish heuristic with the `AVPlayerItemDidPlayToEndTime` notification.

**Note — deleting `shouldAdvanceOnFinish` + `PlayerFinishTests`:** that static helper existed only because `AVAudioPlayer` had no good finish callback, so finish was inferred from `currentTime >= duration - 0.25` on a 0.25s timer. `AVPlayer` posts `AVPlayerItemDidPlayToEndTime` at the exact end, so the heuristic and its unit test become dead code and are removed. The advance-on-finish *behavior* is preserved (`handlePlaybackFinished()` → existing `next()`/`stop()`) and its queue logic stays covered by `PlayQueueTests`.

**Files:**
- Modify: `kora/Player/MusicPlayer.swift`
- Delete: `koraTests/PlayerFinishTests.swift`

**Interfaces:**
- Consumes: `PlayQueue` (`hasNext`, `current`, `next()`, `previous()`, `jump(to:)`, `move(...)`, `tracks`, `index`); `Track.loadMetadata()`, `Track.loadArtwork()`; `ArtworkPalette.theme(for:)`.
- Produces (used by Task 3): `updateNowPlayingInfo()` and `configureRemoteCommands()` are *declared in Task 3's file* but **called from this file** — this task adds the call sites (`configureRemoteCommands()` in `init`, `updateNowPlayingInfo()` at each state change). To keep this task building on its own, add a temporary no-op stub for both (see Step 1) and delete the stub in Task 3.

- [ ] **Step 1: Rewrite `MusicPlayer.swift`**

Replace the entire contents of `kora/Player/MusicPlayer.swift` with:

```swift
import AVFoundation
import Combine
import Foundation

@MainActor
final class MusicPlayer: ObservableObject {
    @Published private(set) var currentTrackName = "No track selected"
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var artist: String?
    @Published private(set) var artwork: Data?
    @Published private(set) var theme: ArtworkTheme = .neutral
    @Published private(set) var currentTrackID: UUID?
    @Published private(set) var queueTracks: [Track] = []
    @Published private(set) var queueIndex: Int = 0
    @Published var volume: Double {
        didSet {
            player?.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: "player.volume")
        }
    }

    var onTrackChange: ((Track?, Bool) -> Void)?

    private var player: AVPlayer?
    private var progressTimer: Timer?
    private var securityScopedURL: URL?
    private var queue = PlayQueue(tracks: [], startAt: 0)
    private var itemObservers: Set<AnyCancellable> = []
    private var durationTask: Task<Void, Never>?

    var hasTrack: Bool {
        player?.currentItem != nil
    }

    init() {
        let saved = UserDefaults.standard.object(forKey: "player.volume") as? Double
        self.volume = saved ?? 1.0
        configureRemoteCommands()   // defined in NowPlayingCenter.swift (Task 3)
    }

    func load(url: URL) {
        stopTimer()
        player?.pause()
        itemObservers.removeAll()
        durationTask?.cancel()
        releaseSecurityScopedURL()

        let didStartAccess = url.startAccessingSecurityScopedResource()
        if didStartAccess { securityScopedURL = url }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = Float(volume)

        player = avPlayer
        currentTrackName = url.deletingPathExtension().lastPathComponent
        currentTime = 0
        duration = 0
        isPlaying = false
        errorMessage = nil

        // AVPlayer doesn't throw at init; surface load failures via item status.
        item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self, self.player === avPlayer else { return }
                if status == .failed { self.errorMessage = "Could not load that audio file." }
            }
            .store(in: &itemObservers)

        // AVPlayer posts this at the exact end — replaces the old polling heuristic.
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.player === avPlayer else { return }
                self.handlePlaybackFinished()
            }
            .store(in: &itemObservers)

        // Duration loads asynchronously; publish it when known (the seek bar tolerates 0).
        durationTask = Task { [weak self] in
            let loaded = try? await asset.load(.duration)
            guard let self, !Task.isCancelled, self.player === avPlayer else { return }
            let seconds = loaded?.seconds ?? 0
            self.duration = seconds.isFinite ? seconds : 0
            self.updateNowPlayingInfo()
        }
    }

    func playPause() {
        guard let player else {
            errorMessage = "Choose an audio file first."
            return
        }
        if player.timeControlStatus == .paused {
            player.play()
            isPlaying = true
            errorMessage = nil
            startTimer()
        } else {
            player.pause()
            isPlaying = false
            stopTimer()
        }
        updateNowPlayingInfo()
        onTrackChange?(queue.current, isPlaying)
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        currentTime = 0
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
        onTrackChange?(queue.current, false)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func reportFileSelectionFailure() {
        errorMessage = "Could not choose an audio file."
    }

    func play(track: Track, in tracks: [Track]) {
        let start = tracks.firstIndex(of: track) ?? 0
        queue = PlayQueue(tracks: tracks, startAt: start)
        loadAndPlayCurrent()
    }

    func next() {
        guard queue.next() != nil else { return }
        loadAndPlayCurrent()
    }

    func previous() {
        guard queue.previous() != nil else { return }
        loadAndPlayCurrent()
    }

    func jumpInQueue(to index: Int) {
        queue.jump(to: index)
        loadAndPlayCurrent()   // updates the published queue via syncQueue()
    }

    func moveInQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        syncQueue()
    }

    private func syncQueue() {
        queueTracks = queue.tracks
        queueIndex = queue.index
        currentTrackID = queue.current?.id
    }

    private func loadAndPlayCurrent() {
        guard let track = queue.current else { return }
        syncQueue()
        load(url: track.url)              // sets up AVPlayer/duration/observers
        currentTrackName = track.title
        artist = track.artist
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
        onTrackChange?(track, true)
        Task { await refreshMetadata(for: track) }
    }

    private func refreshMetadata(for track: Track) async {
        let meta = await track.loadMetadata()
        let art = await track.loadArtwork()
        // Guard against a newer track having started while we awaited.
        guard queue.current?.id == track.id else { return }
        currentTrackName = meta.title
        artist = meta.artist
        artwork = art
        theme = await ArtworkPalette.theme(for: art)
        updateNowPlayingInfo()
        onTrackChange?(queue.current, isPlaying)
    }

    private func handlePlaybackFinished() {
        if queue.hasNext {
            next()
        } else {
            stop()   // stop() already fires onTrackChange(false) + updateNowPlayingInfo()
        }
    }

    private func startTimer() {
        stopTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgress()
            }
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func syncProgress() {
        guard let player, player.currentItem != nil else {
            currentTime = 0
            isPlaying = false
            stopTimer()
            return
        }
        let t = player.currentTime().seconds
        if t.isFinite { currentTime = t }
        // Now Playing elapsed is set on state changes (play/pause/seek); the system
        // extrapolates between them from the playback rate, so no per-tick update here.
    }

    private func releaseSecurityScopedURL() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}

// TEMPORARY STUB — remove in Task 3 once NowPlayingCenter.swift defines these.
extension MusicPlayer {
    func configureRemoteCommands() {}
    func updateNowPlayingInfo() {}
}
```

- [ ] **Step 2: Delete the obsolete finish test**

```bash
git rm koraTests/PlayerFinishTests.swift
```

(Removes the unit test for the now-deleted `shouldAdvanceOnFinish`. Also remember to remove its file reference from the Xcode project if the project does not auto-discover test sources — see Step 3 if the build complains.)

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' build`
Expected: `BUILD SUCCEEDED`. If it fails with a missing-file reference to `PlayerFinishTests.swift`, open the project, remove the stale reference, and rebuild.

- [ ] **Step 4: Run the test suite**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' -parallel-testing-enabled NO test`
Expected: `TEST SUCCEEDED` with `PlayQueueTests`, `BookmarkStoreTests`, `LibraryScanTests`, `ArtworkThemeTests` present and passing; `PlayerFinishTests` gone.

- [ ] **Step 5: Manual verification (the actual fix)**

Launch the app. Play a track **longer than one hour** (a VBR MP3 podcast is the worst case):
- Playback starts within a fraction of a second (was ~3s).
- The UI and keyboard do **not** freeze on selection.
- The seek bar's total-time fills in a moment later (async duration) — expected.
Then play a **short** track and let it run to the end → it auto-advances to the next queued track. Pause near the end → it does **not** advance.

- [ ] **Step 6: Commit**

```bash
git add kora/Player/MusicPlayer.swift
git commit -m "perf: stream playback with AVPlayer to kill the long-file stall

AVAudioPlayer scanned the whole file on the main thread before playing,
freezing the UI ~3s on 1hr+ VBR files. Switch to AVPlayer (streams,
near-instant start), load duration async, and detect finish via
AVPlayerItemDidPlayToEndTime instead of a polling heuristic. Removes the
now-obsolete shouldAdvanceOnFinish + PlayerFinishTests.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: System media-key support via MediaPlayer

**Root cause:** Nothing registers `MPRemoteCommandCenter` handlers or publishes `MPNowPlayingInfoCenter`. The only "now playing" wiring is `NowPlayingState`, which writes a JSON snapshot to the shared container for the **widget** — not the system. macOS routes the F7/F8/F9 keys, Control Center, Touch Bar, and AirPods controls through the MediaPlayer framework, so with no handlers + no now-playing info the OS never hands those events to Kora.

**Fix:** Add a `MusicPlayer` extension that (a) registers play / pause / toggle / next / previous remote commands → existing `playPause()`/`next()`/`previous()`, and (b) publishes title/artist/duration/elapsed/artwork + `playbackState` to `MPNowPlayingInfoCenter` (which is what makes macOS treat Kora as the active Now Playing app and route the keys). The call sites were already added in Task 2; this task replaces the temporary stub with the real implementation.

**Files:**
- Create: `kora/Player/NowPlayingCenter.swift`
- Modify: `kora/Player/MusicPlayer.swift` (delete the temporary stub extension from Task 2)

**Interfaces:**
- Consumes: `MusicPlayer` public state (`currentTrackName`, `artist`, `duration`, `currentTime`, `isPlaying`, `artwork`, `hasTrack`) and methods (`playPause()`, `next()`, `previous()`).
- Produces: `configureRemoteCommands()` and `updateNowPlayingInfo()` (the real definitions the rest of `MusicPlayer` already calls).

- [ ] **Step 1: Remove the temporary stub from `MusicPlayer.swift`**

Delete this block at the end of `kora/Player/MusicPlayer.swift` (added in Task 2):

```swift
// TEMPORARY STUB — remove in Task 3 once NowPlayingCenter.swift defines these.
extension MusicPlayer {
    func configureRemoteCommands() {}
    func updateNowPlayingInfo() {}
}
```

- [ ] **Step 2: Create `kora/Player/NowPlayingCenter.swift`**

```swift
import AVFoundation
import MediaPlayer
import AppKit

extension MusicPlayer {
    /// Register hardware/system media-key handlers once at init. macOS routes the
    /// media keys / Control Center / AirPods controls to whichever app owns the
    /// MediaPlayer remote-command center *and* publishes now-playing info.
    func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPause() }
            return .success
        }
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == false { self?.playPause() } }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.playPause() } }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }

    /// Publish the current track to the system Now Playing center. Setting this
    /// (with playbackState) is what makes macOS deliver the media keys here.
    func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()
        guard hasTrack else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrackName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artist { info[MPMediaItemPropertyArtist] = artist }
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let artwork, let image = NSImage(data: artwork) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' build`
Expected: `BUILD SUCCEEDED`. If it fails with a missing-file reference to `NowPlayingCenter.swift`, add the new file to the `kora` target in the project, then rebuild.

- [ ] **Step 4: Run the test suite (regression gate)**

Run: `xcodebuild -scheme kora -destination 'platform=macOS' -parallel-testing-enabled NO test`
Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Manual verification (the actual fix)**

Launch the app and start playing a track. Then:
- Press the keyboard **play/pause media key** (F8 on most Macs) → playback toggles.
- Press the **next / previous** media keys (F9 / F7) → track changes.
- Open **Control Center → the Now Playing tile** → it shows Kora's title/artist/artwork, and its transport buttons control playback.
- (If you have AirPods) the stem play/pause gesture toggles playback.

- [ ] **Step 6: Commit**

```bash
git add kora/Player/NowPlayingCenter.swift kora/Player/MusicPlayer.swift
git commit -m "feat: system media-key + Now Playing support via MediaPlayer

Register MPRemoteCommandCenter handlers (play/pause/toggle/next/previous)
and publish MPNowPlayingInfoCenter so macOS routes the media keys,
Control Center, and AirPods controls to Kora.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Issue 1 (Add Folder button dead, drag-drop works) → Task 1. ✓
- Issue 2 (~3s stall + frozen keys on >1hr files) → Task 2. ✓ (the main-thread freeze that also ate key input is eliminated by streaming + async duration off the synchronous path)
- Issue 3 (media keys play/forward/backward ignored) → Task 3. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output. The only stub is the *intentional, named* temporary in Task 2, explicitly removed in Task 3 Step 1.

**Type consistency:** `configureRemoteCommands()` / `updateNowPlayingInfo()` — same names in Task 2 call sites, Task 2 stub, and Task 3 real definitions. `handlePlaybackFinished()` defined and called in Task 2 only. `pickFolder() -> URL?` defined and used three times in Task 1. Public surface of `MusicPlayer` unchanged, so `NowPlayingView`, `ContentView`, `LibrarySidebar`, `koraApp`, `QueueView` bindings all still resolve.

**Out of scope (deliberately not done):** Control Center scrubbing (`changePlaybackPositionCommand`) — add only if you want drag-to-seek from the Now Playing tile. Per-tick Now Playing elapsed updates — unnecessary; the system extrapolates from rate.
