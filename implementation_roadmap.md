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
  - `ExecutionPlan.swift` containing phases, goals, and milestones.
  - `ContentView.swift` rendering phase selector + milestone checklists.
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

The running app currently includes a local execution checklist to track phase progress. It is intentionally minimal and is the first concrete implementation step toward this roadmap.
