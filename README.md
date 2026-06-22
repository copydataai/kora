# Kora

A minimal, native macOS music player. Point it at your music folders and play -
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

- `kora/` - the app (SwiftUI). Player engine in `MusicPlayer.swift`, library in `MusicLibrary.swift`, UI in `ContentView.swift` + `*View.swift`.
- `koraWidget/` - the now-playing WidgetKit extension.
- `koraTests/` - unit tests for scan, queue, and bookmark persistence.

## License

Open source.
