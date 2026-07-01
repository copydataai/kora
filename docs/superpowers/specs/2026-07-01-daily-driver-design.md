# Kora daily-driver release — design

Goal: make Kora usable as someone's only music player, then ship v1.0 via
GitHub Releases. Six features, in dependency order, each small enough for a
micro commit series.

## 1. Survive the window

macOS keeps SwiftUI apps (and their audio) running after the last window
closes; nothing to change in playback. What's missing is control without a
window:

- Give the main `WindowGroup` an id (`"main"`).
- Add "Open Kora" (via `@Environment(\.openWindow)` from a helper view inside
  the MenuBarExtra) and "Quit" buttons to the MenuBarExtra.

Verify manually: close window → music keeps playing → reopen from menu bar.

## 2. Resume on launch

Persist playback state to `UserDefaults` and restore it paused.

- **What**: queue as `[String]` file paths, queue index, elapsed seconds.
  Key: `player.session.v1`, one Codable blob (`PersistedSession`).
- **When written**: on track change, on pause/stop, and every ~5s while
  playing (from the existing 0.25s progress timer, throttled).
- **When restored**: in `koraApp.task`, after `library.restore()` so folder
  security scopes are live. Match saved paths against restored library tracks
  (by `url.path`) to reuse their metadata; fall back to `Track(url:)` for
  paths no longer in the library but still on disk.
- **How restored**: rebuild `PlayQueue` at the saved index, `load()` the
  current track, seek to saved position, stay **paused**. Never auto-play at
  launch.
- Restore is skipped if the current track's file no longer exists.

## 3. Shuffle & repeat

- `PlayQueue` gains `isShuffled`: keeps `originalTracks`; shuffling reorders
  `tracks` with the current track moved to the front of the shuffled order;
  un-shuffling restores original order and re-finds the current index.
- `MusicPlayer` gains `repeatMode: RepeatMode` (`off`, `all`, `one`) and
  `isShuffled`, both `@Published`, both persisted in UserDefaults.
- End-of-track (`handlePlaybackFinished`): `one` → seek 0 + play;
  `all` → next, wrapping to index 0 at the end; `off` → current behavior.
- UI: shuffle and repeat toggle buttons next to the transport controls in
  `NowPlayingView`; matching items in the Playback menu.

## 4. Search

- `.searchable` on the sidebar (⌘F via the standard Find behavior).
- Non-empty query → sidebar shows a flat list of matching tracks across all
  available folders instead of the folder tree.
- Match: case-insensitive substring on `Track.title` (filename-derived) and
  `artist` when present. Tags are not indexed up front — this is filename
  search in practice. Known limitation; tag indexing only if it proves
  painful.
- Clicking a result plays the track within its folder's queue, same as
  clicking it in the sidebar.
- Filter logic lives in a pure `nonisolated static` function on
  `MusicLibrary` so it's unit-testable.

## 5. Format fix

Remove `ogg` and `opus` from `MusicLibrary.audioExtensions` — AVPlayer cannot
decode them, so today they scan into the sidebar and fail silently on play.

Sort order was audited: the scanner sorts by full path
(`MusicLibrary.audioFiles`), so numbered filenames play in album order.
No change. Tag-based (track-number) sort is deferred until someone hits it.

## 6. Ship: CI/CD via GitHub Actions

CI (`ci.yml`) already builds and runs unit tests on every push/PR. Add CD:

- New workflow `.github/workflows/release.yml`, triggered by tags matching
  `v*`.
- Steps: checkout → import Developer ID certificate from secrets →
  `xcodebuild archive` (Release) → export signed app → notarize with
  `notarytool` → staple → package a DMG (`hdiutil`) → create a GitHub
  Release with the DMG attached (`gh release create`).
- Required repo secrets, documented in README:
  `MACOS_CERTIFICATE` (base64 .p12), `MACOS_CERTIFICATE_PASSWORD`,
  `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` (app-specific password).
- README gets a "Release" section: bump version, tag `vX.Y.Z`, push tag.
- App icon: provided by the user later; the asset catalog slot already
  exists. Not a blocker for the workflow.

## Testing

Swift Testing, in the existing `koraTests` style:

- `PlayQueueTests`: shuffle keeps current track and preserves the set;
  un-shuffle restores original order; repeat-all wrap semantics (wrap helper
  on the queue if logic lands there).
- `PersistedSessionTests`: encode/decode round-trip; restore skips missing
  files (pure decision function).
- `LibraryScanTests` (or new `SearchFilterTests`): filter matches
  title/artist case-insensitively, empty query returns nothing.

UI-only pieces (menu bar buttons, searchable wiring) are verified by running
the app, not UI tests.

## Non-goals

Playlists, tag editing, EQ, watch-folders/FSEvents, gapless, AirPlay,
streaming, iOS. Folders are the playlists — that identity is the product.
