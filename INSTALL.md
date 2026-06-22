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

## Distribution command surface

From a clean shell (adjust identifiers to your environment):

- Archive:
  - `xcodebuild -scheme kora -destination 'generic/platform=macOS' -archivePath ./build/kora.xcarchive archive`
- Export signed `.app`:
  - `xcodebuild -exportArchive -archivePath ./build/kora.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist`
- Notarize and staple:
  - `xcrun notarytool submit --wait --apple-id ... --team-id ... ./build/kora.app.zip`
  - `xcrun stapler staple ./build/kora.app`

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
