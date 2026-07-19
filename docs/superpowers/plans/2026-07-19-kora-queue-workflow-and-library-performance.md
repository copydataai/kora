# Kora Queue Workflow and Library Performance Plan

> **For agentic workers:** Implement task-by-task. Do not begin a gated task
> until its gate is met. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the useful workflow lessons from MPD/ncmpcpp without changing
Kora into a server: make Up Next honest and efficient, add explicit queue
actions and native commands, then measure before adding library infrastructure.

**Architecture:** Keep `PlayQueue` as the single owner of queue order and index
math, `MusicPlayer` as its thin observable playback facade, and SwiftUI as the
command surface. Folders remain the library and the playlists. No daemon,
protocol, database, or dependency is introduced by the committed queue work.

**Tech stack:** Swift, SwiftUI, AVFoundation, Swift Testing, `xcodebuild`.

## Audited current contracts

- `QueueView` renders only `queueTracks.dropFirst(queueIndex + 1)` in its
  **Up Next** section. Its `.onDelete` offsets are therefore relative to that
  slice; `PlayQueue.removeUpcoming` already translates them by `index + 1`.
- `PlayQueue.move(fromOffsets:toOffset:)` instead accepts absolute full-queue
  indices. Its only production caller is
  `MusicPlayer.moveInQueue(fromOffsets:toOffset:)`; its only other callers are
  two tests that exercise moving the current/past portion of the queue.
- `QueueView` has no `.onMove`, despite the approved design and README promising
  drag reorder. The fix belongs at the shared queue boundary, not in the view.
- Every queue mutation reaches `MusicPlayer.syncQueue()`, which republishes
  `queueTracks`/`queueIndex` and persists the session. Keep that path.
- `LibrarySidebar.trackRow` is shared by folder rows and search results. Its
  existing context menu is the smallest native place to expose track-specific
  queue actions once for both surfaces.
- `koraApp` already owns the app-wide `MusicPlayer` and the Playback menu.
  `ContentView` alone owns inspector presentation state.
- `MusicLibrary.restore()` already rescans every available folder on a fresh app
  launch. While the process remains alive, changes require the existing manual
  per-folder or all-folder rescan.
- `MusicLibrary.scan` runs off the main actor but loads common metadata for every
  file sequentially. A metadata cache is only useful if measurement shows those
  loads, rather than enumeration, dominate an unacceptable scan time.

## Global constraints

- Preserve the approved product identity: **folders are the playlists**.
- The current track and all history at indices `0...queue.index` are fixed while
  dragging Up Next. SwiftUI supplies both source offsets and destination as
  coordinates in the displayed upcoming slice.
- Queue actions never interrupt or replace the current AVPlayer item.
- Queue entries remain unique by `Track.ID`. If an existing entry is queued
  again, reposition it; do not create duplicate SwiftUI identities.
- Manual queue edits made while shuffle is on must not disappear when shuffle
  is turned off. Once the user edits visible order, that visible order becomes
  authoritative and the pre-shuffle snapshot is discarded.
- Use native SwiftUI menus, shortcuts, `.onMove`, and `.onDelete`. Do not add a
  command bus, notification indirection, selection coordinator, or dependency.
- New `.swift` files are unnecessary for the committed work. Do not edit
  `project.pbxproj`.
- Run unit tests serially:
  `xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:koraTests`
- Build with:
  `xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'`
- Match the current 4-space Swift style and touch only the files named per task.

---

### Task 1: Repair upcoming-only drag reorder

**Files:**
- Modify: `kora/Player/PlayQueue.swift`
- Modify: `kora/Player/MusicPlayer.swift`
- Modify: `kora/Player/QueueView.swift`
- Test: `koraTests/PlayQueueTests.swift`

**Contract:** Replace the overly broad full-queue move surface with
`moveUpcoming(fromOffsets:toOffset:)`. Both arguments are relative to the
visible upcoming slice. Inside `PlayQueue`, calculate `base = index + 1`, map
every source offset to `base + offset`, map the destination to
`base + destination`, then call the existing native `Array.move`. A constant
translation preserves SwiftUI's insertion semantics, including destination
equal to the upcoming count.

- [ ] **Step 1: Replace the old move tests with the real view contract**

  Add one focused test with `[a, b, c, d, e]`, current `b`, source offset `0`,
  and destination `3`. Expect `[a, b, d, e, c]`, current `b`, and index `1`.
  This fails if relative offsets are accidentally treated as absolute and
  proves history/current cannot move.

- [ ] **Step 2: Replace `PlayQueue.move` with `moveUpcoming`**

  Translate offsets exactly once in `PlayQueue`. Remove the generic absolute
  method; no remaining caller needs permission to move history or current.
  After the move, invalidate any pre-shuffle snapshot as described in Task 2's
  shared mutation rule.

- [ ] **Step 3: Rename the `MusicPlayer` passthrough and wire the view**

  Rename `moveInQueue` to `moveUpcoming`, keep its single `syncQueue()` call,
  and add `.onMove(perform: player.moveUpcoming)` beside the existing
  `.onDelete` on the Up Next `ForEach`.

- [ ] **Step 4: Verify**

  Run `PlayQueueTests`, then launch Kora with a queue whose current track is not
  first. Drag the first upcoming track to the end and back. The current track,
  elapsed playback, and history stay unchanged; relaunch restores the new order.

- [ ] **Step 5: Commit**

  ```bash
  git add kora/Player/PlayQueue.swift kora/Player/MusicPlayer.swift \
    kora/Player/QueueView.swift koraTests/PlayQueueTests.swift
  git commit -m "fix: reorder only upcoming queue tracks"
  ```

---

### Task 2: Add Play Next and Add to End

**Files:**
- Modify: `kora/Player/PlayQueue.swift`
- Modify: `kora/Player/MusicPlayer.swift`
- Modify: `kora/Library/LibrarySidebar.swift`
- Modify: `kora/Player/QueueView.swift`
- Test: `koraTests/PlayQueueTests.swift`

**Contract:** Add two queue mutations and matching thin `MusicPlayer`
passthroughs:

- `playNext(_ track:)`: place the track at `index + 1`.
- `addToEnd(_ track:)`: place the track at `tracks.endIndex`.
- If the track is already current, no-op. If it exists elsewhere, move the
  existing entry instead of duplicating it. If it is outside the queue, insert
  it. Re-find the current track after moving an older entry so playback identity
  and `queue.index` remain correct.
- If there is no current queue, no-op. The UI disables both actions when
  `player.hasTrack` is false; silently creating a queue with no loaded player
  would split queue state from playback state.
- All manual mutations (`moveUpcoming`, Play Next, Add to End,
  `removeUpcoming`, and `clearUpcoming`) discard `originalTracks` when shuffle
  is active. Keep this as one small private `PlayQueue` helper. Turning shuffle
  off then preserves the user's edited visible queue rather than resurrecting
  removed tracks or dropping newly queued tracks.

- [ ] **Step 1: Write queue contract tests**

  Add compact tests proving:

  1. Play Next inserts a new cross-folder track immediately after current
     without changing current.
  2. Play Next/Add to End reposition an already queued track and leave one
     instance of its `Track.ID`.
  3. Moving a past track to the future re-finds the same current track.
  4. An empty queue is unchanged.
  5. After a manual edit while shuffled, turning shuffle off retains the edited
     track set and does not resurrect cleared entries.

  Keep these in `PlayQueueTests`; no AVPlayer test or mock is needed.

- [ ] **Step 2: Implement the two `PlayQueue` mutations**

  Reuse native array move/insert operations. A private placement helper is
  justified because both actions need the same uniqueness and current-index
  rules; do not expose it outside `PlayQueue`.

- [ ] **Step 3: Expose thin player actions**

  Add `playNext(_:)` and `addToEnd(_:)` to `MusicPlayer`. Each mutates the queue
  and calls `syncQueue()` once. Neither loads audio or calls
  `onTrackChange` because the playing item did not change.

- [ ] **Step 4: Add native row menus**

  In the shared `LibrarySidebar.trackRow` context menu, place **Play Next** and
  **Add to End** before **Reveal in Finder**. Disable them when no track is
  loaded. This covers both folder browsing and search without another UI.

  In each upcoming `QueueView` row, add **Play Next**, **Add to End**, and
  **Remove from Up Next** context actions. Continue to use relative upcoming
  offsets for removal. Do not put queue actions on the Now Playing row.

- [ ] **Step 5: Verify**

  Run `PlayQueueTests`. Manually queue a track from another folder next and at
  the end, reposition an existing upcoming track, remove it, toggle shuffle
  off, and relaunch. Playback must never jump and persisted order must match the
  inspector.

- [ ] **Step 6: Commit**

  ```bash
  git add kora/Player/PlayQueue.swift kora/Player/MusicPlayer.swift \
    kora/Library/LibrarySidebar.swift kora/Player/QueueView.swift \
    koraTests/PlayQueueTests.swift
  git commit -m "feat: add explicit up-next queue actions"
  ```

---

### Task 3: Add discoverable native queue commands

**Files:**
- Modify: `kora/App/koraApp.swift`
- Modify: `kora/UI/ContentView.swift`

No unit test: this is SwiftUI scene/menu wiring; verify by build and manual use.

- [ ] **Step 1: Lift only inspector presentation to the app scene**

  Add `@State private var showQueue = false` to `koraApp`, pass its binding to
  `ContentView`, and change `ContentView`'s local state to `@Binding`. Update the
  preview with `.constant(false)`. Do not put window presentation state in
  `MusicPlayer` and do not introduce custom focused-value types for one window.

- [ ] **Step 2: Extend the existing Playback menu**

  Add:

  - **Show Up Next** / **Hide Up Next**, toggling the shared binding, with
    `Shift-Command-U`.
  - **Clear Up Next**, disabled when
    `player.queueIndex + 1 >= player.queueTracks.count`, with no shortcut
    because it is destructive.

  Retain the existing playback, shuffle, and repeat commands unchanged.

  Track-specific **Play Next**, **Add to End**, and **Remove from Up Next** stay
  in the native row context menus from Task 2. Kora has no passive selected-track
  model: adding one only to enable global menu items would change the current
  single-click-to-play interaction and is deliberately out of scope. Existing
  `.onDelete` remains the keyboard deletion path for an upcoming list selection.

- [ ] **Step 3: Build and verify menus**

  Build, then verify the Playback menu labels and disabled states with an empty
  queue and a populated queue. `Shift-Command-U` must open and close the same
  inspector as the toolbar button; Clear must preserve the current track.

- [ ] **Step 4: Commit**

  ```bash
  git add kora/App/koraApp.swift kora/UI/ContentView.swift
  git commit -m "feat: add native up-next menu commands"
  ```

---

### Task 4: Benchmark before persistent metadata caching

**Files:**
- No committed production changes unless the gate passes.
- Record measured results in this task before checking it off.

**Why gated:** Startup scanning is asynchronous, and a cache only avoids
`Track.loadMetadata`; it cannot avoid bookmark resolution or directory
enumeration. A database/cache without evidence is permanent invalidation code
for a speculative problem.

- [ ] **Step 1: Measure the current path**

  On a representative daily library, preferably at least 5,000 tracks, perform
  five full quit/relaunch runs in a Debug build. Temporarily time, with
  `ContinuousClock`, these existing regions:

  1. `MusicLibrary.audioFiles(in:)` enumeration.
  2. The per-file metadata loop in `MusicLibrary.scan`.
  3. Total `restore()` time until `scanningFolderIDs` is empty.

  Log only track count and durations; do not log paths. Revert the temporary
  timing lines after recording the numbers. Discard the first run and record
  the median of the remaining four.

- [ ] **Step 2: Apply the decision gate**

  Implement a persistent metadata cache only when both are true:

  - median restore-to-ready time exceeds **2 seconds** on the representative
    warm relaunches; and
  - metadata loading consumes more than **50%** of that time.

  Otherwise stop here. Keep the current simple scan and record “gate not met.”
  If enumeration dominates, a metadata cache is the wrong fix; profile that
  path separately only after it causes a real usability problem.

- [ ] **Step 3: If the gate passes, write a separate cache plan first**

  Constrain that follow-up to a native, recomputable JSON file in the app's
  Caches directory, keyed by standardized path plus modification date and file
  size, storing title and artist only. Artwork remains on-demand. Cache misses
  use the existing `Track.loadMetadata`; writes are atomic. Require tests for
  hit, changed-file miss, corrupt-file fallback, and no loss of scan results.
  Do not add SQLite/Core Data or a dependency without measurements showing JSON
  itself is the next bottleneck.

---

### Task 5: Keep automatic freshness and ReplayGain behind later gates

No implementation in this plan.

- [ ] **Automatic freshness gate**

  Startup already scans every folder, and manual Rescan/Rescan All covers
  changes during a running session. Add automation only after repeated real use
  shows stale in-session libraries are a problem. The first implementation is
  a native app-activation rescan with a simple cooldown, reusing `rescanAll()`.
  Use FSEvents only if full rescans are measured as too expensive or near-real-
  time updates become an explicit requirement.

- [ ] **ReplayGain gate**

  Do not change the AVPlayer architecture speculatively. Start only after users
  report material loudness jumps and a representative library audit confirms
  useful ReplayGain tags. Then spike tag parsing plus AVFoundation per-item gain
  in isolation; preserve separate album/track modes. If AVPlayer cannot apply
  gain reliably without replacing the engine, return with that tradeoff before
  implementation.

---

### Task 6: Explicit non-goals

These are rejected for the current product direction, not hidden backlog:

- **MPD-compatible daemon/networking:** changes Kora's local, sandboxed product
  and security model. Reconsider only after remote/headless control is an
  approved product goal.
- **Tag editor:** risks modifying user-owned music and requires format-specific
  write/recovery behavior. Reconsider only as a separately approved project.
- **Visualizer and Last.fm:** visualizer is decoration; Last.fm adds account and
  network state. Add only on explicit demand after core playback workflows are
  proven.
- **Saved playlist system:** do not add it while **folders are the playlists**.
  If product direction changes, begin with standard M3U8 import/export rather
  than a custom playlist database.

---

### Task 7: Final verification sweep

- [ ] Run the full serial `koraTests` command. Report every failure or skipped
  test; do not summarize a partial run as passing.
- [ ] Run the Debug build command, then a Release build with
  `CODE_SIGNING_ALLOWED=NO`.
- [ ] Manual pass: play a middle track, reorder Up Next, Play Next from folder
  and search rows, Add to End, delete one upcoming item, clear the rest, toggle
  the inspector by toolbar and shortcut, toggle shuffle, and relaunch. Current
  playback must never jump; every mutation must persist.
- [ ] Confirm the README's existing “drag to reorder” claim is now true. No
  README feature expansion is needed for gated work that was not implemented.
