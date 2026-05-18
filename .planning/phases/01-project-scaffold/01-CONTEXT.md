# Phase 1: Project Scaffold - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

A CLI-buildable macOS app skeleton: project.yml (xcodegen), Makefile with build/run/test/dmg/clean targets, folder structure (Sources/, Resources/, Tests/), Info.plist with LSUIElement=YES, entitlements with accessibility permission, and a passing XCTest target. No runtime functionality beyond a placeholder menubar icon.

</domain>

<decisions>
## Implementation Decisions

### Entry Point Pattern
- **D-01:** Use `@main` App struct (pure SwiftUI entry point) with a minimal `MenuBarExtra` stub — placeholder text only ("ChordTyper is running")
- **D-02:** No `@NSApplicationDelegateAdaptor` in Phase 1 — added in Phase 2 when lifecycle hooks are needed for menubar setup
- **D-03:** No separate `main.swift` file — `@main` attribute on the App struct serves as the entry point

### Test Target Scope
- **D-04:** Single smoke test class (`ChordTyperSmokeTests`) with one test that verifies the test pipeline works
- **D-05:** Each subsequent phase adds its own test files — no pre-created stubs for future phases

### Swift Concurrency Mode
- **D-06:** `SWIFT_STRICT_CONCURRENCY=complete` enabled from Phase 1 in project.yml
- **D-07:** Swift 6 strict mode — all files written from this phase onward must be concurrency-safe. No `@unchecked Sendable` workarounds.

### Bundle Identifier
- **D-08:** Bundle ID is `dev.chutipon.chordtyper` (reverse-domain of chutipon.dev, all lowercase)
- **D-09:** Used in project.yml `PRODUCT_BUNDLE_IDENTIFIER`, entitlements, and smoke test assertions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specification
- `spec.md` — Full project specification including architecture, project structure, chord detection mechanism, and dictionary format
- `CLAUDE.md` — Technology stack details, project.yml skeleton, Makefile pattern, file responsibilities, coding conventions, and build commands

### Requirements
- `.planning/REQUIREMENTS.md` §Scaffold — SCAF-01 through SCAF-05 defining scaffold requirements

### Roadmap
- `.planning/ROADMAP.md` §Phase 1 — Success criteria (xcodegen generates valid .xcodeproj, make build compiles, make test passes, LSUIElement=YES, entitlements declare accessibility)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None — this phase establishes the patterns all subsequent phases follow

### Integration Points
- project.yml defines the build configuration that all phases depend on
- Makefile targets (build, test, run, dmg, clean) are the CI-equivalent gates for every phase
- Folder structure (Sources/ChordTyper/, Resources/, Tests/ChordTyperTests/) is the namespace for all future files

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. CLAUDE.md already contains detailed project.yml skeleton and Makefile patterns to follow.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-Project Scaffold*
*Context gathered: 2026-05-18*
