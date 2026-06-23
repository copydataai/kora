# Kora Source Boundaries And Shared Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the source tree match the app's responsibilities and remove the duplicated app/widget now-playing JSON contract.

**Architecture:** Keep the app simple, but create physical folders for app shell, UI, library, player, and shared contracts. The now-playing JSON model and App Group path live in one shared Swift file that is compiled into both the app and widget targets.

**Tech Stack:** SwiftUI, WidgetKit, Xcode project file, Swift Testing.

---

## Files

- Create: `KoraShared/NowPlayingSnapshot.swift`
- Move: `kora/koraApp.swift` -> `kora/App/koraApp.swift`
- Move: `kora/ContentView.swift` -> `kora/UI/ContentView.swift`
- Move: `kora/LibrarySidebar.swift` -> `kora/Library/LibrarySidebar.swift`
- Move: `kora/MusicLibrary.swift` -> `kora/Library/MusicLibrary.swift`
- Move: `kora/MusicPlayer.swift` -> `kora/Player/MusicPlayer.swift`
- Move: `kora/PlayQueue.swift` -> `kora/Player/PlayQueue.swift`
- Move: `kora/Track.swift` -> `kora/Player/Track.swift`
- Move: `kora/NowPlayingView.swift` -> `kora/Player/NowPlayingView.swift`
- Move: `kora/NowPlayingState.swift` -> `kora/WidgetBridge/NowPlayingState.swift`
- Modify: `kora/WidgetBridge/NowPlayingState.swift`
- Modify: `koraWidget/KoraWidgetStateStore.swift`
- Delete: `koraWidget/KoraWidgetModels.swift`
- Modify: `kora.xcodeproj/project.pbxproj`
- Modify: `README.md`

### Task 1: Add The Shared Contract

- [ ] **Step 1: Create the shared Swift file**

Create `KoraShared/NowPlayingSnapshot.swift`:

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

- [ ] **Step 2: Add `KoraShared/NowPlayingSnapshot.swift` to both targets**

Use Xcode target membership or edit `kora.xcodeproj/project.pbxproj` so the file is compiled by both `kora` and `koraWidget`. Verify with:

```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-shared-contract-build
```

Expected before deleting duplicated code: build succeeds or fails only because symbols are duplicated.

- [ ] **Step 3: Remove duplicate model from the app bridge**

In `kora/WidgetBridge/NowPlayingState.swift`, remove the private `NowPlayingSnapshot` and `NowPlayingSharedStore` declarations. The file should keep only:

```swift
import Foundation

enum NowPlayingState {
    static func write(track: Track?, isPlaying: Bool) {
        guard let url = NowPlayingSharedStore.containerURL() else { return }
        guard let track else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let snap = NowPlayingSnapshot(
            title: track.title,
            artist: track.artist,
            isPlaying: isPlaying,
            artworkData: nil,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url)
        }
    }
}
```

- [ ] **Step 4: Remove duplicate widget model**

Delete `koraWidget/KoraWidgetModels.swift`. `koraWidget/KoraWidgetStateStore.swift` should compile against the shared `NowPlayingSnapshot` and `NowPlayingSharedStore`.

- [ ] **Step 5: Verify shared contract build**

Run:

```bash
rm -rf /tmp/kora-shared-contract-build
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-shared-contract-build
```

Expected: `** BUILD SUCCEEDED **`.

### Task 2: Move Files Into Responsibility Folders

- [ ] **Step 1: Create folders**

Create:

```text
kora/App
kora/UI
kora/Library
kora/Player
kora/WidgetBridge
```

- [ ] **Step 2: Move files**

Use Finder/Xcode or `git mv`:

```bash
git mv kora/koraApp.swift kora/App/koraApp.swift
git mv kora/ContentView.swift kora/UI/ContentView.swift
git mv kora/LibrarySidebar.swift kora/Library/LibrarySidebar.swift
git mv kora/MusicLibrary.swift kora/Library/MusicLibrary.swift
git mv kora/MusicPlayer.swift kora/Player/MusicPlayer.swift
git mv kora/PlayQueue.swift kora/Player/PlayQueue.swift
git mv kora/Track.swift kora/Player/Track.swift
git mv kora/NowPlayingView.swift kora/Player/NowPlayingView.swift
git mv kora/NowPlayingState.swift kora/WidgetBridge/NowPlayingState.swift
```

- [ ] **Step 3: Remove temporary implementation comments**

In `kora/UI/ContentView.swift`, replace the dropped-file comment with no comment. In `kora/Player/MusicPlayer.swift`, replace the finish-detection comment with:

```swift
// Timer-based finish detection keeps playback simple; use AVAudioPlayerDelegate if precision becomes necessary.
```

- [ ] **Step 4: Build after moves**

Run:

```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-boundaries-build
```

Expected: `** BUILD SUCCEEDED **`.

### Task 3: Update README Layout

- [ ] **Step 1: Replace the project layout section**

In `README.md`, replace lines under `## Project layout` with:

```markdown
- `kora/App/` - app entry and scene wiring.
- `kora/UI/` - root SwiftUI composition.
- `kora/Library/` - folder bookmarks, library scanning, and sidebar UI.
- `kora/Player/` - track model, queue logic, playback engine, and now-playing UI.
- `kora/WidgetBridge/` - app-side writes to the shared widget state file.
- `KoraShared/` - types compiled into both the app and widget targets.
- `koraWidget/` - WidgetKit extension.
- `koraTests/` - unit tests for scan, queue, bookmarks, and playback decisions.
- `koraUITests/` - launch smoke tests for the macOS app.
```

- [ ] **Step 2: Verify final build**

Run:

```bash
rm -rf /tmp/kora-boundaries-final
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/kora-boundaries-final
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add KoraShared kora koraWidget README.md kora.xcodeproj/project.pbxproj
git commit -m "refactor: organize Kora source boundaries"
```

