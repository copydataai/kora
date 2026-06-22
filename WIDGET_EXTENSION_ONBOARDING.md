# Kora widget onboarding and deep-link resume guide

## Purpose

The widget keeps room context visible without opening the app. This guide covers setup, verification, and common pitfalls for local installs and upgrades.

## Prerequisites

- macOS 15.7+ with local install of Kora.
- Open-room data exists (create a room and import at least one local asset).
- `widget-state.json` is present in the host app support path:
  - `~/Library/Application Support/Kora/app.copydataai.kora/widget-state.json`

## Onboarding flow (user install)

1. Install or update Kora via the normal `.app` path.
2. Open the app at least once and create or resume a room.
3. Open Notification Center and add the Kora widget:
   - Edit widgets → search **Kora** → place the widget in a supported area.
4. Confirm the widget immediately shows:
   - a room name,
   - owner,
   - member count,
   - active blocker/warning state,
   - the next action hint.
5. Tap the widget action:
   - it should open Kora and navigate to the room surface if active room exists,
   - or the rooms surface as fallback.

## Deep-link resume behavior

Kora registers the custom scheme `kora://`.

- `kora://rooms` navigates to the Rooms surface.
- `kora://room/<roomID>` navigates directly to that room when the ID exists locally.

The widget uses the same contract with:

- `kora://room/<activeRoomID>` when an active room is present,
- `kora://rooms` when no room is active.

## Migration/reinstall notes

- If a widget does not update after upgrade, reopen Kora once and open any room.
- Verify `widget-state.json` exists in the current support namespace (migration logic is built into runtime state readers).
- If data disappears unexpectedly, confirm you are checking the same `app.copydataai.kora` namespace used by the host bundle ID.

## Troubleshooting

### Widget does not appear

- Confirm `Contents/PlugIns/koraWidget.appex` exists in the built app bundle.
- Confirm installation used the `kora` target with widget extension included.

### Widget appears but room is stale

- Confirm Kora was opened recently and wrote `widget-state.json`.
- Restart the widget refresh window by opening the widget gallery once.
- Check app logs for state write errors in room persistence paths.

### Widget tap opens wrong room

- Confirm the URL contains a known room UUID.
- If the room ID is invalid or missing, Kora falls back to the selected default room.

## What to verify after onboarding

Run checks from [INSTALL.md](INSTALL.md), then verify:

1. Widget embed + extension presence.
2. `kora://` handlers from browser/terminal.
3. Room resume behavior from widget payload (`activeRoomID` path).
