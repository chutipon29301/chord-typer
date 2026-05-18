# Phase 2: Menubar Skeleton - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The app launches as a menubar-only app (no Dock icon, no main window) with a working icon that reflects active/paused state, a dropdown menu with toggle, dictionary submenu, Settings stub, Open Dictionary Folder, and Quit. All menu items are wired to persisted state via @AppStorage, but no runtime chord logic exists yet — this is the UI shell that later phases plug into.

</domain>

<decisions>
## Implementation Decisions

### Menu Style
- **D-01:** Use `.menuBarExtraStyle(.menu)` — standard macOS dropdown menu, native feel, lightweight
- **D-02:** No `.window` popover — keep it consistent with utility apps like Amphetamine/Raycast

### Menu Layout
- **D-03:** Dictionary toggles nested under a "Dictionaries" submenu — cleaner top level
- **D-04:** Top-level structure: "Enable ChordTyper" toggle → Divider → "Dictionaries >" submenu → Divider → "Settings..." / "Open Dictionary Folder" → Divider → "Quit ChordTyper"
- **D-05:** Toggle label is "Enable ChordTyper" with checkmark when active

### Icon States
- **D-06:** Active state icon: `keyboard.fill` (solid SF Symbol)
- **D-07:** Paused state icon: `keyboard.badge.ellipsis` — visually distinct from active, stays in keyboard metaphor
- **D-08:** Icon changes dynamically based on @AppStorage("chordTyperEnabled") state

### App Architecture
- **D-09:** No `@NSApplicationDelegateAdaptor` in Phase 2 — pure SwiftUI MenuBarExtra handles everything needed. AppDelegate deferred to Phase 3 for CGEventTap lifecycle
- **D-10:** Active/paused state stored in `@AppStorage("chordTyperEnabled")` — persists across app restarts
- **D-11:** Dictionary enabled states stored in `@AppStorage("englishEnabled")` and `@AppStorage("thaiEnabled")`

### Menu Item Behavior
- **D-12:** All menu items fully wired to state — toggle flips @AppStorage, icon changes, dictionary checkmarks toggle
- **D-13:** App defaults to active on first launch (no prior @AppStorage value)
- **D-14:** "Settings..." logs to os_log only — placeholder until Phase 8
- **D-15:** "Open Dictionary Folder" opens the app bundle's `Resources/dictionaries/` folder via NSWorkspace
- **D-16:** "Quit ChordTyper" calls `NSApplication.shared.terminate(nil)` — works now

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specification
- `spec.md` — Full project specification including architecture, MenuBarExtra patterns, and SF Symbol usage
- `CLAUDE.md` — Technology stack details, file responsibilities (ChordTyperApp.swift entry point), coding conventions, and build commands

### Requirements
- `.planning/REQUIREMENTS.md` §Menubar — MENU-01 through MENU-04 defining menubar requirements

### Roadmap
- `.planning/ROADMAP.md` §Phase 2 — Success criteria (no Dock icon, icon with active/paused states, dropdown menu items, quit action, make build && make test passes)

### Prior Phase Context
- `.planning/phases/01-project-scaffold/01-CONTEXT.md` — Phase 1 decisions: @main App struct, no AppDelegate yet, SWIFT_STRICT_CONCURRENCY=complete, bundle ID dev.chutipon.chordtyper

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sources/ChordTyper/ChordTyperApp.swift` — existing @main App struct with MenuBarExtra stub using `keyboard` SF Symbol and `.menuBarExtraStyle(.menu)`. This file gets evolved, not replaced.

### Established Patterns
- Pure SwiftUI entry point with `@main` attribute — no separate main.swift
- `SWIFT_STRICT_CONCURRENCY=complete` — all new code must be concurrency-safe
- `os.log` for logging, never `print()`

### Integration Points
- `ChordTyperApp.swift` is the single file modified in this phase — evolve the MenuBarExtra body
- `Resources/dictionaries/` folder already exists from Phase 1 — "Open Dictionary Folder" points here
- @AppStorage keys established here (`chordTyperEnabled`, `englishEnabled`, `thaiEnabled`) become the interface for later phases (Phase 3 reads enabled state, Phase 5 reads dictionary flags)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The menu structure and icon choices are fully specified in the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 2-Menubar Skeleton*
*Context gathered: 2026-05-19*
