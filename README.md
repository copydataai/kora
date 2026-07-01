# Kora

A minimal, native macOS music player. Point it at your music folders and play -
no library import, no accounts, no clutter.

## Features

- Register music **folders**; Kora scans them (including subfolders) into a sidebar library.
- **Adaptive now-playing** that takes on the current album art's color — blurred-art backdrop, art-derived accent, cross-fading as tracks change.
- **Up Next** queue inspector: see what's coming, click a track to jump, drag to reorder.
- **Folder management**: rescan for on-disk changes, rename and reorder, reveal in Finder, and re-link folders that moved.
- Play/pause, previous/next, seek, volume, **shuffle & repeat**, and auto-advance through a folder.
- **Search** (⌘F) across every folder from the sidebar.
- **Resumes where you left off**: last queue, track, and position restore (paused) on launch.
- Close the window and the music keeps playing; reopen or quit from the menu bar.
- A **menu-bar mini-player** plus Playback menu commands (⌘← / ⌘→ to skip).
- Drag a folder onto the window to add it; drag an audio file to play it.
- A macOS **now-playing widget**.

Folders are remembered across launches via security-scoped bookmarks; the app
stays sandboxed and never touches files you didn't pick.

## Build & run

Verified with Xcode 26.3 on macOS.

```bash
open kora.xcodeproj   # then Run the "kora" scheme (Cmd-R)
```

CLI build:

```bash
xcodebuild build -project kora.xcodeproj -scheme kora -destination 'platform=macOS'
```

CLI tests:

```bash
xcodebuild test -project kora.xcodeproj -scheme kora -destination 'platform=macOS'
```

CI runs build and unit tests with `CODE_SIGNING_ALLOWED=NO`. Full UI tests are part of the shared scheme and should be run locally on a signed development machine.

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

## Project layout

- `kora/App/` - app entry and scene wiring.
- `kora/UI/` - root SwiftUI composition.
- `kora/Library/` - folder bookmarks, library scanning, and sidebar UI.
- `kora/Player/` - track model, queue logic, playback engine, and now-playing UI.
- `kora/WidgetBridge/` - app-side writes to the shared widget state file.
- `KoraShared/` - types compiled into both the app and widget targets.
- `koraWidget/` - the now-playing WidgetKit extension.
- `koraTests/` - unit tests for scan, queue, bookmarks, and playback decisions.
- `koraUITests/` - launch smoke tests for the macOS app.

## Development

This repo uses `.editorconfig` for baseline whitespace rules. There is no SwiftFormat or SwiftLint requirement yet; add one only when the project is ready to enforce it in CI.

## License

Open source.
