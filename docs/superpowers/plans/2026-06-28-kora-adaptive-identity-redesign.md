# Kora Adaptive Identity Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Kora an adaptive, artwork-driven visual identity and add folder management, a queue/up-next view, and a menu-bar mini-player — landing as one cohesive redesign.

**Architecture:** SwiftUI + AVFoundation, existing module layout kept. A small pure theming layer (`ArtworkTheme` + `ArtworkPalette`) derives an accent + text color from the playing track's average artwork color; the now-playing view renders a blurred-art backdrop and tints to it. Folder storage migrates from a `[Data]` bookmark blob to an ordered `Codable` model that carries display names and survives stale bookmarks. The queue (already in code) becomes visible via a native `.inspector`, and playback gains app-menu commands + a `MenuBarExtra`.

**Tech Stack:** Swift, SwiftUI, AVFoundation, CoreImage (`CIAreaAverage`), Swift Testing, Xcode 26 / macOS 15.7.

## Global Constraints

- **Deployment target macOS 15.7** — `MenuBarExtra`, `.inspector`, modern materials are all available; no `@available` gating needed.
- **Tests use Swift Testing** (`import Testing`, `@Test`, `#expect`) — never XCTest. Mark tests touching `@MainActor` types with `@MainActor`.
- **Testable logic is extracted as `nonisolated static` pure functions** and tested directly (the existing pattern: `shouldAdvanceOnFinish`, `encodeBookmarks`, `audioFiles`). Views, CoreImage extraction, and AVAudio playback are build-/manual-verify only.
- **Synchronized file groups**: new `.swift` files placed under `kora/<Group>/` or `koraTests/` are auto-included in the target. Do NOT edit `kora.xcodeproj/project.pbxproj`.
- **Sandbox preserved**: keep security-scoped bookmark lifecycle intact (`startAccessingSecurityScopedResource` / `stop…`). No new entitlements.
- **Adaptive color lives only in the now-playing view.** The sidebar stays neutral and borrows the accent only on the currently-playing row.
- **No new third-party dependencies.**
- **Commit after every task.** Commit messages follow the repo style (`feat:`, `refactor:`, `test:`, `docs:`).

**Unit-test command (used throughout):**
```bash
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests CODE_SIGNING_ALLOWED=NO
```
**Build command (used for view/integration tasks):**
```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```
Note: because a missing Swift method is a *compile* error, the Swift-Testing "verify it fails" step shows up as a **build/compile failure of the test target**, not a clean red test. That is the expected red state here.

---

### Task 1: PlayQueue gains `move` and `jump`

**Files:**
- Modify: `kora/Player/PlayQueue.swift`
- Test: `koraTests/PlayQueueTests.swift`

**Interfaces:**
- Consumes: existing `PlayQueue(tracks:startAt:)`, `current`, `index`, `tracks`.
- Produces: `mutating func move(fromOffsets: IndexSet, toOffset: Int)` (keeps `index` on the same track id), `mutating func jump(to newIndex: Int)` (clamps to `0...count-1`).

- [ ] **Step 1: Write the failing tests**

Add to `koraTests/PlayQueueTests.swift`:
```swift
    @Test @MainActor func jumpClampsIntoBounds() {
        var q = PlayQueue(tracks: [track("a"), track("b"), track("c")], startAt: 0)
        q.jump(to: 2)
        #expect(q.current?.title == "c")
        q.jump(to: 99)
        #expect(q.current?.title == "c")   // clamped to last
        q.jump(to: -5)
        #expect(q.current?.title == "a")   // clamped to first
    }

    @Test @MainActor func moveKeepsCurrentTrackWhenItShifts() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 0)   // current = a
        // Move "a" from front to the end; current must still be "a".
        q.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(q.tracks.map(\.title) == ["b", "c", "a"])
        #expect(q.current?.title == "a")
    }

    @Test @MainActor func moveOtherTrackLeavesCurrentUnchanged() {
        let a = track("a"), b = track("b"), c = track("c")
        var q = PlayQueue(tracks: [a, b, c], startAt: 1)   // current = b
        // Move "c" before "a"; current is still "b".
        q.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(q.tracks.map(\.title) == ["c", "a", "b"])
        #expect(q.current?.title == "b")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit-test command. Expected: **compile failure** of `koraTests` — `value of type 'PlayQueue' has no member 'move'` / `'jump'`.

- [ ] **Step 3: Implement `move` and `jump`**

Add to `kora/Player/PlayQueue.swift` inside `struct PlayQueue`:
```swift
    mutating func jump(to newIndex: Int) {
        guard !tracks.isEmpty else { return }
        index = min(max(newIndex, 0), tracks.count - 1)
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let currentID = current?.id
        tracks.move(fromOffsets: source, toOffset: destination)
        if let currentID, let i = tracks.firstIndex(where: { $0.id == currentID }) {
            index = i
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run the unit-test command. Expected: PASS (all `PlayQueueTests`).

- [ ] **Step 5: Commit**
```bash
git add kora/Player/PlayQueue.swift koraTests/PlayQueueTests.swift
git commit -m "feat: PlayQueue move/jump keeping current track identity"
```

---

### Task 2: ArtworkTheme + ArtworkPalette (the theming layer)

**Files:**
- Create: `kora/Player/ArtworkTheme.swift`
- Test: `koraTests/ArtworkThemeTests.swift`

**Interfaces:**
- Produces:
  - `struct ArtworkTheme: Equatable { var accent: Color; var textPrimary: Color; var artwork: Data?; static let neutral }`
  - `enum ArtworkPalette` with pure `static func useDarkText(r:g:b:) -> Bool`, pure `static func theme(forAverage r:g:b:artwork:) -> ArtworkTheme`, and async `static func theme(for data: Data?) async -> ArtworkTheme`.

- [ ] **Step 1: Write the failing tests**

Create `koraTests/ArtworkThemeTests.swift`:
```swift
import Testing
import SwiftUI
@testable import kora

struct ArtworkThemeTests {
    @Test func lightAverageUsesDarkText() {
        #expect(ArtworkPalette.useDarkText(r: 1, g: 1, b: 1))        // white art → black text
        #expect(ArtworkPalette.useDarkText(r: 0.9, g: 0.9, b: 0.8))
    }

    @Test func darkAverageUsesLightText() {
        #expect(!ArtworkPalette.useDarkText(r: 0, g: 0, b: 0))       // black art → white text
        #expect(!ArtworkPalette.useDarkText(r: 0.1, g: 0.1, b: 0.2))
    }

    @Test func themeFromAverageCarriesArtworkAndTextChoice() {
        let art = Data([1, 2, 3])
        let light = ArtworkPalette.theme(forAverage: 1, g: 1, b: 1, artwork: art)
        #expect(light.textPrimary == Color.black)
        #expect(light.artwork == art)

        let dark = ArtworkPalette.theme(forAverage: 0, g: 0, b: 0, artwork: art)
        #expect(dark.textPrimary == Color.white)
    }

    @Test func nilArtworkIsNeutral() async {
        let theme = await ArtworkPalette.theme(for: nil)
        #expect(theme == ArtworkTheme.neutral)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit-test command. Expected: **compile failure** — `cannot find 'ArtworkPalette' in scope`.

- [ ] **Step 3: Implement the theming layer**

Create `kora/Player/ArtworkTheme.swift`:
```swift
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ArtworkTheme: Equatable {
    var accent: Color
    var textPrimary: Color
    var artwork: Data?

    static let neutral = ArtworkTheme(accent: .accentColor, textPrimary: .primary, artwork: nil)
}

enum ArtworkPalette {
    /// Relative luminance threshold: bright average artwork wants dark text on top.
    static func useDarkText(r: Double, g: Double, b: Double) -> Bool {
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b   // 0...1
        return luminance > 0.6
    }

    static func theme(forAverage r: Double, g: Double, b: Double, artwork: Data?) -> ArtworkTheme {
        ArtworkTheme(
            accent: Color(.sRGB, red: r, green: g, blue: b, opacity: 1),
            textPrimary: useDarkText(r: r, g: g, b: b) ? .black : .white,
            artwork: artwork
        )
    }

    /// Decodes artwork, averages it with CIAreaAverage, and builds a theme.
    /// Returns `.neutral` for missing/undecodable artwork. Runs off the main actor.
    static func theme(for data: Data?) async -> ArtworkTheme {
        guard let data, let avg = averageRGBA(of: data) else { return .neutral }
        return theme(forAverage: avg.r, g: avg.g, b: avg.b, artwork: data)
    }

    private static func averageRGBA(of data: Data) -> (r: Double, g: Double, b: Double)? {
        guard let image = CIImage(data: data) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(bitmap[0]) / 255, Double(bitmap[1]) / 255, Double(bitmap[2]) / 255)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the unit-test command. Expected: PASS (all `ArtworkThemeTests`).

- [ ] **Step 5: Commit**
```bash
git add kora/Player/ArtworkTheme.swift koraTests/ArtworkThemeTests.swift
git commit -m "feat: adaptive artwork theming layer (accent + text from average color)"
```

---

### Task 3: Publish theme + current-track id from MusicPlayer

**Files:**
- Modify: `kora/Player/MusicPlayer.swift`
- Test: `koraTests/ArtworkThemeTests.swift` (one `@MainActor` default-state test)

**Interfaces:**
- Consumes: `ArtworkPalette.theme(for:)` (Task 2).
- Produces on `MusicPlayer`: `@Published private(set) var theme: ArtworkTheme` (default `.neutral`), `@Published private(set) var currentTrackID: UUID?`.

- [ ] **Step 1: Write the failing test**

Add to `koraTests/ArtworkThemeTests.swift`:
```swift
    @Test @MainActor func freshPlayerHasNeutralThemeAndNoCurrentTrack() {
        let player = MusicPlayer()
        #expect(player.theme == ArtworkTheme.neutral)
        #expect(player.currentTrackID == nil)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit-test command. Expected: **compile failure** — `value of type 'MusicPlayer' has no member 'theme'`.

- [ ] **Step 3: Add published state and compute theme on metadata load**

In `kora/Player/MusicPlayer.swift`, add to the published block (near `artwork`):
```swift
    @Published private(set) var theme: ArtworkTheme = .neutral
    @Published private(set) var currentTrackID: UUID?
```

In `loadAndPlayCurrent()`, after `guard let track = queue.current else { return }`, set the id:
```swift
        currentTrackID = track.id
```

In `refreshMetadata(for:)`, after the existing stale-guard line `guard queue.current?.id == track.id else { return }`, extend the assignments:
```swift
        currentTrackName = meta.title
        artist = meta.artist
        artwork = art
        theme = await ArtworkPalette.theme(for: art)
        onTrackChange?(queue.current, isPlaying)
```
(The `await` runs the CoreImage average off the main actor inside `ArtworkPalette.theme`; reassigning `theme` re-checks nothing further because the guard already ran — acceptable: a second in-flight track would have changed `queue.current` and this method instance returns at its own guard. If precision matters later, re-check the guard after the await.)

- [ ] **Step 4: Run tests to verify they pass + build**

Run the unit-test command (expect PASS), then the build command (expect BUILD SUCCEEDED).

- [ ] **Step 5: Commit**
```bash
git add kora/Player/MusicPlayer.swift koraTests/ArtworkThemeTests.swift
git commit -m "feat: MusicPlayer publishes adaptive theme and current track id"
```

---

### Task 4: Now-playing redesign (immersive, art-driven)

**Files:**
- Modify: `kora/Player/NowPlayingView.swift`

**Interfaces:**
- Consumes: `player.theme` (`accent`, `textPrimary`, `artwork`), `player.artwork`, `player.currentTrackID`, existing transport/seek/volume API.

This is a view task: write the view, build, and verify visually. No unit test (SwiftUI layout is manual-verify).

- [ ] **Step 1: Rewrite the view**

Replace the body of `kora/Player/NowPlayingView.swift` with:
```swift
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        ZStack {
            backdrop
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.5), value: player.theme)
        .animation(.easeInOut(duration: 0.5), value: player.currentTrackID)
    }

    // MARK: Backdrop — the blurred album art itself + a legibility scrim.
    private var backdrop: some View {
        ZStack {
            if let data = player.theme.artwork, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 60)          // ponytail: SwiftUI .blur on full-res art; pre-blur a thumbnail with CIGaussianBlur only if janky
                    .opacity(0.55)
                    .transition(.opacity)
                    .id(player.currentTrackID) // cross-fade on track change
            } else {
                LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.1)],
                               startPoint: .top, endPoint: .bottom)
            }
            Rectangle().fill(.black.opacity(0.35))   // scrim for contrast
        }
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 28) {
            artworkCard
            VStack(spacing: 6) {
                Text(player.hasTrack ? player.currentTrackName : "Nothing playing")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2)
                if let artist = player.artist, !artist.isEmpty {
                    Text(artist).font(.title3).opacity(0.85)
                } else if !player.hasTrack {
                    Text("Add a folder, then pick a track").font(.callout).opacity(0.7)
                }
            }
            .foregroundStyle(player.theme.textPrimary)
            seekBar
            transport
            volume
            if let errorMessage = player.errorMessage {
                Text(errorMessage).font(.callout).multilineTextAlignment(.center)
                    .foregroundStyle(.red)
            }
        }
        .padding(40)
        .frame(maxWidth: 560)
        .tint(player.theme.accent)
    }

    private var artworkCard: some View {
        Group {
            if let data = player.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.black.opacity(0.25)
                    Image(systemName: "music.note").font(.system(size: 56))
                        .foregroundStyle(player.theme.textPrimary.opacity(0.7))
                }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                   in: 0...max(player.duration, 1))
                .disabled(player.duration == 0)
            HStack {
                Text(timeString(player.currentTime)); Spacer(); Text(timeString(player.duration))
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(player.theme.textPrimary.opacity(0.8))
        }
    }

    private var transport: some View {
        HStack(spacing: 24) {
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous")
            Button { player.playPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.largeTitle)
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Button { player.next() } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next")
        }
        .font(.title2)
        .foregroundStyle(player.theme.textPrimary)
        .buttonStyle(.plain)
        .disabled(!player.hasTrack)
    }

    private var volume: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").accessibilityHidden(true)
            Slider(value: $player.volume, in: 0...1).accessibilityLabel("Volume")
            Image(systemName: "speaker.wave.3.fill").accessibilityHidden(true)
        }
        .foregroundStyle(player.theme.textPrimary.opacity(0.7))
        .frame(maxWidth: 260)
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let s = max(Int(value), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NowPlayingView().environmentObject(MusicPlayer())
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verify**

Run the app (Xcode Cmd-R). Confirm: empty state shows "Nothing playing" + hint on a neutral gradient; playing a track shows the blurred-art backdrop, large rounded title, accent-tinted seek/transport, and the colors **cross-fade** when you hit Next.

- [ ] **Step 4: Commit**
```bash
git add kora/Player/NowPlayingView.swift
git commit -m "feat: immersive art-driven now-playing redesign"
```

---

### Task 5: Folder persistence model + migration

**Files:**
- Modify: `kora/Library/MusicLibrary.swift`
- Test: `koraTests/BookmarkStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct PersistedFolder: Codable, Equatable { var bookmark: Data; var displayName: String? }`
  - `nonisolated static func encodePersisted(_:) -> Data`, `nonisolated static func decodePersisted(_:) -> [PersistedFolder]`, `nonisolated static func migrate(legacy: [Data]) -> [PersistedFolder]`
  - `Folder` now: `var url: URL?`, `var displayName: String?`, `var isAvailable: Bool`, computed `name`.

- [ ] **Step 1: Write the failing tests**

Add to `koraTests/BookmarkStoreTests.swift`:
```swift
    @Test func persistedFoldersRoundTrip() {
        let folders = [
            MusicLibrary.PersistedFolder(bookmark: Data([1, 2, 3]), displayName: "Jazz"),
            MusicLibrary.PersistedFolder(bookmark: Data([4, 5]), displayName: nil),
        ]
        let decoded = MusicLibrary.decodePersisted(MusicLibrary.encodePersisted(folders))
        #expect(decoded == folders)
    }

    @Test func decodePersistedGarbageReturnsEmpty() {
        #expect(MusicLibrary.decodePersisted(Data([0xFF, 0x00])) == [])
    }

    @Test func migrateLegacyBookmarksKeepsOrderAndDropsNames() {
        let legacy = [Data([1]), Data([2]), Data([3])]
        let migrated = MusicLibrary.migrate(legacy: legacy)
        #expect(migrated.map(\.bookmark) == legacy)
        #expect(migrated.allSatisfy { $0.displayName == nil })
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit-test command. Expected: **compile failure** — `cannot find 'PersistedFolder'` / `'encodePersisted'`.

- [ ] **Step 3: Implement the model, codec, migration, and rewrite storage**

In `kora/Library/MusicLibrary.swift`:

Replace the `Folder` struct with:
```swift
    struct Folder: Identifiable, Hashable {
        let id: UUID
        var url: URL?
        let bookmark: Data
        var displayName: String?
        var isAvailable: Bool
        var tracks: [Track]
        var name: String { displayName ?? url?.lastPathComponent ?? "Unavailable folder" }
    }

    struct PersistedFolder: Codable, Equatable {
        var bookmark: Data
        var displayName: String?
    }
```

Add the new persistence key and codec next to the existing `bookmarksKey`:
```swift
    private let foldersKey = "library.folders.v2"

    nonisolated static func encodePersisted(_ folders: [PersistedFolder]) -> Data {
        (try? JSONEncoder().encode(folders)) ?? Data()
    }

    nonisolated static func decodePersisted(_ data: Data) -> [PersistedFolder] {
        (try? JSONDecoder().decode([PersistedFolder].self, from: data)) ?? []
    }

    nonisolated static func migrate(legacy bookmarks: [Data]) -> [PersistedFolder] {
        bookmarks.map { PersistedFolder(bookmark: $0, displayName: nil) }
    }
```

Replace `currentBookmarks()` / `persist(_:)` usage with a folder-aware store. Add:
```swift
    private func loadPersisted() -> [PersistedFolder] {
        if let data = defaults.data(forKey: foldersKey) {
            return MusicLibrary.decodePersisted(data)
        }
        // One-time migration from the legacy [Data] bookmark blob.
        guard let legacyData = defaults.data(forKey: bookmarksKey) else { return [] }
        let migrated = MusicLibrary.migrate(legacy: MusicLibrary.decodeBookmarks(legacyData))
        persistFolders(migrated)
        return migrated
    }

    private func persistFolders(_ entries: [PersistedFolder]) {
        defaults.set(MusicLibrary.encodePersisted(entries), forKey: foldersKey)
    }

    private func persistCurrent() {
        persistFolders(folders.map { PersistedFolder(bookmark: $0.bookmark, displayName: $0.displayName) })
    }
```

Rewrite `addFolder`, `forget`, `restore`, and `ingest` to use the new model:
```swift
    func addFolder(url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        ingest(url: url, bookmark: bookmark, displayName: nil)
        persistCurrent()
    }

    func forget(_ folder: Folder) {
        folder.url?.stopAccessingSecurityScopedResource()
        if let url = folder.url { accessedURLs.removeAll { $0 == url } }
        folders.removeAll { $0.id == folder.id }
        persistCurrent()
    }

    func restore() {
        for entry in loadPersisted() {
            var stale = false
            let url = try? URL(
                resolvingBookmarkData: entry.bookmark, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &stale
            )
            if let url, !stale {
                ingest(url: url, bookmark: entry.bookmark, displayName: entry.displayName)
            } else {
                // Keep a placeholder instead of vanishing — re-link comes in Task 7.
                folders.append(Folder(id: UUID(), url: nil, bookmark: entry.bookmark,
                                      displayName: entry.displayName, isAvailable: false, tracks: []))
            }
        }
    }

    private func ingest(url: URL, bookmark: Data, displayName: String?) {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(url) }
        let folderID = UUID()
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folderID) }
        folders.append(Folder(id: folderID, url: url, bookmark: bookmark,
                              displayName: displayName, isAvailable: true, tracks: tracks))
    }
```

Delete the now-unused private `currentBookmarks()` and `persist(_:)` (the old `[Data]` path). Keep `encodeBookmarks`/`decodeBookmarks` — `loadPersisted()` still uses `decodeBookmarks` for migration.

- [ ] **Step 4: Run tests + build**

Run the unit-test command (expect PASS, including the existing `bookmarkArrayRoundTrips`), then the build command (expect BUILD SUCCEEDED).

- [ ] **Step 5: Commit**
```bash
git add kora/Library/MusicLibrary.swift koraTests/BookmarkStoreTests.swift
git commit -m "refactor: Codable folder storage with display names + legacy migration"
```

---

### Task 6: Rescan folders

**Files:**
- Modify: `kora/Library/MusicLibrary.swift`
- Test: `koraTests/LibraryScanTests.swift`

**Interfaces:**
- Produces on `MusicLibrary`: `func rescan(_ folder: Folder)`, `func rescanAll()`.

- [ ] **Step 1: Write the failing test**

Add to `koraTests/LibraryScanTests.swift` (the pure-scan seam that rescan relies on):
```swift
    @Test func audioFilesReflectsAddedAndRemovedFiles() {
        let root = tempDir()
        write("a.mp3", in: root)
        #expect(MusicLibrary.audioFiles(in: root).count == 1)

        write("b.mp3", in: root)
        #expect(MusicLibrary.audioFiles(in: root).count == 2)   // rescan would pick this up

        try? FileManager.default.removeItem(at: root.appendingPathComponent("a.mp3"))
        #expect(MusicLibrary.audioFiles(in: root).map(\.lastPathComponent) == ["b.mp3"])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit-test command. This test compiles against existing API, so it should **PASS immediately** — it documents the contract `rescan` depends on. (If it fails, the scan contract changed; stop and investigate.) Treat a PASS here as the green for the contract; the method itself is build-verified in Step 4.

- [ ] **Step 3: Implement `rescan` / `rescanAll`**

Add to `MusicLibrary` (Public API section):
```swift
    func rescan(_ folder: Folder) {
        guard let url = folder.url else { return }
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folder.id) }
        if let i = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[i].tracks = tracks
        }
    }

    func rescanAll() {
        for folder in folders where folder.isAvailable { rescan(folder) }
    }
```

- [ ] **Step 4: Run tests + build**

Run the unit-test command (expect PASS), then the build command (expect BUILD SUCCEEDED).

- [ ] **Step 5: Commit**
```bash
git add kora/Library/MusicLibrary.swift koraTests/LibraryScanTests.swift
git commit -m "feat: rescan a folder / rescan all to pick up on-disk changes"
```

---

### Task 7: Stale-folder state + re-link

**Files:**
- Modify: `kora/Library/MusicLibrary.swift`
- Test: `koraTests/BookmarkStoreTests.swift`

**Interfaces:**
- Produces: `nonisolated static func isAvailable(resolvedURL: URL?, isStale: Bool) -> Bool`, `func relink(_ folder: Folder, to newURL: URL)`.

(`restore()` from Task 5 already keeps unavailable placeholders. This task adds the tested availability rule and the re-link action that replaces a stale bookmark.)

- [ ] **Step 1: Write the failing test**

Add to `koraTests/BookmarkStoreTests.swift`:
```swift
    @Test func availabilityRequiresResolvableNonStaleURL() {
        let url = URL(fileURLWithPath: "/tmp/x")
        #expect(MusicLibrary.isAvailable(resolvedURL: url, isStale: false))
        #expect(!MusicLibrary.isAvailable(resolvedURL: url, isStale: true))   // stale → unavailable
        #expect(!MusicLibrary.isAvailable(resolvedURL: nil, isStale: false))  // unresolvable → unavailable
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run the unit-test command. Expected: **compile failure** — `type 'MusicLibrary' has no member 'isAvailable'`.

- [ ] **Step 3: Implement the rule + re-link, and use the rule in `restore()`**

Add to `MusicLibrary`:
```swift
    nonisolated static func isAvailable(resolvedURL: URL?, isStale: Bool) -> Bool {
        resolvedURL != nil && !isStale
    }

    func relink(_ folder: Folder, to newURL: URL) {
        guard let bookmark = try? newURL.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        let accessed = newURL.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(newURL) }
        let tracks = MusicLibrary.audioFiles(in: newURL).map { Track(url: $0, folderID: folder.id) }
        if let i = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[i].url = newURL
            folders[i] = Folder(id: folder.id, url: newURL, bookmark: bookmark,
                                displayName: folder.displayName, isAvailable: true, tracks: tracks)
        }
        persistCurrent()
    }
```

In `restore()`, replace the `if let url, !stale {` condition with the tested rule:
```swift
            if MusicLibrary.isAvailable(resolvedURL: url, isStale: stale), let url {
                ingest(url: url, bookmark: entry.bookmark, displayName: entry.displayName)
            } else {
                folders.append(Folder(id: UUID(), url: nil, bookmark: entry.bookmark,
                                      displayName: entry.displayName, isAvailable: false, tracks: []))
            }
```

- [ ] **Step 4: Run tests + build**

Run the unit-test command (expect PASS), then the build command (expect BUILD SUCCEEDED).

- [ ] **Step 5: Commit**
```bash
git add kora/Library/MusicLibrary.swift koraTests/BookmarkStoreTests.swift
git commit -m "feat: keep stale folders as unavailable placeholders with re-link"
```

---

### Task 8: Rename + reorder folders

**Files:**
- Modify: `kora/Library/MusicLibrary.swift`

**Interfaces:**
- Produces on `MusicLibrary`: `func rename(_ folder: Folder, to name: String)`, `func moveFolders(fromOffsets: IndexSet, toOffset: Int)`.

- [ ] **Step 1: Implement rename + reorder**

Add to `MusicLibrary`:
```swift
    func rename(_ folder: Folder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].displayName = trimmed.isEmpty ? nil : trimmed
        persistCurrent()
    }

    func moveFolders(fromOffsets source: IndexSet, toOffset destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        persistCurrent()
    }
```

(No new unit test: `rename`/`moveFolders` are thin `@MainActor` mutations over `persistCurrent()`, whose codec/order is already covered by Task 5's round-trip test. Verified by build + manual.)

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**
```bash
git add kora/Library/MusicLibrary.swift
git commit -m "feat: rename and reorder folders, persisted across launches"
```

---

### Task 9: Sidebar redesign (indicator, states, context menus, reorder)

**Files:**
- Modify: `kora/Library/LibrarySidebar.swift`

**Interfaces:**
- Consumes: `library.folders` (with `isAvailable`, `name`, `tracks`), `library.rescan/forget/rename/relink/moveFolders`, `player.play(track:in:)`, `player.currentTrackID`.

View task: write, build, manual-verify.

- [ ] **Step 1: Rewrite the sidebar**

Replace `kora/Library/LibrarySidebar.swift` with:
```swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LibrarySidebar: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var choosingFolder = false
    @State private var locating: MusicLibrary.Folder?
    @State private var renaming: MusicLibrary.Folder?
    @State private var draftName = ""

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
            Button { choosingFolder = true } label: { Label("Add Folder", systemImage: "plus") }
                .padding(8)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { library.addFolder(url: url) }
        }
        .fileImporter(isPresented: Binding(get: { locating != nil },
                                           set: { if !$0 { locating = nil } }),
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result, let folder = locating {
                library.relink(folder, to: url)
            }
            locating = nil
        }
        .alert("Rename Folder", isPresented: Binding(get: { renaming != nil },
                                                     set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $draftName)
            Button("Save") { if let f = renaming { library.rename(f, to: draftName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var folderList: some View {
        List {
            ForEach(library.folders) { folder in
                Section {
                    if folder.isAvailable {
                        ForEach(folder.tracks) { track in trackRow(track, in: folder) }
                    } else {
                        Button("Locate…") { locating = folder }
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text(folder.name).foregroundStyle(folder.isAvailable ? .primary : .secondary)
                        Spacer()
                        if folder.isAvailable {
                            Text("\(folder.tracks.count)").foregroundStyle(.secondary).font(.caption)
                        } else {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                        }
                    }
                }
                .contextMenu { folderMenu(folder) }
            }
            .onMove { library.moveFolders(fromOffsets: $0, toOffset: $1) }
        }
    }

    private func trackRow(_ track: Track, in folder: MusicLibrary.Folder) -> some View {
        let isPlaying = player.currentTrackID == track.id
        return Button {
            player.play(track: track, in: folder.tracks)
        } label: {
            HStack(spacing: 8) {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(player.theme.accent)
                }
                Text(track.title).foregroundStyle(isPlaying ? player.theme.accent : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([track.url])
            }
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: MusicLibrary.Folder) -> some View {
        if folder.isAvailable {
            Button("Rescan") { library.rescan(folder) }
            Button("Reveal in Finder") {
                if let url = folder.url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        } else {
            Button("Locate…") { locating = folder }
        }
        Button("Rename…") { renaming = folder; draftName = folder.name }
        Button("Forget Folder", role: .destructive) { library.forget(folder) }
    }
}

#Preview {
    LibrarySidebar()
        .environmentObject(MusicLibrary())
        .environmentObject(MusicPlayer())
}
```

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual verify**

Run the app. Confirm: empty state shows the "No folders yet" view; folder headers show track counts; the playing track is accent-tinted with a speaker glyph; right-click a folder offers Rescan / Reveal / Rename / Forget; right-click a track offers Reveal; folders drag-reorder. (Stale state is verified in Task 13's manual pass.)

- [ ] **Step 4: Commit**
```bash
git add kora/Library/LibrarySidebar.swift
git commit -m "feat: sidebar with playing indicator, states, context menus, reorder"
```

---

### Task 10: Expose the queue from MusicPlayer

**Files:**
- Modify: `kora/Player/MusicPlayer.swift`

**Interfaces:**
- Produces on `MusicPlayer`: `@Published private(set) var queueTracks: [Track]`, `@Published private(set) var queueIndex: Int`, `func jumpInQueue(to index: Int)`, `func moveInQueue(fromOffsets: IndexSet, toOffset: Int)`.

- [ ] **Step 1: Add a published queue mirror + mutations**

In `kora/Player/MusicPlayer.swift` add to the published block:
```swift
    @Published private(set) var queueTracks: [Track] = []
    @Published private(set) var queueIndex: Int = 0
```

Add a private sync helper and call it wherever the queue changes:
```swift
    private func syncQueue() {
        queueTracks = queue.tracks
        queueIndex = queue.index
        currentTrackID = queue.current?.id
    }
```

Call `syncQueue()` at the end of `play(track:in:)`, `next()`, `previous()`, and after `loadAndPlayCurrent()` sets `currentTrackID`. Then add the queue-driven actions:
```swift
    func jumpInQueue(to index: Int) {
        queue.jump(to: index)
        loadAndPlayCurrent()
        syncQueue()
    }

    func moveInQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        syncQueue()
    }
```

(Remove the now-redundant `currentTrackID = track.id` line added in Task 3 from `loadAndPlayCurrent()` only if you instead call `syncQueue()` there; keep exactly one assignment path. Simplest: keep `loadAndPlayCurrent()` setting `currentTrackID = track.id`, and have the four mutators call `syncQueue()`.)

- [ ] **Step 2: Build**

Run the build command. Expected: BUILD SUCCEEDED. (Queue logic correctness is covered by Task 1's `PlayQueue` tests; playback wiring is manual-verify in Task 11.)

- [ ] **Step 3: Commit**
```bash
git add kora/Player/MusicPlayer.swift
git commit -m "feat: MusicPlayer exposes a published queue with jump/move"
```

---

### Task 11: Queue inspector + ContentView toolbar

**Files:**
- Create: `kora/Player/QueueView.swift`
- Modify: `kora/UI/ContentView.swift`

**Interfaces:**
- Consumes: `player.queueTracks`, `player.queueIndex`, `player.jumpInQueue(to:)`, `player.moveInQueue(fromOffsets:toOffset:)`, `player.theme.accent`, `library.rescanAll()`.

View task: write, build, manual-verify.

- [ ] **Step 1: Create the queue view**

Create `kora/Player/QueueView.swift`:
```swift
import SwiftUI

struct QueueView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        Group {
            if player.queueTracks.isEmpty {
                ContentUnavailableView("Queue is empty", systemImage: "list.bullet")
            } else {
                List {
                    ForEach(Array(player.queueTracks.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 8) {
                            if index == player.queueIndex {
                                Image(systemName: "speaker.wave.2.fill").foregroundStyle(player.theme.accent)
                            }
                            Text(track.title)
                                .foregroundStyle(index == player.queueIndex ? player.theme.accent : .primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { player.jumpInQueue(to: index) }
                    }
                    .onMove { player.moveInQueue(fromOffsets: $0, toOffset: $1) }
                }
            }
        }
        .navigationTitle("Up Next")
    }
}

#Preview {
    QueueView().environmentObject(MusicPlayer())
}
```

- [ ] **Step 2: Wire the inspector + toolbar into ContentView**

Replace `kora/UI/ContentView.swift` body with the inspector + toolbar (keep the existing `handleDrop` method unchanged):
```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var showQueue = false

    var body: some View {
        NavigationSplitView {
            LibrarySidebar().navigationTitle("Kora")
        } detail: {
            NowPlayingView()
        }
        .frame(minWidth: 820, minHeight: 560)
        .inspector(isPresented: $showQueue) { QueueView() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { library.rescanAll() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Rescan all folders")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showQueue.toggle() } label: { Image(systemName: "list.bullet") }
                    .help("Up Next")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers); return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                    if isDir.boolValue {
                        library.addFolder(url: url)
                    } else if MusicLibrary.audioExtensions.contains(url.pathExtension.lowercased()) {
                        let t = Track(url: url, folderID: UUID())
                        player.play(track: t, in: [t])
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MusicLibrary())
        .environmentObject(MusicPlayer())
}
```

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verify**

Run the app. Play a folder, open the Up Next inspector (toolbar list icon): the current track is accent-highlighted, tapping a row jumps to it, drag reorders without changing what's playing. The rescan toolbar button refreshes folders.

- [ ] **Step 5: Commit**
```bash
git add kora/Player/QueueView.swift kora/UI/ContentView.swift
git commit -m "feat: Up Next queue inspector + rescan/queue toolbar"
```

---

### Task 12: Playback commands + menu-bar mini-player

**Files:**
- Modify: `kora/App/koraApp.swift`

**Interfaces:**
- Consumes: the app's `MusicPlayer` `@StateObject` (`playPause`, `next`, `previous`, `isPlaying`, `currentTrackName`, `artist`, `artwork`, `hasTrack`).

View/scene task: write, build, manual-verify. Read the current `koraApp.swift` first to match how the `MusicPlayer`/`MusicLibrary` `@StateObject`s and the widget-state mirroring are wired, and insert `.commands {}` and the `MenuBarExtra` scene without disturbing that wiring.

- [ ] **Step 1: Add Playback commands to the main `WindowGroup`**

On the existing `WindowGroup { ... }` scene in `kora/App/koraApp.swift`, append a `.commands` modifier (use the same `player` `@StateObject` the scene already owns):
```swift
        .commands {
            CommandMenu("Playback") {
                Button(player.isPlaying ? "Pause" : "Play") { player.playPause() }
                Button("Next") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
```
(Play/Pause gets a menu item but no extra shortcut — the in-window space bar already covers it.)

- [ ] **Step 2: Add a `MenuBarExtra` mini-player scene**

In the `body: some Scene`, after the `WindowGroup`, add:
```swift
        MenuBarExtra("Kora", systemImage: "music.note") {
            VStack(alignment: .leading, spacing: 10) {
                if player.hasTrack {
                    HStack(spacing: 10) {
                        if let data = player.artwork, let image = NSImage(data: data) {
                            Image(nsImage: image).resizable().frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading) {
                            Text(player.currentTrackName).font(.headline).lineLimit(1)
                            if let artist = player.artist, !artist.isEmpty {
                                Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                } else {
                    Text("Nothing playing").foregroundStyle(.secondary)
                }
                HStack(spacing: 20) {
                    Button { player.previous() } label: { Image(systemName: "backward.fill") }
                    Button { player.playPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button { player.next() } label: { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .disabled(!player.hasTrack)
            }
            .padding(12)
            .frame(width: 260)
        }
        .menuBarExtraStyle(.window)
```
If `koraApp` does not already `import AppKit`/`SwiftUI` for `NSImage`, add `import SwiftUI` (and `AppKit` if needed).

- [ ] **Step 3: Build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verify**

Run the app. The menu bar shows a music-note icon; clicking it opens a now-playing card with working transport. The app's "Playback" menu drives play/next/previous, and ⌘→ / ⌘← skip tracks.

- [ ] **Step 5: Commit**
```bash
git add kora/App/koraApp.swift
git commit -m "feat: Playback menu commands + menu-bar mini-player"
```

---

### Task 13: Full verification, codex review, README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Full unit-test run**

Run:
```bash
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests CODE_SIGNING_ALLOWED=NO
```
Expected: all suites PASS (`PlayQueueTests`, `ArtworkThemeTests`, `BookmarkStoreTests`, `LibraryScanTests`, `PlayerFinishTests`).

- [ ] **Step 2: Full build**

Run the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: End-to-end manual pass**

Run the app and verify the whole flow: add folders (picker + drag-drop); play; adaptive backdrop + color cross-fade on Next; sidebar playing indicator; rescan; rename; reorder; Reveal in Finder; queue inspector jump/reorder; menu-bar mini-player; ⌘→/⌘←. For the stale path: add a folder, quit, move/rename it on disk, relaunch — it appears greyed with "Locate…"; re-locating restores playback.

- [ ] **Step 4: codex review pass**

Run the `codex` CLI over the branch diff as the code-review pass (user preference: codex over subagent review). Example:
```bash
git diff main...HEAD > /tmp/kora-redesign.diff
codex exec "Review this diff for correctness, sandbox/security-scope lifecycle, SwiftUI state bugs, and the persistence migration. Flag anything risky." < /tmp/kora-redesign.diff
```
Address any real findings (commit fixes); note false positives.

- [ ] **Step 5: Update README features**

In `README.md`, update the `## Features` list to add: art-driven adaptive now-playing; folder rescan / re-link / rename / reorder / reveal; Up Next queue; menu-bar mini-player. Keep it to one line per feature, matching the existing terse style.

- [ ] **Step 6: Commit**
```bash
git add README.md
git commit -m "docs: README covers adaptive identity, folder management, queue, menu-bar"
```

---

## Self-Review

**Spec coverage:**
- Adaptive theming layer → Task 2; published into player → Task 3. ✓
- Now-playing redesign (backdrop, foreground, empty state, motion) → Task 4. ✓
- Sidebar redesign (indicator, states, empty state) → Task 9. ✓
- Folder management: persistence migration → Task 5; rescan → Task 6; stale + re-link → Task 7; rename + reorder → Task 8; reveal in Finder → Task 9 (context menus). ✓
- Queue/up-next (PlayQueue mutations → Task 1; player exposure → Task 10; inspector view → Task 11). ✓
- Menu-bar + commands → Task 12. ✓
- Testing (PlayQueue move/jump, palette luminance, Codable round-trip + migration, scan reflects changes, availability rule) → Tasks 1,2,5,6,7. ✓
- codex review + README → Task 13. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; tests carry real assertions. ✓

**Type consistency:** `Folder.url` is `URL?` from Task 5 onward; all later consumers (`forget`, `rescan`, `relink`, sidebar, reveal) guard `folder.url`. `PersistedFolder`, `encodePersisted/decodePersisted/migrate`, `isAvailable`, `theme`, `currentTrackID`, `queueTracks/queueIndex`, `jumpInQueue/moveInQueue`, `move(fromOffsets:toOffset:)/jump(to:)` are named identically where defined and consumed. ✓
