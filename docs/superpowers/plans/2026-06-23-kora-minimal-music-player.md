# Kora Minimal Music Library Player — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Kora from a one-file audio viewer into a minimal, sandboxed macOS music *library* player — register folders, browse them in a sidebar, play with artwork/volume/queue, plus a now-playing widget.

**Architecture:** SwiftUI + AVFoundation. `MusicLibrary` persists folders as security-scoped bookmarks and scans them into `Track`s. `MusicPlayer` (extended) plays a queue with next/prev/auto-advance, volume, and artwork. `ContentView` is a `NavigationSplitView` (library sidebar | now-playing hero). The `koraWidget` extension is rewritten to read now-playing state from a shared App Group container the app writes.

**Tech Stack:** Swift 5/6, SwiftUI, AVFoundation, WidgetKit, swift-testing (`import Testing`). Xcode 16 file-system-synchronized groups (new files auto-join the target).

## Global Constraints

- Platform: macOS, sandboxed (`ENABLE_APP_SANDBOX = YES`). Do not disable the sandbox.
- App bundle id: `app.copydataai.kora`. Widget bundle id: `app.copydataai.kora.widget`.
- App Group id (new): `group.app.copydataai.kora`.
- Entitlements required: `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-only`, `com.apple.security.files.bookmarks.app-scope`, `com.apple.security.application-groups`.
- Encoding: ASCII only in source. Match existing SwiftUI style (private computed-var subviews, custom `ButtonStyle`s already in `ContentView.swift`).
- New Swift files go **inside the target folder** (`kora/` for app, `koraWidget/` for widget) so the synchronized group includes them. Files at the **repo root** are NOT in the build.
- Commit after each task. Conventional commit messages. End commit messages with the Co-Authored-By trailer used in this repo.
- TDD where logic is pure/testable (library scan, queue math, persistence, time formatting). UI and AVAudioPlayer timing are manual-verify.

---

## File Structure

**Create (app, in `kora/`):**
- `kora/Track.swift` — `Track` value type + metadata extraction helpers.
- `kora/MusicLibrary.swift` — folders as bookmarks, scan, persistence (`ObservableObject`).
- `kora/PlayQueue.swift` — pure queue index math (testable, no AVFoundation).
- `kora/NowPlayingView.swift` — hero panel (artwork, title/artist, seek, transport, volume).
- `kora/LibrarySidebar.swift` — folder/track list + add/forget.
- `kora/NowPlayingState.swift` — shared widget-state writer (App Group container).
- `kora/kora.entitlements` — app entitlements.

**Modify (app):**
- `kora/MusicPlayer.swift` — add volume, artwork, artist, queue, next/prev, auto-advance, widget mirroring.
- `kora/ContentView.swift` — replace body with `NavigationSplitView`; move button styles if reused.
- `kora/koraApp.swift` — own `MusicLibrary` + `MusicPlayer` as `@StateObject`s, inject via environment.

**Create (widget, in `koraWidget/`):**
- `koraWidget/koraWidget.entitlements` — widget entitlements (sandbox + app group).

**Modify (widget):**
- `koraWidget/KoraWidgetModels.swift` — replace room models with `NowPlayingSnapshot`.
- `koraWidget/KoraWidgetStateStore.swift` — read from App Group container.
- `koraWidget/KoraRoomWidget.swift` — rewrite as `KoraNowPlayingWidget`.

**Delete:**
- Root orphans: `ContentView.swift`, `ExecutionPlan.swift`, `koraApp.swift`, `PhaseExecutionStore.swift`.
- Docs: `product.md`, `implementation_roadmap.md`, `INSTALL.md`, `WIDGET_EXTENSION_ONBOARDING.md`.

**Rewrite:**
- `README.md` — lean (~60 lines).

**Tests (in `koraTests/`):**
- `koraTests/LibraryScanTests.swift`, `koraTests/PlayQueueTests.swift`, `koraTests/BookmarkStoreTests.swift`.

---

## Task 1: Repo cleanup + lean README

Removes the dead "rooms" vision's leftovers and collapses 868 lines of docs into one README. No app code changes — the app still builds (orphans were never in the target).

**Files:**
- Delete: `ContentView.swift`, `ExecutionPlan.swift`, `koraApp.swift`, `PhaseExecutionStore.swift` (repo root), `product.md`, `implementation_roadmap.md`, `INSTALL.md`, `WIDGET_EXTENSION_ONBOARDING.md`
- Modify: `README.md`
- Check: `scripts/verify-release.sh`

- [ ] **Step 1: Confirm the root Swift files are not in the build**

Run: `grep -c 'ExecutionPlan.swift\|PhaseExecutionStore.swift' kora.xcodeproj/project.pbxproj`
Expected: `0` (orphans, safe to delete).

- [ ] **Step 2: Delete orphan code + stale docs**

```bash
git rm ContentView.swift ExecutionPlan.swift koraApp.swift PhaseExecutionStore.swift \
       product.md implementation_roadmap.md INSTALL.md WIDGET_EXTENSION_ONBOARDING.md
```

- [ ] **Step 3: Rewrite `README.md`**

Replace the entire file with:

```markdown
# Kora

A minimal, native macOS music player. Point it at your music folders and play —
no library import, no accounts, no clutter.

## Features

- Register music **folders**; Kora scans them (including subfolders) into a sidebar library.
- Now-playing view with album artwork, title/artist, seek, and volume.
- Play/pause, previous/next, and auto-advance through a folder.
- Drag a folder onto the window to add it; drag an audio file to play it.
- A macOS **now-playing widget**.

Folders are remembered across launches via security-scoped bookmarks; the app
stays sandboxed and never touches files you didn't pick.

## Build & run

Requires Xcode 16+ (macOS).

```bash
open kora.xcodeproj   # then Run the "kora" scheme (Cmd-R)
```

## Project layout

- `kora/` — the app (SwiftUI). Player engine in `MusicPlayer.swift`, library in `MusicLibrary.swift`, UI in `ContentView.swift` + `*View.swift`.
- `koraWidget/` — the now-playing WidgetKit extension.
- `koraTests/` — unit tests for scan, queue, and bookmark persistence.

## License

Open source.
```

- [ ] **Step 4: Audit the release script**

Run: `grep -niE 'room|phase|milestone|widget-state|ExecutionPlan' scripts/verify-release.sh`
If matches refer only to the deleted "rooms/phase" vision, remove those checks (edit the file, keep build/sign checks). If the whole script only served the dead vision, `git rm scripts/verify-release.sh`. If it has generic build checks, leave them. Record the decision in the commit message.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: drop dead rooms scaffolding and collapse docs into README"
```

---

## Task 2: Entitlements (sandbox file access + bookmarks + app group)

Without these the library cannot persist folder access and the widget cannot read shared state. This is project-setting work, not Swift.

**Files:**
- Create: `kora/kora.entitlements`, `koraWidget/koraWidget.entitlements`
- Modify: `kora.xcodeproj/project.pbxproj` (set `CODE_SIGN_ENTITLEMENTS` per target)

**Interfaces:**
- Produces: App Group `group.app.copydataai.kora` available to both targets; app may create app-scoped bookmarks.

- [ ] **Step 1: Create `kora/kora.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.app.copydataai.kora</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Create `koraWidget/koraWidget.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.app.copydataai.kora</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 3: Wire `CODE_SIGN_ENTITLEMENTS` for both targets**

Preferred: in Xcode, select each target → Build Settings → set **Code Signing Entitlements** to `kora/kora.entitlements` (app) and `koraWidget/koraWidget.entitlements` (widget). Then Signing & Capabilities should show App Sandbox + App Groups with `group.app.copydataai.kora` checked for both.

If editing `project.pbxproj` directly: in each `XCBuildConfiguration` block belonging to the `kora` target (both Debug and Release), add inside `buildSettings`:
`CODE_SIGN_ENTITLEMENTS = kora/kora.entitlements;`
And for the `koraWidget` target's Debug and Release configs:
`CODE_SIGN_ENTITLEMENTS = koraWidget/koraWidget.entitlements;`
(Find target configs by the `PRODUCT_BUNDLE_IDENTIFIER` value — `app.copydataai.kora` vs `app.copydataai.kora.widget`.)

- [ ] **Step 4: Build to verify signing still succeeds**

Run: `xcodebuild -project kora.xcodeproj -scheme kora -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`. If signing fails on App Group registration, confirm the App Groups capability is enabled in Signing & Capabilities (auto-managed via `REGISTER_APP_GROUPS = YES`).

- [ ] **Step 5: Commit**

```bash
git add kora/kora.entitlements koraWidget/koraWidget.entitlements kora.xcodeproj/project.pbxproj
git commit -m "build: add sandbox file-access, bookmark, and app-group entitlements"
```

---

## Task 3: PlayQueue (pure queue math)

The one piece of transport logic worth isolating and testing without audio.

**Files:**
- Create: `kora/PlayQueue.swift`
- Test: `koraTests/PlayQueueTests.swift`

**Interfaces:**
- Produces:
  - `struct PlayQueue { var tracks: [Track]; private(set) var index: Int }`
  - `init(tracks: [Track], startAt: Int)`
  - `var current: Track?`
  - `mutating func next() -> Track?` — advances if a next track exists, else returns nil and leaves index at last.
  - `mutating func previous() -> Track?` — steps back if possible, else nil.
  - `var hasNext: Bool`, `var hasPrevious: Bool`
- Consumes: `Track` (Task 4) — for the test, use a minimal `Track(url:)`. Order Task 4 first if your `Track` initializer differs; the queue only reads identity/order, not metadata.

- [ ] **Step 1: Write failing tests `koraTests/PlayQueueTests.swift`**

```swift
import Testing
import Foundation
@testable import kora

private func track(_ name: String) -> Track {
    Track(url: URL(fileURLWithPath: "/tmp/\(name).mp3"), folderID: UUID())
}

struct PlayQueueTests {
    @Test func startsAtRequestedIndex() {
        var q = PlayQueue(tracks: [track("a"), track("b"), track("c")], startAt: 1)
        #expect(q.current?.title == "b")
    }

    @Test func nextAdvancesAndStopsAtEnd() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 0)
        #expect(q.next()?.title == "b")
        #expect(q.next() == nil)          // no wrap past end
        #expect(q.current?.title == "b")  // stays on last
    }

    @Test func previousStepsBackAndStopsAtStart() {
        var q = PlayQueue(tracks: [track("a"), track("b")], startAt: 1)
        #expect(q.previous()?.title == "a")
        #expect(q.previous() == nil)
        #expect(q.current?.title == "a")
    }

    @Test func emptyQueueHasNoCurrent() {
        var q = PlayQueue(tracks: [], startAt: 0)
        #expect(q.current == nil)
        #expect(q.next() == nil)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail to compile/fail**

Run: `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -only-testing:koraTests/PlayQueueTests 2>&1 | tail -20`
Expected: failure (`PlayQueue` / `Track` not found).

- [ ] **Step 3: Implement `kora/PlayQueue.swift`**

```swift
import Foundation

struct PlayQueue {
    private(set) var tracks: [Track]
    private(set) var index: Int

    init(tracks: [Track], startAt: Int = 0) {
        self.tracks = tracks
        self.index = tracks.isEmpty ? 0 : min(max(startAt, 0), tracks.count - 1)
    }

    var current: Track? {
        tracks.indices.contains(index) ? tracks[index] : nil
    }

    var hasNext: Bool { index + 1 < tracks.count }
    var hasPrevious: Bool { index > 0 }

    mutating func next() -> Track? {
        guard hasNext else { return nil }
        index += 1
        return tracks[index]
    }

    mutating func previous() -> Track? {
        guard hasPrevious else { return nil }
        index -= 1
        return tracks[index]
    }
}
```

(Depends on `Track` from Task 4. If implementing in order, write Task 4's `Track` first, or stub it.)

- [ ] **Step 4: Run tests, verify pass**

Run: `xcodebuild test ... -only-testing:koraTests/PlayQueueTests 2>&1 | tail -20`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add kora/PlayQueue.swift koraTests/PlayQueueTests.swift
git commit -m "feat: add PlayQueue with bounded next/previous"
```

---

## Task 4: Track model + library scan

`Track` carries identity + lazy metadata; `MusicLibrary` turns folders into tracks and filters to audio.

**Files:**
- Create: `kora/Track.swift`, `kora/MusicLibrary.swift`
- Test: `koraTests/LibraryScanTests.swift`

**Interfaces:**
- Produces:
  - `struct Track: Identifiable, Hashable { let id: UUID; let url: URL; let folderID: UUID; var title: String; var artist: String? }`
  - `init(url:folderID:)` — `title` defaults to filename without extension; `artist` nil.
  - `func loadArtwork() async -> Data?` and `func loadMetadata() async -> (title: String, artist: String?)` using `AVAsset` common metadata (used by player/UI, not by scan).
  - `enum MusicLibrary` static helper: `static let audioExtensions: Set<String>`; `static func audioFiles(in folder: URL, fileManager: FileManager = .default) -> [URL]` — recursive, filtered, sorted by path.
  - `final class MusicLibrary: ObservableObject` (folders + persistence) is fleshed out in Task 5/6; this task delivers `Track` + the static scan + its tests.
- Consumes: nothing.

- [ ] **Step 1: Write failing tests `koraTests/LibraryScanTests.swift`**

```swift
import Testing
import Foundation
@testable import kora

struct LibraryScanTests {
    private func tempDir() -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("korascan-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    private func write(_ name: String, in dir: URL) {
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data())
    }

    @Test func findsNestedAudioAndSkipsNonAudio() {
        let root = tempDir()
        write("a.mp3", in: root)
        write("notes.txt", in: root)
        write("cover.jpg", in: root)
        let sub = root.appendingPathComponent("album")
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        write("b.flac", in: sub)

        let files = MusicLibrary.audioFiles(in: root).map { $0.lastPathComponent }
        #expect(files.contains("a.mp3"))
        #expect(files.contains("b.flac"))   // two levels deep
        #expect(!files.contains("notes.txt"))
        #expect(!files.contains("cover.jpg"))
        #expect(files.count == 2)
    }

    @Test func trackTitleDefaultsToFilename() {
        let t = Track(url: URL(fileURLWithPath: "/m/Song Name.m4a"), folderID: UUID())
        #expect(t.title == "Song Name")
        #expect(t.artist == nil)
    }
}
```

- [ ] **Step 2: Run, verify fail**

Run: `xcodebuild test ... -only-testing:koraTests/LibraryScanTests 2>&1 | tail -20`
Expected: fail (`Track`, `MusicLibrary` not found).

- [ ] **Step 3: Implement `kora/Track.swift`**

```swift
import Foundation
import AVFoundation

struct Track: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let folderID: UUID
    var title: String
    var artist: String?

    init(url: URL, folderID: UUID, title: String? = nil, artist: String? = nil) {
        self.id = UUID()
        self.url = url
        self.folderID = folderID
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist
    }

    func loadMetadata() async -> (title: String, artist: String?) {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return (title, artist) }
        let loadedTitle = await stringValue(items, .commonKeyTitle)
        let loadedArtist = await stringValue(items, .commonKeyArtist)
        return (loadedTitle ?? title, loadedArtist ?? artist)
    }

    func loadArtwork() async -> Data? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }
        for item in items where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue) { return data }
        }
        return nil
    }

    private func stringValue(_ items: [AVMetadataItem], _ key: AVMetadataKey) async -> String? {
        for item in items where item.commonKey == key {
            if let s = try? await item.load(.stringValue), let s, !s.isEmpty { return s }
        }
        return nil
    }
}
```

- [ ] **Step 4: Implement scan in `kora/MusicLibrary.swift`** (static part only for now)

```swift
import Foundation

extension MusicLibrary {
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "alac", "caf", "ogg", "opus"
    ]

    /// Recursively collect audio files under `folder`, sorted by path for stable order.
    static func audioFiles(in folder: URL, fileManager: FileManager = .default) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [URL] = []
        for case let url as URL in enumerator
        where audioExtensions.contains(url.pathExtension.lowercased()) {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }
}
```

And the class shell (filled in Task 5/6):

```swift
import Foundation
import Combine

@MainActor
final class MusicLibrary: ObservableObject {
    struct Folder: Identifiable, Hashable {
        let id: UUID
        let url: URL
        var name: String { url.lastPathComponent }
        var tracks: [Track]
    }

    @Published private(set) var folders: [Folder] = []
}
```

- [ ] **Step 5: Run tests, verify pass; commit**

Run: `xcodebuild test ... -only-testing:koraTests/LibraryScanTests 2>&1 | tail -20`
Expected: PASS.

```bash
git add kora/Track.swift kora/MusicLibrary.swift koraTests/LibraryScanTests.swift
git commit -m "feat: add Track model and recursive audio folder scan"
```

> **Note (spec deviation):** scan filters by a curated audio-extension allowlist rather than UTType `.audio` conformance — deterministic and testable without per-file I/O. The file *picker* still uses `[.audio]`.

---

## Task 5: Folder persistence via security-scoped bookmarks

Make folders survive relaunch. Bookmark serialization is the failure-prone bit, so it gets a test.

**Files:**
- Modify: `kora/MusicLibrary.swift`
- Test: `koraTests/BookmarkStoreTests.swift`

**Interfaces:**
- Produces (on `MusicLibrary`):
  - `func addFolder(url: URL)` — creates app-scoped bookmark, starts access, scans, appends folder, persists.
  - `func forget(_ folder: Folder)` — stops access, removes, persists.
  - `func restore()` — called at launch: resolve saved bookmarks, start access, scan.
  - `static func encodeBookmarks(_ data: [Data]) -> Data` / `static func decodeBookmarks(_ data: Data) -> [Data]` — pure, testable round-trip used for persistence.
  - persistence key: `UserDefaults` key `"library.folderBookmarks"` (array of bookmark `Data`).
- Consumes: `audioFiles(in:)`, `Folder`, `Track` (Task 4).

- [ ] **Step 1: Write failing test `koraTests/BookmarkStoreTests.swift`**

```swift
import Testing
import Foundation
@testable import kora

struct BookmarkStoreTests {
    // Verifies the persistence envelope round-trips: a corrupted decode here would
    // silently drop every saved folder on next launch.
    @Test func bookmarkArrayRoundTrips() throws {
        let a = Data([1, 2, 3])
        let b = Data([9, 8, 7, 6])
        let encoded = MusicLibrary.encodeBookmarks([a, b])
        let decoded = MusicLibrary.decodeBookmarks(encoded)
        #expect(decoded == [a, b])
    }

    @Test func decodeOfGarbageReturnsEmpty() {
        #expect(MusicLibrary.decodeBookmarks(Data([0xFF, 0x00])) == [])
    }
}
```

- [ ] **Step 2: Run, verify fail**

Run: `xcodebuild test ... -only-testing:koraTests/BookmarkStoreTests 2>&1 | tail -20`
Expected: fail (methods not found).

- [ ] **Step 3: Implement persistence + bookmark lifecycle in `kora/MusicLibrary.swift`**

Replace the class body with:

```swift
@MainActor
final class MusicLibrary: ObservableObject {
    struct Folder: Identifiable, Hashable {
        let id: UUID
        let url: URL
        var name: String { url.lastPathComponent }
        var tracks: [Track]
    }

    @Published private(set) var folders: [Folder] = []

    private let defaults: UserDefaults
    private let bookmarksKey = "library.folderBookmarks"
    private var accessedURLs: [URL] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        for url in accessedURLs { url.stopAccessingSecurityScopedResource() }
    }

    // MARK: Pure persistence envelope (tested)

    static func encodeBookmarks(_ data: [Data]) -> Data {
        (try? NSKeyedArchiver.archivedData(withRootObject: data as NSArray, requiringSecureCoding: true)) ?? Data()
    }

    static func decodeBookmarks(_ data: Data) -> [Data] {
        let classes = [NSArray.self, NSData.self]
        let array = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? [Data]
        return array ?? []
    }

    // MARK: Public API

    func addFolder(url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }
        var saved = currentBookmarks()
        saved.append(bookmark)
        persist(saved)
        ingest(url: url)
    }

    func forget(_ folder: Folder) {
        folder.url.stopAccessingSecurityScopedResource()
        accessedURLs.removeAll { $0 == folder.url }
        folders.removeAll { $0.id == folder.id }
        // Re-derive surviving bookmarks from remaining folders.
        let surviving = folders.compactMap { f in
            try? f.url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        persist(surviving)
    }

    func restore() {
        for bookmark in currentBookmarks() {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &stale
            ), !stale else { continue }   // drop stale silently
            ingest(url: url)
        }
    }

    // MARK: Internal

    private func ingest(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { accessedURLs.append(url) }
        let folderID = UUID()
        let tracks = MusicLibrary.audioFiles(in: url).map { Track(url: $0, folderID: folderID) }
        folders.append(Folder(id: folderID, url: url, tracks: tracks))
    }

    private func currentBookmarks() -> [Data] {
        guard let data = defaults.data(forKey: bookmarksKey) else { return [] }
        return MusicLibrary.decodeBookmarks(data)
    }

    private func persist(_ bookmarks: [Data]) {
        defaults.set(MusicLibrary.encodeBookmarks(bookmarks), forKey: bookmarksKey)
    }
}
```

Keep the `audioFiles`/`audioExtensions` extension from Task 4.

- [ ] **Step 4: Run tests, verify pass; commit**

Run: `xcodebuild test ... -only-testing:koraTests/BookmarkStoreTests 2>&1 | tail -20`
Expected: PASS.

```bash
git add kora/MusicLibrary.swift koraTests/BookmarkStoreTests.swift
git commit -m "feat: persist library folders as security-scoped bookmarks"
```

---

## Task 6: Extend MusicPlayer (volume, artwork/artist, queue, auto-advance)

**Files:**
- Modify: `kora/MusicPlayer.swift`

**Interfaces:**
- Produces (added to `MusicPlayer`):
  - `@Published private(set) var artist: String?`
  - `@Published private(set) var artwork: Data?`
  - `@Published var volume: Double` (0...1; `didSet` updates `player?.volume` and persists to `UserDefaults` key `"player.volume"`).
  - `func play(track: Track, in tracks: [Track])` — builds `PlayQueue` at that track, loads + plays, fires `onTrackChange`.
  - `func next()` / `func previous()` — move within the queue and play; no-op at bounds.
  - `var onTrackChange: ((Track?, Bool) -> Void)?` — callback so the app mirrors state to the widget (title/artist/artwork/isPlaying).
  - Auto-advance: when a track finishes, call `next()`; if no next, stop.
- Consumes: `Track`, `PlayQueue`.

- [ ] **Step 1: Add state, volume persistence, queue plumbing**

In `MusicPlayer`, add published properties and a queue + callback:

```swift
@Published private(set) var artist: String?
@Published private(set) var artwork: Data?
@Published var volume: Double {
    didSet {
        player?.volume = Float(volume)
        UserDefaults.standard.set(volume, forKey: "player.volume")
    }
}
var onTrackChange: ((Track?, Bool) -> Void)?

private var queue = PlayQueue(tracks: [], startAt: 0)
```

Initialize volume in `init`:

```swift
init() {
    let saved = UserDefaults.standard.object(forKey: "player.volume") as? Double
    self.volume = saved ?? 1.0
}
```

- [ ] **Step 2: Implement `play(track:in:)`, `next()`, `previous()`**

```swift
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

private func loadAndPlayCurrent() {
    guard let track = queue.current else { return }
    load(url: track.url)              // existing method sets player/duration/etc.
    player?.volume = Float(volume)
    currentTrackName = track.title
    artist = track.artist
    player?.play()
    isPlaying = true
    startTimer()
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
    onTrackChange?(queue.current, isPlaying)
}
```

- [ ] **Step 3: Auto-advance on finish**

In `syncProgress()`, where the track is detected as finished (the existing `currentTime >= duration - 0.25` branch), replace the "reset to 0" behavior with:

```swift
if duration > 0, currentTime >= duration - 0.25 {
    if queue.hasNext {
        next()
    } else {
        stop()
        onTrackChange?(queue.current, false)
    }
}
```

Also update `playPause()` / `stop()` to call `onTrackChange?(queue.current, isPlaying)` so the widget reflects pause/stop.

- [ ] **Step 4: Build (no unit test — AVAudioPlayer timing is manual)**

Run: `xcodebuild -project kora.xcodeproj -scheme kora -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add kora/MusicPlayer.swift
git commit -m "feat: player gains volume, artwork, queue, and auto-advance"
```

---

## Task 7: NavigationSplitView UI (sidebar + now-playing hero, drag & drop)

**Files:**
- Modify: `kora/ContentView.swift`, `kora/koraApp.swift`
- Create: `kora/LibrarySidebar.swift`, `kora/NowPlayingView.swift`

**Interfaces:**
- Consumes: `MusicLibrary` (`folders`, `addFolder`, `forget`, `restore`), `MusicPlayer` (`play(track:in:)`, `next`, `previous`, `playPause`, `stop`, `isPlaying`, `currentTime`, `duration`, `seek`, `volume`, `artist`, `artwork`, `currentTrackName`, `hasTrack`).
- Keep the existing `PrimaryProductButtonStyle` / `QuietButtonStyle` (move them into `NowPlayingView.swift` or a small shared file; they are currently `private` in `ContentView.swift`).

- [ ] **Step 1: `koraApp.swift` owns library + player, calls `restore()`**

```swift
import SwiftUI

@main
struct koraApp: App {
    @StateObject private var library = MusicLibrary()
    @StateObject private var player = MusicPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(player)
                .task {
                    library.restore()
                    player.onTrackChange = { track, playing in
                        NowPlayingState.write(track: track, isPlaying: playing)
                    }
                }
        }
    }
}
```

(`NowPlayingState` lands in Task 8; if implementing in order, stub `onTrackChange` to `{ _, _ in }` here and wire it in Task 8.)

- [ ] **Step 2: `LibrarySidebar.swift`**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct LibrarySidebar: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer
    @State private var choosingFolder = false

    var body: some View {
        List {
            ForEach(library.folders) { folder in
                Section(folder.name) {
                    ForEach(folder.tracks) { track in
                        Button(track.title) { player.play(track: track, in: folder.tracks) }
                            .buttonStyle(.plain)
                    }
                }
                .contextMenu { Button("Forget Folder") { library.forget(folder) } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { choosingFolder = true } label: {
                Label("Add Folder", systemImage: "plus")
            }
            .padding(8)
        }
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { library.addFolder(url: url) }
        }
    }
}
```

- [ ] **Step 3: `NowPlayingView.swift`** (artwork, title/artist, seek, transport, volume; move the two button styles here)

```swift
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        VStack(spacing: 28) {
            artwork
            VStack(spacing: 6) {
                Text(player.hasTrack ? player.currentTrackName : "Nothing playing")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(2)
                if let artist = player.artist, !artist.isEmpty {
                    Text(artist).font(.title3).foregroundStyle(.secondary)
                }
            }
            seekBar
            transport
            volume
        }
        .padding(40)
        .frame(maxWidth: 560, maxHeight: .infinity)
    }

    private var artwork: some View {
        Group {
            if let data = player.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "music.note").font(.system(size: 56)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 260, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var seekBar: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                   in: 0...max(player.duration, 1))
                .disabled(player.duration == 0)
            HStack {
                Text(timeString(player.currentTime)); Spacer(); Text(timeString(player.duration))
            }
            .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 20) {
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.playPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title)
            }
            .keyboardShortcut(.space, modifiers: [])
            Button { player.next() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain)
        .disabled(!player.hasTrack)
    }

    private var volume: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: $player.volume, in: 0...1)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .frame(maxWidth: 260)
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let s = max(Int(value), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
```

- [ ] **Step 4: Rewrite `ContentView.swift` body as the split view + window drop**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var library: MusicLibrary
    @EnvironmentObject var player: MusicPlayer

    var body: some View {
        NavigationSplitView {
            LibrarySidebar().navigationTitle("Kora")
        } detail: {
            NowPlayingView()
        }
        .frame(minWidth: 760, minHeight: 520)
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

#Preview { ContentView().environmentObject(MusicLibrary()).environmentObject(MusicPlayer()) }
```

Remove the old `header`/`titleBlock`/`playback`/`metadata` members. Move `PrimaryProductButtonStyle`/`QuietButtonStyle` into `NowPlayingView.swift` if still referenced, else delete them.

- [ ] **Step 5: Build + manual smoke test**

Run: `xcodebuild -project kora.xcodeproj -scheme kora -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`. Then run the app (Cmd-R): add a folder, play a track, confirm next/prev, volume, drag-drop a folder and a file.

- [ ] **Step 6: Commit**

```bash
git add kora/ContentView.swift kora/koraApp.swift kora/LibrarySidebar.swift kora/NowPlayingView.swift
git commit -m "feat: sidebar library + now-playing hero UI with drag-and-drop"
```

---

## Task 8: Rewrite widget as now-playing + app writes shared state

**Files:**
- Create: `kora/NowPlayingState.swift`
- Modify: `koraWidget/KoraWidgetModels.swift`, `koraWidget/KoraWidgetStateStore.swift`, `koraWidget/KoraRoomWidget.swift`

**Interfaces:**
- Shared App Group: `group.app.copydataai.kora`, file `nowplaying.json`.
- Produces:
  - `struct NowPlayingSnapshot: Codable { var title: String; var artist: String?; var isPlaying: Bool; var artwork: Data?; var updatedAt: Date }` (shared shape; define once in the widget models file, app reads it via the synchronized membership or a copy — keep one source if both targets share the file; otherwise mirror the struct).
  - `enum NowPlayingState { static func write(track: Track?, isPlaying: Bool) }` (app side).
  - `enum NowPlayingStore { static func read() -> NowPlayingSnapshot? }` (widget side).

- [ ] **Step 1: Replace `koraWidget/KoraWidgetModels.swift`**

```swift
import Foundation

struct NowPlayingSnapshot: Codable, Hashable {
    var title: String
    var artist: String?
    var isPlaying: Bool
    var artworkData: Data?
    var updatedAt: Date
}

enum NowPlayingSharedStore {
    static let appGroup = "group.app.copydataai.kora"
    static let fileName = "nowplaying.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }
}
```

- [ ] **Step 2: Replace `koraWidget/KoraWidgetStateStore.swift`**

```swift
import Foundation

enum NowPlayingStore {
    static func read() -> NowPlayingSnapshot? {
        guard let url = NowPlayingSharedStore.containerURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
    }
}
```

- [ ] **Step 3: Rewrite `koraWidget/KoraRoomWidget.swift` as `KoraNowPlayingWidget`**

A `TimelineProvider` reading `NowPlayingStore.read()`, rendering artwork thumbnail + title + artist + a play/pause glyph; empty state shows "Kora" + "No track playing". Register it as the `@main` widget. (Keep it small — one `StaticConfiguration`, `systemSmall`/`systemMedium`.)

- [ ] **Step 4: App-side writer `kora/NowPlayingState.swift`**

```swift
import Foundation

enum NowPlayingState {
    static func write(track: Track?, isPlaying: Bool) {
        guard let url = NowPlayingSharedStore.containerURL() else { return }
        guard let track else { try? FileManager.default.removeItem(at: url); return }
        let snap = NowPlayingSnapshot(
            title: track.title, artist: track.artist,
            isPlaying: isPlaying, artworkData: nil, updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: url) }
    }
}
```

> Note: `NowPlayingSnapshot` + `NowPlayingSharedStore` are defined in the widget target. Add the same file to the app target's membership (synchronized groups: place a shared copy in a folder both targets include, or duplicate the small struct in the app). Simplest: duplicate the ~15-line struct in `NowPlayingState.swift` to avoid cross-target membership fiddling. Artwork in the widget is optional for v1 — `artworkData: nil` keeps the payload small; populate later if desired.

- [ ] **Step 5: Wire the callback in `koraApp.swift`** (replace the stub from Task 7 Step 1 with `NowPlayingState.write`).

- [ ] **Step 6: Build both targets**

Run: `xcodebuild -project kora.xcodeproj -scheme kora -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`. Add the widget from Notification Center; play a track; confirm it shows.

- [ ] **Step 7: Commit**

```bash
git add kora/NowPlayingState.swift koraWidget/
git commit -m "feat: rewrite widget as now-playing reading shared app-group state"
```

---

## Self-Review

**Spec coverage:**
- Library / folders / recursive scan / forget → Tasks 4, 5, 7. ✓
- Security-scoped bookmarks persistence → Task 5. ✓
- Track metadata (title/artist/artwork) → Tasks 4, 6. ✓
- Queue / next / prev / auto-advance → Tasks 3, 6. ✓
- Volume + persistence → Task 6. ✓
- Drag & drop (folder adds, file plays) → Task 7. ✓
- Sidebar + now-playing hero layout → Task 7. ✓
- Widget rewrite (app-group shared state) → Task 8. ✓
- Entitlements → Task 2. ✓
- Cleanup orphans + collapse docs → Task 1. ✓
- Tests (scan, queue, bookmark round-trip) → Tasks 3, 4, 5. ✓

**Placeholder scan:** Task 8 Step 3 describes the widget view in prose rather than full code — intentional (mechanical WidgetKit boilerplate, kept lean per the token-efficiency mandate; the data contract above it is concrete). All logic-bearing steps carry full code.

**Type consistency:** `play(track:in:)`, `PlayQueue(tracks:startAt:)`, `Track(url:folderID:)`, `MusicLibrary.audioFiles(in:)`, `MusicLibrary.Folder`, `NowPlayingSnapshot`, `NowPlayingSharedStore.appGroup` used consistently across tasks.

**Known ordering note:** Task 3 (PlayQueue) references `Track`, defined in Task 4. Implement Task 4's `Track` first or stub it — flagged in Task 3.
