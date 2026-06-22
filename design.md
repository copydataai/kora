# Design Plan for Kora Execution

## Goal translation

Kora should be a **clean studio surface** for real collaboration: quick to understand, hard to misclick, fast to act.

The design must support the full product plan, not only MVP:
- useful multiplayer from day one,
- recommended v1.0 as the true shipping baseline,
- extension into video,
- and widget visibility without adding clutter.

## Design doctrine

- **Minimalist baseline:** favor predictable, low-noise controls over visual density.
- **OpenAI/Apple influence:** concise phrasing, clear hierarchy, direct system feedback.
- **Self-reinforcement:** every screen should suggest the next useful action, not just display status.

## Core UI principles

1. **Room-first context**
   - Show participants, active item, blockers, and last decision on entry.
   - Keep room identity visible at all times.

2. **Minimal control surface**
   - one primary path for review, one for process, one for export.
   - advanced operations behind explicit expansion.

3. **Self-service reinforcement**
   - role-aware prompts (“next action” chips),
   - pre-export check summaries,
   - template recall for recurring workflows.

4. **Local-first trust signals**
   - codec/container + lineage visible at ingest and before export,
   - warnings are specific and actionable.

5. **Mac-native behavior**
   - keyboard-first operations,
   - native panes/windows,
   - predictable menu and shortcut flow.

6. **Restraint-first visual language**
   - whitespace-led composition,
   - strong typographic hierarchy,
   - low-contrast status chips,
   - short transition moments only.

## Design for v0.9 vs v1.0

### v0.9 design behavior

- Focused audio flow only.
- Immediate room creation/joining, invite handling, and room-first role visibility.
- Compact comments and approvals.
- In-room quality pass as a required checkpoint before export, with hard-stop blockers and visible warnings.

For v1.0 add:
- explicit templates and role prompts to reinforce the next best action,
- richer quality context while keeping the same control cadence.

### v1.0 design behavior

- Persistent status timeline with reusable checkpoints.
- Review lanes by role and state.
- Widget-ready room-state surface states for active rooms.
- Video extension in a second track with shared components.

## Widget design requirements

- Small but useful glance states: room name, pending review count, critical blockers.
- Explicit stale-state signaling when payload age exceeds the refresh expectation.
- One-tap resume action from widget into app context.
- Low-noise visual language and readable status chips.
- No complex gestures; predictable actions only.

### Widget implementation now

- `koraWidget` target is implemented with real state read:
  - reads host payload from `widget-state.json`.
  - shows active room blockers, warnings, and next-action hint.
- keeps room list short and scan-first.
- marks stale payloads to avoid accidental blind action.

### Open-source + minimalism contract

- keep layout hierarchy stable as features expand;
- maintain clear status semantics and avoid ornamental UI load;
- no behavior should require hidden defaults to proceed.

### Navigation contract

- Deep links:
  - `kora://room/<uuid>` opens that room in the Room surface.
  - `kora://rooms` opens the rooms surface.
- Navigation state is route-scoped (single-use) to avoid replay after persistence updates.

## Format communication in UI

- For every item, show:
  - file type,
  - codec,
  - support tier,
  - status (`native`, `transcoded`, `fallback`, `unsupported`).
- Surface conversion choices with short impact notes.

## Minimal visuals

- restrained palette,
- predictable spacing,
- low-noise status chips,
- short intentional transitions only.

## Definition of done for shipped feature

A feature is design-complete when it:

- works in multiplayer context,
- preserves local-first workflow,
- does not increase install friction,
- follows quality checkpoints,
- and remains readable in a compact state (including widget surfaces).

## Alignment checks for all releases

Before approving a feature release:

- Is this still useful for real session work?
- Does it strengthen self-service from within a room?
- Does it preserve minimal, readable interaction?
- Can this scale to video under the same collaboration model?
- Is widget behavior still predictable and low-noise?

## Current implementation anchor

The app currently includes an execution scaffold plus room MVP:

- Phase list and goals in [ExecutionPlan.swift](/Users/josesanchez/Developer/public/kora/kora/kora/ExecutionPlan.swift)
- Phase selection and milestone checklist in [ExecutionTrackerView.swift](/Users/josesanchez/Developer/public/kora/kora/kora/ExecutionTrackerView.swift)
- Room creation, invite, and role workflow in [RoomWorkspaceView.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomWorkspaceView.swift)
- Room domain model and persistence in [RoomModels.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomModels.swift)
- Room collaboration state store in [RoomStore.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomStore.swift)
- Widget extension source in [koraWidget](/Users/josesanchez/Developer/public/kora/kora/koraWidget)

Design implication:
- Keep this scaffold minimal and non-blocking.
- Replace placeholders with production-grade UI as each phase ships.
- Progress UI is for team governance, not the user-facing media workflow.
- Preserve a clear loop narrative: `next action -> complete -> advance`.
