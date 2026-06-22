# Kora

Kora is an **open-source**, macOS-only, multiplayer-first media app for local teams.

We optimize for real workflow utility first:
- end-to-end collaboration in one room,
- strong local audio quality,
- easy path to video,
- and low-friction installation.
- high self-service reinforcement loop from first export onward.

## What this project is aiming for

- Become an end-to-end local media collaboration tool, starting with audio.
- Support most common local audio/video formats through a stable tiered matrix.
- Make install and upgrades simple for both users and contributors.
- Keep the interface minimal, calm, and action-focused.
- Execute in phases with clear, measurable milestones.

## Current implementation status

We now have a phased execution scaffold in the app:
- [ExecutionPlan.swift](/Users/josesanchez/Developer/public/kora/kora/ExecutionPlan.swift)
- [ContentView.swift](/Users/josesanchez/Developer/public/kora/kora/ContentView.swift)
- [implementation_roadmap.md](/Users/josesanchez/Developer/public/kora/kora/implementation_roadmap.md)

This shows active phases and checklist progress directly in the local UI.

## Recommended release target

We are defining **v1.0 — Recommended Production Baseline** as the goal, with:

- Multiplayer room workflow with presence and review controls.
- Local audio pipeline with quality checks and deterministic exports.
- Signed distribution and update path for practical installs.
- macOS widget support for active room context and pending actions.
- Video extension using the same collaboration model as audio.

For detail, see [product.md](/Users/josesanchez/Developer/public/kora/kora/product.md).

## MVP (v0.9)

A practical but minimal starting point:

- local audio import and processing,
- multiplayer review,
- room roles,
- core quality checks,
- zero external dependency setup.

## Install path

### For users

1. Download the macOS app package.
2. Run first-time setup wizard.
3. Open or join a room and start reviewing.

### For contributors

1. Clone repository.
2. Open in Xcode.
3. Build and run.
4. Contribute adapters, quality rules, and UI improvements through standard PR flow.

## Design reference

Implementation decisions and UI criteria are in:

- [design.md](/Users/josesanchez/Developer/public/kora/kora/design.md)

Execution details are in:

- [implementation_roadmap.md](/Users/josesanchez/Developer/public/kora/kora/implementation_roadmap.md)
