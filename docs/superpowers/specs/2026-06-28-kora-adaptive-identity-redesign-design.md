# Kora — Adaptive Identity Redesign (Design)

Date: 2026-06-28
Status: Approved (design), pending implementation plan

## Goal

Give Kora a distinctive visual identity and close the highest-value gaps left by
v1. The identity is **adaptive / artwork-driven**: the now-playing view absorbs
color from the current album art and re-tints as tracks change. Alongside the
visual work, this phase adds folder management, a queue/up-next view, and a
menu-bar mini-player.

Built as **one cohesive redesign** (not incremental slices) — the whole system
should feel like one vision when it lands.

Targets macOS 15.7 (project deployment target), so `MenuBarExtra`, `.inspector`,
and modern SwiftUI materials are all available without availability gating.

## In scope

- Adaptive artwork identity (now-playing absorbs album-art color).
- Now-playing redesign ("the playing experience").
- Sidebar redesign with a playing-track indicator and proper states.
- Folder management: rescan, visible stale state + re-link, reveal in Finder,
  reorder + rename.
- Queue / up-next view with drag-to-reorder.
- Menu-bar mini-player + app-menu playback commands.

## Out of scope (this phase)

Search/filter, widget redesign, EQ, gapless/crossfade, playlists, lyrics,
network/streaming. Add only on explicit request.

## Visual direction

Adaptive / artwork-driven. The **adaptive color lives in the now-playing view
only** — the sidebar stays neutral so the app does not turn into a rainbow. The
sidebar borrows the accent in exactly one spot: the currently-playing row.

## Architecture

Existing module layout is kept (`App/`, `UI/`, `Library/`, `Player/`,
`WidgetBridge/`, `KoraShared/`, `koraWidget/`).

```
New:   Player/ArtworkTheme.swift   ArtworkTheme value type + ArtworkPalette helper
       Player/QueueView.swift       inspector content: current + upcoming, reorder
Edit:  Player/MusicPlayer.swift     + theme; queue jump/move passthroughs
       Player/PlayQueue.swift       + move(fromOffsets:toOffset:), jump(to:)
       Player/NowPlayingView.swift  redesign: backdrop, foreground, empty state
       Library/MusicLibrary.swift   PersistedFolder Codable model + migration;
                                    rescan; stale handling; displayName; reorder;
                                    rename
       Library/LibrarySidebar.swift playing indicator; states; context menus;
                                    .onMove
       UI/ContentView.swift         .inspector + toolbar (queue toggle, rescan
                                    all); keep drag-drop
       App/koraApp.swift            .commands(Playback) + MenuBarExtra
```

## Adaptive theming layer

The heart of the identity. One value type and one helper, consumed via the
environment's `MusicPlayer`.

- **`ArtworkTheme`** (value type, `Equatable`): `accent: Color`,
  `textPrimary: Color` (black or white, chosen by luminance), and the source
  artwork `Data?` used for the backdrop. A `.neutral` static default for the
  no-artwork case.
- **`ArtworkPalette.theme(for: Data?) async -> ArtworkTheme`**: decode artwork →
  `CIImage` → one CoreImage **`CIAreaAverage`** over the full extent → average
  RGBA → `accent`. Relative luminance (`0.299·r + 0.587·g + 0.114·b`) decides
  black vs white `textPrimary` for contrast. No artwork → `.neutral`. Runs off
  the main actor.
- **Wiring**: `MusicPlayer` gains `@Published var theme: ArtworkTheme = .neutral`,
  computed inside the existing `refreshMetadata(for:)` under the **same
  stale-guard already there** (`queue.current?.id == track.id`) so a fast track
  change can't apply the wrong theme. The whole app reads `player.theme`.
- **Motion**: `.animation(.easeInOut(duration: 0.5), value: player.theme)` at the
  now-playing root cross-fades the accent on track change.

Keeping the single-average approach is deliberate: it gives the immersive look in
~30 lines with no dependency. Upgrade path (only if the average looks muddy):
multi-swatch vibrant extraction.

## Now-playing redesign

- **Backdrop**: the current album art itself, `scaledToFill` + heavy
  `.blur(radius: ~60)` + a legibility scrim — no color math. Cross-fades on track
  change via `.id(track.id)` + transition.
  `// ponytail:` SwiftUI `.blur` on full-res art; if janky, pre-blur a downscaled
  thumbnail with `CIGaussianBlur` (known upgrade path).
- **Foreground** over the backdrop: an elevated rounded **artwork card** (shadow),
  large **SF Rounded** title + secondary artist using `theme.textPrimary`, an
  **accent-tinted** seek bar with monospaced time labels, a larger center
  play/pause plus prev/next (accent). Space-bar shortcut kept. Volume restyled,
  kept inline.
- **Empty state**: neutral gradient + "Nothing playing" + a hint to add a folder.

## Sidebar redesign

- **Playing-track indicator**: the row whose `track.id` matches the player's
  current track shows an accent glyph + accent-tinted text — the one place the
  sidebar uses the now-playing accent.
- **States**: hover highlight, clear selection, section headers showing folder
  name + track count.
- **Empty state**: "No folders yet — add one to start" with the Add button, which
  stays pinned at the bottom.

## Folder management + persistence

Rename, reorder, and remembered-but-stale folders cannot ride on today's
`[Data]`-of-bookmarks storage, so the persisted model grows.

- **Persisted model**: `PersistedFolder: Codable { bookmark: Data; displayName:
  String? }`, stored as an **ordered array** (order = sidebar order) via
  `JSONEncoder` under a new UserDefaults key, with a **one-time migration** that
  reads the old NSKeyedArchiver key (kept readable for one release). `Folder`
  gains `displayName: String?` (`name = displayName ?? url.lastPathComponent`)
  and `isAvailable: Bool`.
- **Rescan**: `rescan(_ folder)` re-runs `audioFiles(in:)`, rebuilds `tracks`,
  preserves the same `folderID`/bookmark/name. Plus "Rescan All". Surfaced via
  context menu + toolbar.
- **Stale + re-link**: `restore()` stops dropping stale bookmarks silently — it
  keeps the folder with `isAvailable = false`, labeled from the saved
  `displayName` (this is *why* names are persisted: a stale bookmark may not
  resolve to any URL). The sidebar shows it greyed with a **"Locate…"** button →
  folder picker → new bookmark replaces the stale one and rescans. Old data with
  no saved name → generic "Unavailable folder" label.
- **Reveal in Finder**: `NSWorkspace.shared.activateFileViewerSelecting([url])` —
  folder + track context menu.
- **Reorder**: `.onMove` reorders `folders` → persist new order. **Rename**:
  context menu → inline edit → set `displayName` → persist.

## Queue / up-next

- **UI**: a native `.inspector` panel on the now-playing detail, toggled from a
  toolbar button + a menu command. Lists the queue with the current track
  highlighted (accent) and upcoming tracks below. Clicking a row jumps to it.
  Rendered by `QueueView.swift` with `.onMove` drag-reorder.
- **`PlayQueue` gains** `move(fromOffsets:toOffset:)` and `jump(to:)`, both
  keeping `index` pointed at the same current track when items shift around it.
  `MusicPlayer` exposes thin passthroughs; jumping loads + plays the new current.

## Menu-bar + commands

- **`.commands { CommandMenu("Playback") }`**: Play/Pause, Next (⌘→), Previous
  (⌘←) in the app menu — keyboard reach beyond the in-window space bar. Play/Pause
  gets a menu item but no extra shortcut (the in-window space bar already covers
  it; avoids stealing a global key).
- **`MenuBarExtra`** (`.menuBarExtraStyle(.window)`): a compact now-playing
  dropdown — tiny artwork, title/artist, mini transport — reading the same
  `MusicPlayer` (already a Scene-level `@StateObject`).

## Data flow

1. Artwork loads (existing async path) → `ArtworkPalette.theme(...)` computed
   off-main → assigned on main under the stale-guard → now-playing animates
   backdrop + accent.
2. Folder op (add/rescan/rename/reorder/locate) → persist the Codable array →
   `folders` updates → sidebar re-renders.
3. Queue op (jump/move/next/previous/auto-advance) → `PlayQueue` mutation →
   now-playing + inspector + menu-bar update.

## Testing

Unit tests (`koraTests`), each encoding why it matters:

- **`PlayQueue.move`** preserves current-track identity when items shift around
  the index; **`jump`** sets and clamps the index. Guards that reordering/jumping
  never silently changes what's playing.
- **`ArtworkPalette`** luminance → text-color pick: feed known light/dark colors,
  assert black-on-light and white-on-dark. Guards legibility.
- **`MusicLibrary`** Codable round-trip + old→new migration: old NSKeyedArchiver
  bookmarks still load after upgrade. Guards that nobody loses their library.
- **Rescan** reflects added/removed files on disk. Guards the refresh contract.
- **Stale** bookmark yields an unavailable placeholder, not a vanished folder.
  Guards the re-link affordance.

Manual-verify: backdrop blur + color cross-fade, inspector, `MenuBarExtra`,
drag-reorder feel.

## Review

Before merge, run the `codex` CLI over the diff as the code-review pass (user
preference: codex over subagent-delegated review). The big-bang diff makes an
independent review pass especially worthwhile.

## Risks

- **Contrast on busy art** — scrim + luminance-picked text; a muddy average gives
  a dull accent (acceptable v1; upgrade: vibrant-swatch extraction).
- **`.blur` perf on large art** — upgrade path: pre-blurred downscaled thumbnail.
- **Migration correctness** — covered by test; old key stays readable one release.
- **Big-bang diff size** — mitigated by the `codex` review pass before merge.
