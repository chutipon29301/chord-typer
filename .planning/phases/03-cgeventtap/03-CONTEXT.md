# Phase 3: CGEventTap - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

The app installs a CGEventTap to capture all keydown and keyup events at session level, checks Accessibility permission on launch (with user guidance if missing), and passes all events through unchanged. This phase establishes the low-level event interception pipeline — EventTapManager owns the tap lifecycle, exposes a closure-based handler for Phase 4 to plug chord detection into, and publishes tap state for menubar UI reflection. No events are modified or suppressed yet.

</domain>

<decisions>
## Implementation Decisions

### EventTap Lifecycle
- **D-01:** Dedicated `EventTapManager` class owns the tap lifecycle (create, enable, disable, destroy) — separate from AppDelegate for clean responsibility separation
- **D-02:** Plain class with serial `DispatchQueue` for state mutations, not an actor — CGEventTap callback is a C function pointer that can't be async; avoids actor/async bridging overhead in the hot path
- **D-03:** Create tap on app launch (`applicationDidFinishLaunching`) — provides immediate permission feedback to user
- **D-04:** Introduce AppDelegate via `@NSApplicationDelegateAdaptor(AppDelegate.self)` in `ChordTyperApp` — SwiftUI `@main` App struct stays the entry point

### Permission UX
- **D-05:** Show `NSAlert` with "Open Settings" button on launch when Accessibility permission is missing — modal dialog with clear guidance
- **D-06:** After alert dismissal, poll `CGPreflightListenEventAccess()` every 2 seconds; auto-create tap when permission is granted; stop polling after ~60s to avoid resource waste
- **D-07:** Use `CGPreflightListenEventAccess()` for permission check (not `AXIsProcessTrusted()`) — more precisely checks event tap permission
- **D-08:** App keeps running in paused state if permission not granted — menubar menu shows "Grant Accessibility Permission" item so user can grant later without relaunching

### Resilience Strategy
- **D-09:** On `kCGEventTapDisabledByTimeout`, immediately re-enable via `CGEvent.tapEnable(tap:enable:)` inside the callback — standard pattern (Ghostty, Hammerspoon), log via `os.log`
- **D-10:** Subscribe to `NSWorkspace.didWakeNotification` for sleep/wake recovery — verify tap's RunLoopSource validity on wake, destroy and recreate if needed, re-check permission
- **D-11:** Add `tccutil reset Accessibility dev.chutipon.chordtyper` to Makefile `run` target — prevents TCC silent-disable issue during development after rebuilds
- **D-12:** Detect permission revocation via tap failure (nil from `CGEventTapCreate` or events stop arriving) — no active polling for revocation; show permission alert again and enter paused state

### Event Pass-Through Design
- **D-13:** Closure-based handler property on `EventTapManager`: `eventHandler: ((CGEvent) -> CGEvent?)` — Phase 3 sets pass-through (return event unchanged); Phase 4 replaces with chord detection logic. Clean hook point, no EventTapManager changes needed later
- **D-14:** Intercept `.keyDown` and `.keyUp` events only via `CGEventMask` — modifier keys (`.flagsChanged`) skipped for now; sufficient for chord detection
- **D-15:** Install tap at session level (`kCGSessionEventTap`) as specified in EVNT-01 — sufficient for chord detection; if Thai IME issues surface in Phase 6, tap level can be revisited
- **D-16:** EventTapManager publishes tap state (e.g., enum: `.running`, `.stopped`, `.noPermission`) via observable property — AppDelegate bridges to SwiftUI so menubar icon/menu can reflect actual tap state beyond just the user toggle

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specification
- `spec.md` — Full project specification including CGEventTap architecture, event processing pipeline, and API details
- `CLAUDE.md` — Technology stack (CGEventTap API details, CGPreflightListenEventAccess), file responsibilities (EventTap.swift), coding conventions, build commands

### Requirements
- `.planning/REQUIREMENTS.md` §Event Tap — EVNT-01 through EVNT-05 defining event tap requirements

### Roadmap
- `.planning/ROADMAP.md` §Phase 3 — Success criteria (transparent keystroke pass-through, permission guidance, timeout re-enable, sleep/wake recovery, make build && make test)

### Prior Phase Context
- `.planning/phases/01-project-scaffold/01-CONTEXT.md` — Phase 1 decisions: @main App struct, SWIFT_STRICT_CONCURRENCY=complete, bundle ID dev.chutipon.chordtyper, entitlements structure
- `.planning/phases/02-menubar-skeleton/02-CONTEXT.md` — Phase 2 decisions: @NSApplicationDelegateAdaptor deferred to Phase 3 (D-09), @AppStorage keys (chordTyperEnabled, englishEnabled, thaiEnabled), keyboard.fill/keyboard.badge.ellipsis icon states

### Project Configuration
- `project.yml` — xcodegen config with entitlements path, ad-hoc signing, ENABLE_HARDENED_RUNTIME: NO, accessibility entitlement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sources/ChordTyper/ChordTyperApp.swift` — existing `@main` App struct with `MenuBarExtra`, `@AppStorage("chordTyperEnabled")` state. Add `@NSApplicationDelegateAdaptor(AppDelegate.self)` here.
- `Resources/ChordTyper.entitlements` — already declares `com.apple.security.temporary-exception.accessibility: true`

### Established Patterns
- Pure SwiftUI entry point with `@main` attribute — AppDelegate added via adaptor, not replacement
- `SWIFT_STRICT_CONCURRENCY=complete` — EventTapManager must be concurrency-safe; the C callback context must bridge safely
- `os.log` via `Logger(subsystem:category:)` for all logging — never `print()`
- `@AppStorage` for persisted user state — EventTapManager reads `chordTyperEnabled` to know whether to process events

### Integration Points
- `ChordTyperApp.swift` — add `@NSApplicationDelegateAdaptor(AppDelegate.self)`
- New `AppDelegate.swift` — owns EventTapManager lifecycle, bridges tap state to SwiftUI
- New `EventTapManager.swift` — the core of this phase (corresponds to `EventTap.swift` in CLAUDE.md file responsibilities)
- `Makefile` — add `tccutil reset` to `run` target
- `project.yml` — may need adjustment if new source files require explicit listing (currently uses path-based source inclusion)

</code_context>

<specifics>
## Specific Ideas

- Note the discrepancy: CLAUDE.md recommends `.cghidEventTap` (HID level) for Thai IME compatibility, but EVNT-01 and this discussion chose `kCGSessionEventTap` (session level). Session level is the starting point — if Thai output issues arise in Phase 6, escalate to HID level as a targeted fix.
- `CGPreflightListenEventAccess()` was chosen over `AXIsProcessTrusted()` — pair with `CGRequestListenEventAccess()` to trigger the system permission prompt when needed.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 3-CGEventTap*
*Context gathered: 2026-05-21*
