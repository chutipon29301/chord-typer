# Phase 4: Chord Detection - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

The ChordEngine state machine collects simultaneous keypresses within a configurable timing window, evaluates on all-keys-released, produces a sorted-alphabetical chord key for dictionary lookup, and either signals a match or replays all original keystrokes. This phase delivers the core chord detection algorithm — it plugs into EventTapManager's eventHandler closure (D-13 from Phase 3) and returns results via a typed enum. No text output or dictionary loading yet — those are Phase 5 and 6 respectively.

</domain>

<decisions>
## Implementation Decisions

### Timing Window Behavior
- **D-01:** First keyDown opens the timing window — any keys pressed within 50ms of that first key are part of the chord. Simple, predictable, matches ZipChord behavior.
- **D-02:** A key arriving after the window closes starts a new chord cycle — the previous chord evaluates immediately on its own collected keys. Clean separation between chord cycles.
- **D-03:** If any modifier key (Cmd, Shift, Option, Control) is held during key collection, abort the chord and flush all buffered events as pass-through. Prevents accidental chord triggers during system shortcuts (Cmd+C, Cmd+V, etc.).
- **D-04:** Modifier detection via `CGEvent.flags` inspection on each keyDown — no changes to EventTapManager's event mask (D-14 stays keyDown+keyUp only). Check for `.maskCommand`, `.maskShift`, `.maskAlternate`, `.maskControl`.

### State Machine Design
- **D-05:** ChordEngine is a plain class with serial `DispatchQueue` for thread safety — matches EventTapManager pattern (D-02). CGEventTap callback is synchronous C code; can't await an actor. No async bridging overhead.
- **D-06:** Three states: `.idle` → `.collecting` → `.evaluating` → back to `.idle`. Transitions: keyDown triggers idle→collecting; all keys released or window expiry triggers collecting→evaluating; match or replay triggers evaluating→idle. Modifier abort triggers collecting→idle (flush all buffered events).
- **D-07:** Track held keys as `Set<UInt16>` of virtual keycodes — IME-independent, consistent regardless of keyboard layout. Convert to sorted-alphabetical character string only at evaluation time for dictionary lookup.
- **D-08:** Timing window expiry via `DispatchQueue.asyncAfter` with cancellable `DispatchWorkItem` — scheduled when entering collecting state, cancelled if all keys release before it fires. Runs on the same serial queue as state mutations.

### Key Replay on Mismatch
- **D-09:** Buffer original `CGEvent` objects during collection (ordered array). On mismatch, replay them via `CGEventPost` in the order received. Preserves exact key flags, timestamps, and modifier state.
- **D-10:** Buffer both keyDown AND keyUp events — replay the complete press/release sequence so target apps see proper key state cycles.
- **D-11:** Re-entry prevention via boolean `isReplaying` flag on ChordEngine. Set true before posting replay events, false after. In the event handler, if `isReplaying`, pass through immediately. Works because replay happens synchronously on the same serial queue.

### Integration Boundary
- **D-12:** AppDelegate owns ChordEngine — creates it and assigns the eventHandler closure to EventTapManager. ChordEngine is a peer of EventTapManager, not nested inside it. Consistent with AppDelegate already owning EventTapManager.
- **D-13:** `ChordEngine.process(event:type:)` returns a `ChordResult` enum: `.passThrough(CGEvent)`, `.suppress`, `.chord(key: String, buffered: [CGEvent])`. The eventHandler closure maps this to `CGEvent?` for the tap. Phase 6 extends handling of `.chord(...)` for text output.
- **D-14:** Injectable `chordLookup: (String) -> String?` closure on ChordEngine — defaults to `{ _ in nil }` (no matches). Phase 4 tests inject a hardcoded dictionary `{ "eht": "the", "adn": "and" }`. Phase 5 replaces with DictionaryManager. Enables testing the full detect→match→signal path.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Specification
- `spec.md` — Full project specification including CGEventTap architecture, event processing pipeline, chord detection algorithm description, and API details
- `CLAUDE.md` — Technology stack (CGEventTap API), file responsibilities (ChordDetector.swift), coding conventions (sorted-alphabetical key encoding, no force unwraps, os.log), testing conventions

### Requirements
- `.planning/REQUIREMENTS.md` §Chord Detection — CHRD-01 through CHRD-05 defining timing window, minimum keys, order independence, all-keys-released evaluation, and unmatched chord replay

### Roadmap
- `.planning/ROADMAP.md` §Phase 4 — Success criteria (sorted-alpha key detection, order independence, all-keys-released, 3-key minimum, unmatched replay, make build && make test)

### Prior Phase Context
- `.planning/phases/03-cgeventtap/03-CONTEXT.md` — Phase 3 decisions: EventTapManager architecture (D-02 serial queue, D-13 eventHandler closure, D-14 keyDown+keyUp mask), permission handling, tap state enum
- `.planning/phases/02-menubar-skeleton/02-CONTEXT.md` — Phase 2 decisions: @AppStorage keys, icon states
- `.planning/phases/01-project-scaffold/01-CONTEXT.md` — Phase 1 decisions: @main App struct, SWIFT_STRICT_CONCURRENCY=complete, bundle ID

### Source Code
- `Sources/ChordTyper/EventTapManager.swift` — EventTapManager with `eventHandler` closure hook (line 26), `handleEvent()` method (line 158) that Phase 4 plugs into
- `Sources/ChordTyper/AppDelegate.swift` — AppDelegate that owns EventTapManager, will also own ChordEngine

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EventTapManager.eventHandler: ((CGEvent) -> CGEvent?)?` — the closure hook for Phase 4 to plug chord detection into (currently nil = pass-through)
- `EventTapManager.handleEvent(type:event:)` — dispatches to eventHandler on keyDown/keyUp, handles tap disable recovery
- `TapState` enum (`.running`, `.stopped`, `.noPermission`) — pattern for ChordEngine's own state enum

### Established Patterns
- Plain class + serial `DispatchQueue` for thread safety (not actors) — EventTapManager uses this, ChordEngine should match
- Injectable closures for testability — EventTapManager uses `permissionChecker`, `tapCreator`, etc. ChordEngine should use injectable `chordLookup`
- `os.Logger(subsystem:category:)` for all logging — ChordEngine uses category "ChordEngine"
- `@unchecked Sendable` annotation for manually thread-safe classes

### Integration Points
- `AppDelegate` — add ChordEngine creation and wire `eventTapManager.eventHandler = { engine.process(event:type:) }` mapping
- `EventTapManager.handleEvent()` line 167-169 — currently calls `eventHandler?(event) ?? event`. ChordEngine's process() return value maps: `.passThrough(event)` → return event, `.suppress` → return nil, `.chord(...)` → Phase 6 handles output then return nil
- New file: `Sources/ChordTyper/ChordDetector.swift` (per CLAUDE.md file responsibilities) — contains ChordEngine class and ChordResult enum

</code_context>

<specifics>
## Specific Ideas

- CLAUDE.md names the file `ChordDetector.swift` and the class responsibility as "Timing window + chord recognition" — the class name `ChordEngine` fits this scope
- The `ChordResult.chord(key:buffered:)` case carries both the sorted-alpha key string AND the original buffered events — Phase 6 needs the key for dictionary lookup and may need the events for context
- Keycode-to-character conversion for sorted-alpha encoding: use `CGEvent` with a null source to map virtual keycodes to characters via `keyboardStringForKey` or a static lookup table for the standard US QWERTY layout (since chord keys are defined as lowercase English letters regardless of IME)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 4-Chord Detection*
*Context gathered: 2026-05-22*
