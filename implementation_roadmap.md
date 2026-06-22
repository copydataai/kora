# Kora Implementation Roadmap

This file defines phased execution with concrete implementation outputs.

## Scope guardrails

- MacOS-only for this roadmap.
- Open-source implementation and delivery.
- Audio-first launch, video extension on top.
- No hidden complexity: each phase ships a usable collaboration workflow.

## Phase 0 — Plan Stabilization (Current)

Goal: turn strategy into executable backlog.

- Deliverable:
  - `README.md` with current target and install outline.
  - `product.md` with objective, MVP, v1.0, and post-MVP.
  - `design.md` for UI constraints and quality signal behavior.
  - `implementation_roadmap.md` with explicit milestones.
- App implementation started:
  - `kora/ExecutionPlan.swift` containing phases, goals, and milestones.
  - `kora/ExecutionTrackerView.swift` and `kora/PhaseExecutionStore.swift` rendering the checklist loop.
  - `koraApp.swift` simplified app shell for local progress execution.

Acceptance:
- Team can open the app and see active phase + milestones.
- Each milestone can be marked complete to track progress.
- The same phase can be advanced via the in-app execution loop:
  - identify the next pending milestone,
  - mark it complete,
  - auto-recommend the next phase when all milestones are done.

## Execution loop: repeatable cycle

The loop is now runnable:

1. Open a phase.
2. Run the top "Next action" milestone.
3. Complete it.
4. Continue until the phase is fully complete.
5. Advance to the next phase.

Current loop state is stored locally and persisted to user storage so progress is preserved across launches.

### Loop run #1 (2026-06-22)

- [x] Execute `Plan Stabilization` phase milestones:
  - [x] Finalize phase docs.
  - [x] Define scope-contract for v0.9/v1.0.
  - [x] Add measurable KPI table placeholders for baseline milestones.
- [x] Wire implementation engine into app (`ContentView` and `PhaseExecutionStore`).
- [ ] Start v0.9 execution milestones.

Next loop (run #2) starts by opening the v0.9 list and completing `mvp-room`.

### Loop run #2 (2026-06-22)

- [x] Implement `mvp-room` in app:
  - [x] Room model and lifecycle.
  - [x] Invite generation and consumption path.
  - [x] Local role state (`owner`, `editor`, `reviewer`).
  - [x] Room-first status and self-service hinting.
- [x] Implement `mvp-audio` local import and metadata extraction:
  - [x] File chooser and room attachment.
  - [x] duration/sample-rate/channel metadata extraction.
  - [x] support tier classification + status fallback behavior.
- [x] Implement `mvp-quality` hard-stop and warning checks:
  - [x] pre-export hard-stop detection (asset blockers, compatibility, invalid metadata),
  - [x] warning surface (clipping + loudness + channel/sample-rate consistency),
  - [x] room-aware export gate with explicit failure reasons.
- [x] Ship `mvp-ui` minimal room review interface improvements:
  - [x] quality status banner and export gate state visibility in room detail.
  - [x] explicit hard-stop warning and warning-only paths before export.

Current run focus: `v1.0` recommended baseline.
- Widget scaffolding is now in place (`widget-state.json` is persisted with room quality summaries).
- Next milestones remain:
  - `v10-distribution`: packaging hardening + state migration path.
  - `v10-widget`: actual widget extension using `widget-state.json`.

### Loop run #3 (2026-06-22)

- [x] Start v1.0 execution by preparing installer hardening and migration path:
  - [x] shared macOS state migration helper for room and execution data
  - [x] migration-aware persistence paths for room and checkpoint state
  - [x] installation hardening notes for signing/notarization and upgrade rollback

## Phase 1 — v0.9 MVP

Goal: ship practical end-to-end multiplayer audio loop.

Implementation targets:
- Room model and invite flow.
- Local audio import + metadata.
- Sync state and comment thread.
- Pre-export quality checks with clear blockers.

Acceptance:
- One-room flow from import to approved export in one practical cycle.

## Phase 2 — v1.0 Recommended Baseline

Goal: ship the baseline product intentionally, not as a constrained demo.

Implementation targets:
- Signed app packaging and update channel.
- macOS widget for room state and pending actions.
- Video room model reuse without changing collaboration primitives.
- Presets and role-aware next-step guidance.

Acceptance:
- New user can install, join/create room, complete review tasks, and resume from widget.

## Phase 3 — v1.3 Reliability

Goal: harden concurrency and large-file behavior.

Implementation targets:
- Conflict resolution behavior for concurrent updates.
- Background/resumable job queue.
- Audit trail with decision context.

Acceptance:
- Reduced conflict incidents and recoverable job behavior for large assets.

## Phase 4 — v1.5 Expansion

Goal: expand format reach and media convenience.

Implementation targets:
- Broader audio/video adapter surface.
- Reusable snippets/collections.
- Metadata and subtitle ingestion support.

Acceptance:
- Tier-2 format matrix implemented with explicit support labels.

## Phase 5 — v2.0 Community Scale

Goal: move from internal roadmap to community-driven extension.

Implementation targets:
- Codec/action plugin API.
- Public support matrix automation.
- Community contribution workflow for adapters.

Acceptance:
- Third-party module can be added without core model rewrites.

## Current implementation anchor

The running app now includes:
- local execution checklist and runable loops for phase control,
- room-first collaborative MVP surface in-app.

It remains intentionally minimal and can be iterated in the next loop milestone without changing architecture.
