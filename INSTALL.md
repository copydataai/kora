# Installation and migration notes (v1.0 planning)

This project ships as open-source and targets macOS installs from a local distribution.

## Local release hardening

Keep these checks in place before distributing a release package:

1. Bump app version metadata consistently (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
2. Verify signing identity is set for all distributable targets.
3. Validate app bundle integrity after signing.
4. Notarize and staple the package build before publishing links.
5. Keep a previous working bundle in release assets for rollback.
6. Publish a short changelog with required state migration notes when storage format or path changes.
7. Keep a release verification path that includes deep-link + widget smoke checks.

## Distribution command surface

From a clean shell (adjust identifiers to your environment):

- Archive:
  - `xcodebuild -scheme kora -destination 'generic/platform=macOS' -archivePath ./build/kora.xcarchive archive`
- Export signed `.app`:
  - `xcodebuild -exportArchive -archivePath ./build/kora.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist`
- Notarize and staple:
  - `xcrun notarytool submit --wait --apple-id ... --team-id ... ./build/kora.app.zip`
  - `xcrun stapler staple ./build/kora.app`

## Scheme-friendly release verification

Use the project scheme name directly for all release validation:

- `./scripts/verify-release.sh`
- or with overrides:
  - `./scripts/verify-release.sh ./kora.xcodeproj kora Release ./build/kora.xcarchive ./build ./exportOptions.plist`

The script verifies:

- build scheme exists (`kora`),
- archive and exported app output paths,
- embedded widget extension presence (`Contents/PlugIns/koraWidget.appex`),
- `CFBundleURLTypes` contains scheme `kora`,
- deep-link contract lines in source (`kora://rooms`, `kora://room/<uuid>`).

Deep-link smoke checks are intentionally manual by design:
- `open "kora://rooms"`
- `open "kora://room/<valid-room-uuid>"`


## State migration path for packaged upgrades

Kora persists local app state in one canonical path:

- `~/Library/Application Support/Kora/<bundle id>/`

Current state files:

- `room-state.json`
- `milestone-state.json`
- `widget-state.json`

On first launch after an installer path change, the app checks these legacy locations and migrates if needed:

- `~/Library/Application Support/Kora/room-state.json`
- `~/Library/Application Support/Kora/milestone-state.json`
- any nested `~/Library/Application Support/Kora/<namespace>/` folder states

This keeps existing local rooms, invite state, and execution milestones available after packaging migration.

## Open-source/local install contract

- No third-party runtime is required to run room workflows.
- App state stays local by default.
- Contributor and contributor-machine installs use the same state migration path for reliability.

## Widget onboarding

- Before release verification, confirm widget onboarding steps in [WIDGET_EXTENSION_ONBOARDING.md](WIDGET_EXTENSION_ONBOARDING.md).

## Widget extension checks

- Verify widget embedding in packaged builds:
  - after archive, confirm `Contents/PlugIns/koraWidget.appex` exists in the final app bundle.
- Verify payload sharing path:
  - open a room in Kora and confirm `widget-state.json` appears in host app support path.
  - confirm the widget shows an active room and blocker summary on next refresh.

## URL handler checks

- Confirm app URL scheme registration in the release app bundle:
  - `CFBundleURLTypes` includes scheme `kora`.
- Confirm resume flow:
  - open `kora://rooms` from browser/terminal and ensure the app enters the room surface.
  - open `kora://room/<valid-uuid>` and ensure the target room becomes selected/open in `RoomWorkspaceView`.
