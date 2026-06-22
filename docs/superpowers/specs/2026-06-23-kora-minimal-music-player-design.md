# Kora — Minimal Music Library Player (Design)

Date: 2026-06-23
Status: Approved (design), pending implementation plan

## Goal

A minimalist, sandboxed macOS music player in the spirit of Apple Music / OpenAI
restraint. The user registers music **folders**; Kora scans them into a library
browsed in a sidebar and played from a now-playing hero panel. Ships with a
macOS now-playing widget.

This supersedes the abandoned "multiplayer rooms for media teams" vision still
described in the legacy docs. Those docs and the orphaned scaffolding are removed
as part of this work.

## Non-goals (v1)

Equalizer, gapless/crossfade, search, playlist files, custom sorting, manual
queue reordering, network/streaming, lyrics. Add only on explicit request.

## Architecture

SwiftUI + AVFoundation. Sandboxed macOS app target (`kora`) plus a WidgetKit
extension target (`koraWidget`).

```
koraApp            entry; owns MusicLibrary + MusicPlayer as @StateObjects;
                   mirrors now-playing state into the shared widget store
ContentView        NavigationSplitView: LibrarySidebar | NowPlayingView
  LibrarySidebar   folders -> tracks list, "+ Add Folder", "Forget" per folder,
                   selection drives the player
  NowPlayingView   artwork, title/artist, seek slider + time, TransportControls,
                   volume slider
MusicLibrary (new) folders persisted as security-scoped bookmarks; scan -> [Track]
MusicPlayer        AVAudioPlayer engine: play/pause/stop/seek, volume, queue,
                   next/prev, auto-advance on finish
Track (new)        id, url, title, artist, lazy artwork, source folder
```

### Component contracts

- **Track**: value type. `id`, `url`, `title`, `artist?`, source folder id.
  Artwork loaded lazily from `AVAsset` metadata (not held eagerly for the whole
  library). `title`/`artist` from `AVAsset` common metadata, falling back to the
  filename (title) and empty (artist).
- **MusicLibrary** (`ObservableObject`): `folders: [Folder]`, each `Folder` =
  resolved security-scoped URL + display name + `tracks: [Track]`. Methods:
  `addFolder(url:)`, `forget(folder:)`, `rescan()`. Persists folder bookmarks to
  `UserDefaults` (array of bookmark `Data`). On launch: resolve each bookmark,
  `startAccessingSecurityScopedResource`, scan. Stops access on `forget` and
  app teardown.
- **MusicPlayer** (`ObservableObject`, existing, extended): adds `volume`,
  `artwork`, `artist`, a `queue: [Track]` with `currentIndex`, `next()`,
  `previous()`, and auto-advance when a track finishes. `play(track:in:)` sets
  the queue to the track's folder list (listed order) and starts playback.

### Data flow

1. User adds a folder (picker or drag-drop) -> `MusicLibrary.addFolder` stores a
   bookmark and scans -> `folders` updates -> sidebar re-renders.
2. User clicks a track -> `MusicPlayer.play(track:in:folderTracks)` -> queue set,
   playback starts, now-playing panel + widget store update.
3. Track finishes -> `MusicPlayer` auto-advances to `next()` (no wrap past end;
   stops at end of folder). `previous()`/`next()` clamp at queue bounds.

## Scanning rules

- **Recursive** scan of subfolders.
- Include files whose UTType conforms to `.audio` (matches the current importer's
  `allowedContentTypes: [.audio]`). Skip everything else silently.
- Scan is best-effort: unreadable files are skipped, not fatal.

## Sandbox & entitlements (required, not optional)

The app is sandboxed (`ENABLE_APP_SANDBOX = YES`). The library cannot persist
folder access without bookmarks. Required entitlements:

- `com.apple.security.files.user-selected.read-only` — folder/file picker access.
- `com.apple.security.files.bookmarks.app-scope` — persistent folder bookmarks.
- An **App Group** shared by app + widget — for now-playing state hand-off.

Bookmark lifecycle: create app-scoped bookmark on add; resolve + start access on
launch; stop access on forget/teardown; if a bookmark is stale, drop it and
surface a quiet "folder unavailable" state rather than crashing.

## Widget

Rewrite `koraWidget` from the dead "room" concept into a **now-playing** widget,
reusing the existing shared-state plumbing:

- App writes current track (title, artist, art thumbnail, isPlaying) to the
  shared App-Group container on every track/state change.
- Widget reads that container and renders a compact now-playing card.
- Reuse/rename `KoraWidgetModels`, `KoraWidgetStateStore`; replace
  `KoraRoomWidget` with `KoraNowPlayingWidget`.
- Empty state when nothing has played: app name + "No track playing".

## Drag & drop

`onDrop` of file URLs on the window:
- Dropped **folder** -> `MusicLibrary.addFolder`.
- Dropped **audio file** -> play it immediately (single-item queue).

## Volume

Slider bound to `AVAudioPlayer.volume` (0...1). Last value persisted in
`UserDefaults`, restored on launch.

## Cleanup (token efficiency)

- **Delete orphaned Swift** (not in the build): root-level `ContentView.swift`,
  `ExecutionPlan.swift`, `koraApp.swift`, `PhaseExecutionStore.swift`.
- **Collapse docs** (868 lines -> one lean README ~60 lines): delete
  `product.md`, `implementation_roadmap.md`, `INSTALL.md`,
  `WIDGET_EXTENSION_ONBOARDING.md`; rewrite `README.md` to cover what Kora is,
  build/run, and features. Audit `scripts/verify-release.sh` for references to
  deleted concepts; trim or drop if it only served the dead vision.

## Testing

Unit tests (in `koraTests`) on the real logic, encoding why each matters:

- **Library scan**: audio-extension filtering + recursion — a non-audio file in a
  nested folder must not appear; an audio file two levels deep must. Guards
  against accidentally importing junk or missing nested music.
- **Queue navigation**: `next`/`previous` clamp at bounds; auto-advance moves to
  the next track and stops at the end. Guards transport correctness.
- **Bookmark round-trip**: create -> persist -> resolve yields a usable URL.
  Guards the sandbox persistence that the whole library depends on.

Playback engine timing and UI remain manual-verify.

## Risks

- **Stale bookmarks** after a folder moves/deletes — handled by dropping the
  bookmark and showing an unavailable state.
- **Large libraries** scanning slowly on launch — acceptable for v1 (local
  folders); scan off the main actor, show folders incrementally if needed.
- **Artwork memory** if loaded eagerly — mitigated by lazy per-track artwork.
