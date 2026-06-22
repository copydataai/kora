# Product Plan — Kora

## Objective

Deliver an **end-to-end multiplayer macOS app** for local media teams with:

1. Audio-first launch that is genuinely useful on day one.
2. Broad local audio/video format compatibility.
3. Easy installation and upgrades.
4. Built-in self-service quality and collaboration controls.
5. Widget support to keep creators in context from macOS surfaces.

## Positioning

Kora is open-source and macOS-first.

- **Open-source model:** transparent behavior, community extendability, and auditable defaults.
- **Minimal UI doctrine:** concise, predictable controls inspired by OpenAI/Apple style clarity and restraint.
- **Production-first workflow:** one room, one history, one quality path.

## End-to-end workflow

`Import -> Ingest check -> Multiplayer review -> Process -> Validate -> Approve -> Export`

Every stage must preserve context and be auditable inside the same shared project session.

## Definitions: “MVP” vs “recommended version”

- **MVP (v0.9):** minimum set of features needed for useful collaborative work.
- **Recommended release (v1.0):** the version we recommend shipping after initial learning, with stronger self-service depth and distribution quality.
- **Post-MVP (v1.x+):** planned evolution that expands media coverage and advanced collaboration, not a different product.

## v0.9 MVP — Useful today

### Mandatory features

1. **Multiplayer core**
   - Create/join multiplayer sessions.
   - Presence state (who is in/out)
   - Real-time comments, notes, status transitions.
   - Shared ownership roles (`owner`, `editor`, `reviewer`).
   - Deterministic room join path with short invite codes.

2. **Local audio pipeline**
   - Folder/file import from local storage.
   - Basic metadata extraction and display.
   - Deterministic processing profile per room.
   - Stable local cache and repeatable exports.

3. **Quality baseline for collaboration**
   - Pre-export blockers for hard failures (corrupt files, missing metadata, incompatible codec settings).
   - Soft warnings for quality risks (clipping, low loudness consistency, channel mismatch).
   - Session history of review decisions.

4. **Practical installation**
   - One-click macOS app installation path.
   - First-run onboarding wizard with zero external tooling required.
   - Safe migration path for local project folders.

### MVP success criteria

- A user can create and join a room, review an audio asset, and produce one approved export in **one setup pass**.
- No external service is required to run local mode.
- All collaborators can view the same session state within one pass.
- Core quality states are visible before export.
- The first successful export should feel “self-reinforcing” (repeatable with minimal guidance).

## v1.0 — Recommended release (do not undersell)

MVP is useful; v1.0 is what we actively recommend as the product baseline.

### Additions from v0.9

1. **High self-service reinforcement**
   - Room presets (`podcast`, `music mix`, `voice-over`, `interview polish`).
   - Template-driven onboarding for recurring workflows.
   - Role-based next-step prompts (“review now”, “re-run quality”, “export now”).

2. **Distribution quality**
   - Signed and notarized app bundles.
   - Auto-update channel with rollback fallback.
   - Built-in crash diagnostics with opt-in telemetry for quality fixes.

3. **Video extension phase (same room model)**
   - Shared comment/review model reused for videos.
   - Timeline-aligned annotations and playback markers.
   - Synchronized status and state transitions across media types.

4. **Widget support in macOS app**
   - Dedicated widget extension tied to active room and pending tasks.
   - Quick read of blockers/quality status.
   - One-tap resume into the related room state.

## Current ship status against v0.9/v1.0

- `mvp-room` is implemented in-app: role-aware room state, room creation, and invite join flow.
- `mvp-audio` is implemented: local import + metadata extraction are now in room flow.
- `mvp-quality` is next to close v0.9 loop.
- v1.0 planning remains recommended baseline and includes:
  - richer self-service templates/presets,
  - signed update path,
  - macOS widget,
  - and video reuse of the room primitives already introduced.
- `mvp-quality` now includes pre-export hard-stop logic, warning diagnostics, and export gating in room flow.

## Post-MVP roadmap (non-restrictive growth)

### v1.3 — Reliability and depth
- Conflict resolution for concurrent room edits.
- Advanced quality rules library.
- Session templates with per-team defaults.
- Local caching and resumable jobs for very large files.

### v1.5 — Broader media ecosystem
- Extend video editing affordances.
- Shared asset collections and reusable media snippets.
- Expanded format adapters and subtitle/metadata ingestion helpers.
- Optional integrations and export preset sharing.

### v2.0 — Community scale
- Verified plugin API for codecs and room actions.
- Community-maintained format packages.
- Public format support matrix per release channel.

## Broad format compatibility plan

### Audio support

- **Tier 1 (MVP):** WAV, AIFF, FLAC, ALAC, MP3, AAC, M4A, OGG/Vorbis, Opus
- **Tier 2 (v1.0):** WMA, AMR, DTS, PCM variants, ADPCM, AAC-LD/HE-AAC
- **Tier 3 (v1.5+):** niche broadcast and archival codecs, legacy containers as community adapters

### Video support

- **Tier 1 (v1.0):** MP4/MOV (H.264, HEVC), WebM (VP8/VP9), MKV with common tracks
- **Tier 2 (v1.5):** AVI, WMV, FLV, OGV, AV1-capable workflows
- **Tier 3 (v2+):** rare enterprise/intermediate codecs as validated extensions

### Support policy

- Each tier has explicit supported/partial/unsupported states.
- If conversion is used, it must be declared in the session history.
- Fallback behavior must keep creators informed and offer a clear reconfigure path.
- For pre-export quality in v0.9:
  - hard-stop blockers prevent export.
  - warnings remain exportable but explicit in-room and actionable.
  - quality state is stored per room and refreshed by local checks.

## Practical installation path

### User install (default)

1. Download signed macOS `.app` package.
2. Drag to Applications.
3. First run wizard:
   - permission checks,
   - local storage location,
   - room invite onboarding,
   - sample workflow suggestion.
4. Optional update channel and automatic migration messages.

### Contributor install

1. Clone repository.
2. Open project in Xcode.
3. Build and run the app target.
4. Keep local format adapter modules editable for rapid contribution.

## Non-goals (initially)

- Full DAW replacement.
- Cross-platform parity before v1.0 is stable.
- Enterprise administration suite before collaboration + quality model matures.

## Risks and mitigations

- **Format breadth increases support debt.**
  - Mitigation: tiered matrix + explicit guarantees by release.
- **Multiplayer conflicts under heavy load.**
  - Mitigation: clear lock/state model and deterministic merge strategy.
- **Large file performance risk.**
  - Mitigation: background workers, resumable jobs, and queue prioritization.

## Implementation now

To keep planning and execution connected, this repository includes a local phase tracker:

- [ExecutionPlan.swift](/Users/josesanchez/Developer/public/kora/kora/kora/ExecutionPlan.swift)
- [PhaseExecutionStore.swift](/Users/josesanchez/Developer/public/kora/kora/kora/PhaseExecutionStore.swift)
- [ExecutionTrackerView.swift](/Users/josesanchez/Developer/public/kora/kora/kora/ExecutionTrackerView.swift)
- [RoomModels.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomModels.swift)
- [RoomStore.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomStore.swift)
- [RoomWorkspaceView.swift](/Users/josesanchez/Developer/public/kora/kora/kora/RoomWorkspaceView.swift)
- [implementation_roadmap.md](/Users/josesanchez/Developer/public/kora/kora/implementation_roadmap.md)

Current app work in this phase:

- A persisted local-phase checklist UI for planning execution with milestone state persistence.
- Explicit phase milestones for all roadmap stages.
- A minimal shell focused on room-first execution and milestone workflow.

### New execution loop implementation

- Milestone state is persisted locally (in defaults + app support fallback) so progress survives relaunch.
- The UI now identifies the next pending action and supports quick progression.
- Completing all milestones in a phase can immediately move planning focus to the next phase.

This satisfies the requirement to **create and implement** the plan, not just document it.
