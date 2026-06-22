import Foundation

struct KoraMilestone: Identifiable, Hashable {
    let id: String
    let title: String
    let ownerHint: String
    let artifactHint: String
}

enum KoraPhase: Int, CaseIterable, Identifiable, Hashable {
    case planning = 0
    case mvp
    case v10
    case v13
    case v15
    case v2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .planning:
            "Phase 0 — Plan Stabilization"
        case .mvp:
            "Phase 1 — v0.9 Multiplayer MVP"
        case .v10:
            "Phase 2 — v1.0 Recommended Baseline"
        case .v13:
            "Phase 3 — v1.3 Reliability"
        case .v15:
            "Phase 4 — v1.5 Media Expansion"
        case .v2:
            "Phase 5 — v2.0 Community Scale"
        }
    }

    var goal: String {
        switch self {
        case .planning:
            "Align docs, repo structure, and delivery definition with explicit acceptance criteria."
        case .mvp:
            "Ship a practical multiplayer audio loop with self-service quality checks."
        case .v10:
            "Deliver signed install path, widget extension, and video extension model reuse."
        case .v13:
            "Harden concurrency, quality rules, and resilience for larger teams/files."
        case .v15:
            "Expand supported media format surface and richer production features."
        case .v2:
            "Open plugin architecture for codecs and room actions with community contribution pathways."
        }
    }

    var milestones: [KoraMilestone] {
        switch self {
        case .planning:
            return [
                .init(
                    id: "plan-docs",
                    title: "Finalize phase docs (README, product, design)",
                    ownerHint: "PM + Eng lead",
                    artifactHint: "product.md, design.md, implementation_roadmap.md"
                ),
                .init(
                    id: "scope-contract",
                    title: "Define explicit in-scope/out-of-scope for v0.9 and v1.0",
                    ownerHint: "PM",
                    artifactHint: "Section added in product.md"
                ),
                .init(
                    id: "success-metrics",
                    title: "Define measurable success gates and KPI targets",
                    ownerHint: "Product",
                    artifactHint: "Metrics table in product.md"
                )
            ]
        case .mvp:
            return [
                .init(
                    id: "mvp-room",
                    title: "Create room model, invites, and role state",
                    ownerHint: "Backend + Client",
                    artifactHint: "Room schema + collaboration logic"
                ),
                .init(
                    id: "mvp-audio",
                    title: "Implement local audio import + metadata extraction",
                    ownerHint: "Core media",
                    artifactHint: "Local ingest + audio parser"
                ),
                .init(
                    id: "mvp-quality",
                    title: "Add pre-export quality checks and hard-stop blockers",
                    ownerHint: "Quality + UI",
                    artifactHint: "Quality checkpoint pipeline"
                ),
                .init(
                    id: "mvp-ui",
                    title: "Ship minimal, fast room-first flow",
                    ownerHint: "SwiftUI",
                    artifactHint: "Focused room review UI"
                )
            ]
        case .v10:
            return [
                .init(
                    id: "v10-distribution",
                    title: "Implement signed packaging, updater, and migration path",
                    ownerHint: "Release",
                    artifactHint: "Installer + release pipeline"
                ),
                .init(
                    id: "v10-widget",
                    title: "Add macOS widget for active room and blockers",
                    ownerHint: "Client",
                    artifactHint: "WidgetKit extension"
                ),
                .init(
                    id: "v10-video-layer",
                    title: "Add video-room metadata model and UI branch",
                    ownerHint: "Core media + UI",
                    artifactHint: "Shared room primitives + video path"
                ),
                .init(
                    id: "v10-reinforcement",
                    title: "Ship task templates and role-aware next actions",
                    ownerHint: "Product + UI",
                    artifactHint: "Template and prompt system"
                )
            ]
        case .v13:
            return [
                .init(
                    id: "v13-conflict",
                    title: "Handle concurrent edit conflicts predictably",
                    ownerHint: "Backend",
                    artifactHint: "Conflict resolver spec + implementation"
                ),
                .init(
                    id: "v13-jobs",
                    title: "Add resumable job queue for large files",
                    ownerHint: "Core media",
                    artifactHint: "Queue engine + persistence"
                ),
                .init(
                    id: "v13-history",
                    title: "Improve audit trail and version history",
                    ownerHint: "Product",
                    artifactHint: "Review timeline with decision metadata"
                )
            ]
        case .v15:
            return [
                .init(
                    id: "v15-formats",
                    title: "Add second-tier video+audio codec adapters",
                    ownerHint: "Media",
                    artifactHint: "Adapter registry + tests"
                ),
                .init(
                    id: "v15-assets",
                    title: "Build reusable media collections and snippets",
                    ownerHint: "UI + Data",
                    artifactHint: "Collections view and persistence"
                ),
                .init(
                    id: "v15-subtitles",
                    title: "Add subtitle and metadata ingestion pipeline",
                    ownerHint: "Core media",
                    artifactHint: "Metadata import service"
                )
            ]
        case .v2:
            return [
                .init(
                    id: "v2-plugin",
                    title: "Introduce plugin API surface for codecs and actions",
                    ownerHint: "Core",
                    artifactHint: "Extension protocol + docs"
                ),
                .init(
                    id: "v2-matrix",
                    title: "Publish per-release format matrix and maintenance tags",
                    ownerHint: "Product",
                    artifactHint: "Format matrix automation"
                )
            ]
        }
    }
}
