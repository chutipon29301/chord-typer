# Phase 4: Chord Detection - Research

**Researched:** 2026-05-22
**Domain:** Swift state machine, CGEvent keycode mapping, DispatchQueue timing, XCTest
**Confidence:** HIGH

## Summary

Phase 4 adds `ChordDetector.swift` to the existing codebase, implementing a `ChordEngine` class
that plugs into `EventTapManager.eventHandler` and converts raw CGEvent key streams into chord
decisions. The architecture is fully locked by CONTEXT.md decisions (D-01 through D-14) — this
is an implementation research document, not an exploratory one.

The core algorithm is a three-state machine (`.idle` → `.collecting` → `.evaluating` → `.idle`)
guarded by a serial `DispatchQueue`. Timing is managed by a cancellable `DispatchWorkItem`.
Key identity uses `UInt16` virtual keycodes stored in a `Set`; the sorted-alphabetical chord
key is derived at evaluation time. The boundary with Phase 5 (dictionary) is clean: a
`chordLookup: (String) -> String?` injectable closure defaults to `{ _ in nil }` so Phase 4
tests can inject a hardcoded dictionary.

The single most dangerous pitfall in this phase is re-entry: the CGEventTap callback will see
the replayed events that ChordEngine posts during mismatch. This is addressed by the `isReplaying`
boolean flag (D-11) — getting this exactly right is critical.

**Primary recommendation:** Implement ChordEngine as a plain class + serial DispatchQueue (not
actor) matching the EventTapManager pattern already in the codebase, and test the full state
machine with synchronous mock injection — no real CGEventTap required.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Timing Window Behavior**
- D-01: First keyDown opens the timing window — keys pressed within 50ms of first key are part of the chord.
- D-02: A key arriving after the window closes starts a new chord cycle; previous chord evaluates immediately.
- D-03: Any modifier key (Cmd, Shift, Option, Control) held during collection aborts the chord; flush all buffered events as pass-through.
- D-04: Modifier detection via `CGEvent.flags` inspection on each keyDown — no changes to EventTapManager's event mask.

**State Machine Design**
- D-05: ChordEngine is a plain class with serial `DispatchQueue` — not an actor (CGEventTap callback is synchronous C code; cannot await).
- D-06: Three states: `.idle` → `.collecting` → `.evaluating` → `.idle`. Modifier abort: `.collecting` → `.idle` (flush events).
- D-07: Track held keys as `Set<UInt16>` of virtual keycodes. Convert to sorted-alphabetical character string only at evaluation time.
- D-08: Timing window expiry via `DispatchQueue.asyncAfter` with cancellable `DispatchWorkItem`. Runs on the same serial queue as state mutations.

**Key Replay on Mismatch**
- D-09: Buffer original `CGEvent` objects (ordered array). On mismatch, replay via `CGEventPost` in received order.
- D-10: Buffer both keyDown AND keyUp events — replay the complete press/release sequence.
- D-11: Re-entry prevention via boolean `isReplaying` flag. Set true before replay, false after. If `isReplaying`, pass through immediately.

**Integration Boundary**
- D-12: AppDelegate owns ChordEngine — creates it and assigns the eventHandler closure to EventTapManager.
- D-13: `ChordEngine.process(event:type:)` returns `ChordResult` enum: `.passThrough(CGEvent)`, `.suppress`, `.chord(key: String, buffered: [CGEvent])`.
- D-14: Injectable `chordLookup: (String) -> String?` closure on ChordEngine — defaults to `{ _ in nil }`. Phase 4 tests inject hardcoded dict.

### Claude's Discretion

None — all decisions were locked in the context discussion.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHRD-01 | Chord detection uses configurable timing window (50ms default, 20-200ms range) | D-01, D-08: DispatchWorkItem timer on serial queue; `timingWindowMs: TimeInterval` property on ChordEngine |
| CHRD-02 | Minimum 3 keys required to trigger chord evaluation | D-06: evaluation gate checks `heldKeys.count >= 3` before producing `.chord(...)` |
| CHRD-03 | Key order does not matter (T+H+E = H+E+T = E+T+H) | D-07: `Set<UInt16>` is order-independent; sorted-alpha encoding at evaluation time |
| CHRD-04 | Chord evaluated on all-keys-released, not on keydown | D-06: state transitions to `.evaluating` only when keyUp brings `heldKeys` to empty |
| CHRD-05 | Unmatched chord passes through all keys in original order (no keystroke loss) | D-09, D-10, D-11: buffered CGEvent array replayed via CGEventPost with re-entry guard |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Keystroke interception | Driver/kernel (CGEventTap) | — | Already implemented in EventTapManager; ChordEngine is a consumer, not a tap owner |
| Chord state machine | Background queue (ChordEngine) | — | Serial DispatchQueue matches EventTapManager pattern; runs off main thread |
| Timing window management | Background queue (DispatchWorkItem) | — | asyncAfter on same queue ensures no state race |
| Key → chord string encoding | Background queue (ChordEngine) | — | Pure transformation at evaluation time |
| Dictionary lookup | Injectable closure (chordLookup) | Phase 5 DictionaryManager | Phase 4 leaves this as `{ _ in nil }` stub |
| Result routing | AppDelegate (eventHandler closure) | — | Maps ChordResult to CGEvent? for tap callback |
| Replay (mismatch) | Background queue (ChordEngine) | CGEventPost | Synchronous on ChordEngine queue before returning from process() |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation | macOS 13+ | DispatchQueue, DispatchWorkItem, asyncAfter | Only option for GCD on Apple platforms — no alternatives [CITED: developer.apple.com/documentation/foundation] |
| CoreGraphics | macOS 13+ | CGEvent, CGEventPost, CGEventField, CGEventFlags | Only API for reading/posting synthetic key events at HID level [CITED: developer.apple.com/documentation/coregraphics] |
| os.Logger | macOS 11+ | Structured logging | Already established in EventTapManager; required by CLAUDE.md [VERIFIED: existing codebase] |
| XCTest | Xcode 16.4 | Unit tests | Already established test framework in project [VERIFIED: existing codebase] |

### No External Dependencies

Per CLAUDE.md constraint: zero third-party dependencies. All phase 4 capabilities are achievable
with Foundation + CoreGraphics alone.

**Installation:** No new packages. All required frameworks are already linked in project.yml.

---

## Package Legitimacy Audit

No new packages are introduced in this phase. All capabilities are implemented using Apple-
provided system frameworks. This section is intentionally empty.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
CGEventTap callback (RunLoop thread, C code)
         │
         ▼
EventTapManager.handleEvent(type:event:)   [serial queue: eventtap]
         │
         │  calls eventHandler closure (set by AppDelegate)
         ▼
ChordEngine.process(event:type:)           [serial queue: chordengine]
         │
         ├─ isReplaying == true ──► return .passThrough(event)
         │
         ├─ type == .keyDown
         │    ├─ modifier held? ──────────────► abort: flush bufferedEvents → return .passThrough each
         │    ├─ state == .idle ────────────── open window, → .collecting
         │    ├─ state == .collecting
         │    │    ├─ key inside window? ─── add to heldKeys + bufferedEvents
         │    │    └─ key outside window? ── evaluate previous chord, start new cycle
         │    └─ (add keyDown to bufferedEvents always)
         │
         ├─ type == .keyUp
         │    ├─ remove key from heldKeys
         │    ├─ add keyUp to bufferedEvents (D-10)
         │    └─ heldKeys.isEmpty? ────────── all released → evaluate chord
         │
         └─ evaluate(bufferedEvents, heldKeys)
              ├─ heldKeys.count < 3 ───────── return .passThrough (replay)
              ├─ chordLookup(sortedKey) != nil ► return .chord(key:buffered:)
              └─ no match ─────────────────── isReplaying=true, CGEventPost each, isReplaying=false
                                               return .suppress (events already posted)
```

### Recommended Project Structure

```
Sources/ChordTyper/
├── ChordDetector.swift     # ChordEngine class + ChordResult enum (NEW — this phase)
├── EventTapManager.swift   # unchanged
├── AppDelegate.swift       # add ChordEngine creation + wire eventHandler (small edit)
└── ChordTyperApp.swift     # unchanged
Tests/ChordTyperTests/
├── ChordEngineTests.swift  # new test file covering all state machine paths (NEW)
├── EventTapManagerTests.swift  # unchanged
└── ...
```

### Pattern 1: State Machine with Serial DispatchQueue

**What:** All mutable state (`_state`, `heldKeys`, `bufferedEvents`, `isReplaying`, `windowWorkItem`)
lives in private vars guarded by a single serial DispatchQueue. Public entry point `process(event:type:)`
dispatches synchronously (`queue.sync`) so it can return a value to the CGEventTap caller.

**When to use:** When a class must be Sendable, called from a non-async C callback, and owns
timing state that must not be accessed concurrently.

**Why not actor:** Swift actors use cooperative scheduling with `await`. The CGEventTap C callback
cannot call `await` — it must return synchronously. `queue.sync` provides the same isolation
without async bridging. [CITED: developer.apple.com/documentation/dispatch/dispatchqueue — sync]

```swift
// Source: modelled on EventTapManager pattern (Sources/ChordTyper/EventTapManager.swift)
final class ChordEngine: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "dev.chutipon.chordtyper.chordengine",
        qos: .userInteractive
    )

    func process(event: CGEvent, type: CGEventType) -> ChordResult {
        queue.sync { _process(event: event, type: type) }
    }

    // All state mutations happen inside queue.sync — no locks needed
    private var _state: ChordEngineState = .idle
    private var _heldKeys: Set<UInt16> = []
    private var _bufferedEvents: [CGEvent] = []
    private var _isReplaying = false
    private var _windowWorkItem: DispatchWorkItem?
}
```

### Pattern 2: Cancellable Timing Window via DispatchWorkItem

**What:** When entering `.collecting`, schedule a `DispatchWorkItem` with `asyncAfter`. If all
keys release before it fires (the happy path), cancel it. If it fires first, evaluate
whatever was collected.

**Critical detail:** The work item must dispatch back onto the SAME serial queue, so it doesn't
race with keyDown/keyUp events arriving simultaneously.

```swift
// Source: Apple GCD docs — DispatchWorkItem cancellation pattern [CITED: developer.apple.com/documentation/dispatch/dispatchworkitem]
private func _openWindow() {
    let item = DispatchWorkItem { [weak self] in
        // Runs on self.queue (scheduled with asyncAfter below)
        self?._evaluateOnWindowExpiry()
    }
    _windowWorkItem = item
    queue.asyncAfter(deadline: .now() + timingWindowMs / 1000.0, execute: item)
}

private func _cancelWindow() {
    _windowWorkItem?.cancel()
    _windowWorkItem = nil
}
```

### Pattern 3: Sorted-Alphabetical Chord Key Encoding

**What:** At evaluation time, convert the `Set<UInt16>` of keycodes to a sorted array of
lowercase character strings, join them, and use as the dictionary lookup key.

**Key insight:** Virtual keycode 0 = 'a', 11 = 'b', etc. on US QWERTY, but these numeric
mappings are NOT portable across keyboard layouts. The safe approach is to use a static
lookup table for the 26 letter keys (standard keys that chord dictionaries use), mapping
each virtual keycode to its US QWERTY lowercase letter character. [ASSUMED — keycode layout
assumptions based on training knowledge; the table should be verified against
developer.apple.com/documentation/coregraphics/cgeventfield and IOKit HID usage tables.]

Alternatively, use `CGEvent(keyboardEventSource:virtualKey:keyDown:)` with a null source to
generate an event and then read its Unicode string via `CGEvent.keyboardGetUnicodeString` —
but this has IME interaction risk. The static table is simpler and deterministic.

```swift
// Source: training knowledge + codebase CLAUDE.md encoding spec [ASSUMED for keycode values]
private let keycodeToChar: [UInt16: Character] = [
    0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
    3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
    40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
    35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
    32: "u", 9: "v", 13: "w", 7: "x", 16: "y",
    6: "z"
]

func sortedChordKey(for keycodes: Set<UInt16>) -> String {
    keycodes
        .compactMap { keycodeToChar[$0] }
        .sorted()
        .map(String.init)
        .joined()
}
// T(17) + H(4) + E(14) → ["e","h","t"] sorted → "eht"
```

### Pattern 4: ChordResult Enum

**What:** A typed return value from `process(event:type:)` that the eventHandler closure maps
to `CGEvent?` for the tap callback.

```swift
// Source: CONTEXT.md D-13
enum ChordResult {
    /// Pass this event through unchanged (return it from the tap callback).
    case passThrough(CGEvent)
    /// Suppress this event (return nil from the tap callback).
    case suppress
    /// A chord was recognised. key = sorted-alpha lookup key.
    /// buffered = original events (for Phase 6 context / Phase 5 dict lookup).
    /// ChordEngine has already handled replay if no match — caller returns nil.
    case chord(key: String, buffered: [CGEvent])
}
```

### Pattern 5: Re-entry Guard (isReplaying)

**What:** When ChordEngine posts replay events via `CGEventPost`, those events flow back
through the CGEventTap callback and into `process(event:type:)`. Without a guard, each
replayed event would start a new chord cycle.

**Implementation:** Set `_isReplaying = true` synchronously before calling `CGEventPost`,
and reset to `false` after. Because `process()` is called via `queue.sync` from the tap
callback thread, and replay happens inside the same `queue.sync` block, no concurrency
risk exists. The check at the top of `_process()` short-circuits immediately.

```swift
// Source: CONTEXT.md D-11 + EventTapManager re-entry pattern
private func _replayEvents(_ events: [CGEvent]) {
    _isReplaying = true
    defer { _isReplaying = false }
    for event in events {
        CGEventPost(.cghidEventTap, event)
    }
}
```

**Warning:** `CGEventPost(.cghidEventTap, ...)` is synchronous on macOS — the event is
delivered before the call returns on the same thread. Because the tap callback runs on a
dedicated RunLoop thread, and our serial queue is separate from that RunLoop, the re-entry
path is: CGEventPost → tap callback (RunLoop thread) → calls eventHandler → which calls
`process()` → which calls `queue.sync` → which blocks on the serial queue. But the serial
queue is currently occupied by `_replayEvents`. This is a DEADLOCK.

**Resolution:** The replay must NOT use `queue.sync` for re-entry. Use a separate flag that
is checked WITHOUT entering the queue. The `isReplaying` check must happen BEFORE `queue.sync`:

```swift
func process(event: CGEvent, type: CGEventType) -> ChordResult {
    // Check re-entry flag WITHOUT acquiring queue — avoids deadlock during replay
    if _isReplaying { return .passThrough(event) }
    return queue.sync { _process(event: event, type: type) }
}
```

`_isReplaying` can be accessed outside the queue because it is only written inside the queue
during a synchronous `CGEventPost` call that blocks queue execution until all replayed events
have been processed. The write (`true`) and the re-entry reads are on different threads but
the timing is deterministic. Alternatively, make `_isReplaying` an `atomic` via
`OSAllocatedUnfairLock` or `os_unfair_lock` to be strictly safe. [ASSUMED — this threading
analysis is based on training knowledge of GCD + CGEventPost behavior; must validate with
integration testing.]

### Anti-Patterns to Avoid

- **Actor for ChordEngine:** Cannot call `await actor.method()` from a synchronous C callback.
  Use plain class + `DispatchQueue.sync`.
- **`queue.sync` around CGEventPost during replay:** Causes deadlock. See Pattern 5 resolution above.
- **Keycode-to-character via CGEvent.keyboardGetUnicodeString during collection:** This queries
  the IME layer and may return transformed characters (Thai, etc.). Use a static US QWERTY table.
- **Evaluating on keyDown (first key release):** Violates CHRD-04 and causes false positives when
  keys are held at different durations. Always wait for `heldKeys.isEmpty`.
- **Using `Set<Character>` instead of `Set<UInt16>`:** Character values ARE IME-dependent.
  Virtual keycodes are layout-stable at the CGEventTap HID level.
- **Forgetting to buffer keyUp events:** CHRD-05 replay must include both keyDown and keyUp so
  the target app sees proper press/release cycles (D-10).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Thread safety for mutable state | Custom lock/mutex | `DispatchQueue.sync` | GCD serial queue is the Apple-idiomatic pattern; already used in EventTapManager |
| Cancellable timers | Manual timer tracking | `DispatchWorkItem` + `.cancel()` | Built-in cancellation, runs on the same queue, no external state needed |
| Synthetic key event creation | Custom byte construction | `CGEvent(keyboardEventSource:virtualKey:keyDown:)` | The only public API for synthetic events at the HID level |
| Sorted character encoding | Custom sort | `sorted().map(String.init).joined()` | One-liner with standard library |

**Key insight:** The chord detection algorithm itself is genuinely custom code — there is no
library for this. But all the infrastructure (timing, threading, event posting) uses well-
established Apple APIs.

---

## Common Pitfalls

### Pitfall 1: Deadlock During Replay (CRITICAL)
**What goes wrong:** `process(event:type:)` holds the serial queue lock via `queue.sync`. Inside
the lock, `CGEventPost` is called to replay buffered events. CGEventPost is synchronous and
immediately invokes the CGEventTap callback on the RunLoop thread. That callback calls
`process()` which tries to acquire the same serial queue — deadlock.
**Why it happens:** GCD serial queues are non-reentrant. `queue.sync` called while the queue
is already executing blocks forever.
**How to avoid:** Check `_isReplaying` BEFORE calling `queue.sync`. Use `os_unfair_lock` or
`OSAllocatedUnfairLock` (Swift 5.9+) around the `_isReplaying` boolean if strict atomicity
is needed.
**Warning signs:** App freezes immediately on first chord mismatch replay.

### Pitfall 2: Keycode-to-Character Mapping Is Layout-Dependent
**What goes wrong:** Using `CGEvent.keyboardGetUnicodeString` to map keycodes to characters
returns IME-transformed output (e.g., Thai characters when Thai IME is active). Chord keys
defined in the dictionary as English letters won't match.
**Why it happens:** CGEventTap intercepts at HID level (raw keycodes), but Unicode string
lookup passes through the IME layer.
**How to avoid:** Use a static lookup table mapping the 26 letter virtual keycodes to their
US QWERTY lowercase characters. This is IME-independent.
**Warning signs:** Chord detection works with English IME but silently never matches with
Thai IME active.

### Pitfall 3: Window Timer Fires on Different Queue
**What goes wrong:** If `DispatchWorkItem` is scheduled without specifying the queue, it runs
on the global concurrent queue. This races with keyDown/keyUp events on the serial queue.
**Why it happens:** `DispatchQueue.asyncAfter(deadline:execute:)` called on `DispatchQueue.main`
or `.global()` by mistake.
**How to avoid:** Always schedule the work item on `self.queue` (the serial queue owned by
ChordEngine): `queue.asyncAfter(deadline: .now() + ..., execute: workItem)`.
**Warning signs:** Intermittent test failures, state corruption in timing edge cases.

### Pitfall 4: Forgetting to Cancel Window on State Transitions
**What goes wrong:** Window timer fires after a modifier abort or after a new chord cycle
starts, evaluating stale state.
**Why it happens:** `_cancelWindow()` not called in all transition paths.
**How to avoid:** Call `_cancelWindow()` in every transition that exits `.collecting`:
modifier abort, new chord start (D-02), and successful all-keys-released evaluation.
**Warning signs:** Spurious chord evaluations, chords evaluated twice.

### Pitfall 5: Missing keyUp in Buffered Events
**What goes wrong:** Replay only sends keyDown events. Target app's key state gets stuck
(key appears permanently held). Subsequent typing produces wrong characters.
**Why it happens:** Buffering only `keyDown` events is the natural first-pass implementation.
**How to avoid:** Buffer ALL events (`keyDown` and `keyUp`) in `_bufferedEvents` in received
order. Replay the full array.
**Warning signs:** After a chord mismatch, the next few characters typed produce wrong output.

### Pitfall 6: State Not Reset After Evaluation
**What goes wrong:** After processing a chord (match or mismatch), `heldKeys` and
`bufferedEvents` retain stale values. The next chord cycle inherits old state.
**Why it happens:** Reset logic omitted from `_evaluateAndReset()`.
**How to avoid:** Always clear `_heldKeys`, `_bufferedEvents`, `_windowWorkItem = nil`,
`_state = .idle` in `_reset()`. Call `_reset()` at the END of every evaluation path.
**Warning signs:** Second chord after a mismatch produces wrong result or double-evaluates.

---

## Code Examples

### ChordResult Enum (full)
```swift
// Source: CONTEXT.md D-13
enum ChordResult {
    case passThrough(CGEvent)
    case suppress
    case chord(key: String, buffered: [CGEvent])
}
```

### AppDelegate Integration (edit to AppDelegate.swift)
```swift
// Source: CONTEXT.md D-12 + existing AppDelegate.swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let eventTapManager = EventTapManager()
    let chordEngine = ChordEngine()  // add this

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire ChordEngine into EventTapManager (D-12)
        eventTapManager.eventHandler = { [weak self] event in
            guard let self else { return event }
            let result = self.chordEngine.process(
                event: event,
                type: event.type
            )
            switch result {
            case .passThrough(let e): return e
            case .suppress:           return nil
            case .chord(_, _):        return nil  // Phase 6 handles output
            }
        }
        // ... rest unchanged
    }
}
```

**Note on eventHandler signature:** `EventTapManager.eventHandler` currently has signature
`((CGEvent) -> CGEvent?)?` but does not pass `type`. The type must be derived from
`event.type` inside the closure. This works because `CGEvent.type` is always set on events
delivered to the tap. [VERIFIED: existing codebase — EventTapManager.swift line 26]

### Unit Test Pattern
```swift
// Source: EventTapManagerTests.swift pattern — adapted for ChordEngine
final class ChordEngineTests: XCTestCase {
    private var engine: ChordEngine!

    override func setUp() {
        super.setUp()
        engine = ChordEngine()
        // Inject hardcoded dictionary (D-14)
        engine.chordLookup = { key in
            ["eht": "the", "adn": "and"][key]
        }
    }

    func testChordEngine_threeKeysReleased_producesChordKey() {
        // Simulate T+H+E down then up
        let t = makeKeyEvent(keycode: 17, down: true)
        let h = makeKeyEvent(keycode: 4,  down: true)
        let e = makeKeyEvent(keycode: 14, down: true)
        let tUp = makeKeyEvent(keycode: 17, down: false)
        let hUp = makeKeyEvent(keycode: 4,  down: false)
        let eUp = makeKeyEvent(keycode: 14, down: false)

        _ = engine.process(event: t, type: .keyDown)
        _ = engine.process(event: h, type: .keyDown)
        _ = engine.process(event: e, type: .keyDown)
        _ = engine.process(event: tUp, type: .keyUp)
        _ = engine.process(event: hUp, type: .keyUp)
        let result = engine.process(event: eUp, type: .keyUp)

        if case .chord(let key, _) = result {
            XCTAssertEqual(key, "eht")
        } else {
            XCTFail("Expected .chord, got \(result)")
        }
    }

    private func makeKeyEvent(keycode: UInt16, down: Bool) -> CGEvent {
        CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: down)!
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `OSSpinLock` for thread safety | `DispatchQueue.sync` / `os_unfair_lock` | macOS 10.12 | OSSpinLock deprecated; GCD serial queues are the canonical pattern |
| `DispatchQueue.after` with `Int` delay | `DispatchWorkItem` + `cancel()` | macOS 10.10 | Cancellable work items avoid spurious evaluations |
| Carbon event hooks | CGEventTap | macOS 12 (Carbon deprecated) | CGEventTap is the only supported API for HID-level interception |
| Actor for event processing | Plain class + queue.sync | Swift 6 | Actors require async/await; CGEventTap callbacks are synchronous C |

**Deprecated/outdated:**
- `OSSpinLock`: deprecated macOS 10.12 — use `os_unfair_lock` or GCD instead
- Carbon `RegisterEventHotKey`: deprecated macOS 12 — do not use
- `@unchecked Sendable` with no justification: CLAUDE.md requires explicit comment explaining manual thread safety

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Virtual keycode-to-letter mapping table (a=0, b=11, c=8, ...) is correct for US QWERTY | Code Examples §Sorted-Alpha Encoding | Chord detection silently misses all chords — sort keys don't match dictionary keys |
| A2 | `_isReplaying` flag read outside `queue.sync` is safe given the deterministic CGEventPost+tap synchronous delivery order | Architecture Patterns §Re-entry Guard | Data race; undefined behavior — use `OSAllocatedUnfairLock` if in doubt |
| A3 | `eventHandler` closure is called with event.type already set correctly before ChordEngine.process receives it | Code Examples §AppDelegate Integration | `process()` needs explicit type parameter or event type derivation |

---

## Open Questions

1. **Virtual keycode table correctness**
   - What we know: US QWERTY virtual keycodes are documented in IOKit `IOHIDUsageTables.h`
   - What's unclear: Whether the values in A1 above are exactly right for all 26 letters
   - Recommendation: Add a test that exercises each letter keycode and verifies the sorted-alpha output; fix table in Wave 0 if test fails. The keycodes are well-known constants; a one-time verification test is sufficient.

2. **`isReplaying` threading safety**
   - What we know: `_isReplaying` needs to be readable outside `queue.sync` to avoid deadlock
   - What's unclear: Whether direct bool access without lock is safe given Swift 6 strict concurrency
   - Recommendation: Use `OSAllocatedUnfairLock<Bool>` (Swift 5.9+ / macOS 13+) for `_isReplaying`; this matches the deployment target and eliminates the race without async overhead.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| xcodebuild | `make test` | ✓ | Xcode 16.4 | — |
| xcodegen | `make generate` | ✓ | 2.45.4 | — |
| CGEvent API | Keystroke simulation in tests | ✓ | macOS 13+ | — |
| XCTest | Unit tests | ✓ | bundled with Xcode 16.4 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 16.4) |
| Config file | project.yml (ChordTyperTests target) |
| Quick run command | `make test` |
| Full suite command | `make test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHRD-01 | Keys within 50ms window collected into one chord | unit | `make test` | ❌ Wave 0 |
| CHRD-01 | Keys after window expiry start new chord cycle | unit | `make test` | ❌ Wave 0 |
| CHRD-02 | Only 2 keys pressed — no chord evaluation | unit | `make test` | ❌ Wave 0 |
| CHRD-02 | 3+ keys pressed — chord evaluation triggered | unit | `make test` | ❌ Wave 0 |
| CHRD-03 | T+H+E and H+E+T produce same chord key "eht" | unit | `make test` | ❌ Wave 0 |
| CHRD-04 | Chord not evaluated on keyDown — only after all keyUp | unit | `make test` | ❌ Wave 0 |
| CHRD-05 | Unmatched chord replays all original events in order | unit | `make test` | ❌ Wave 0 |
| CHRD-05 | Replay includes both keyDown and keyUp events | unit | `make test` | ❌ Wave 0 |
| Integration | Modifier key aborts chord and flushes buffer | unit | `make test` | ❌ Wave 0 |
| Integration | isReplaying guard prevents re-entry during replay | unit | `make test` | ❌ Wave 0 |

**Test file naming:** `Tests/ChordTyperTests/ChordEngineTests.swift`
**Test naming pattern:** `testChordEngine_[scenario]_[expectedBehavior]` (per CLAUDE.md)

### Sampling Rate
- **Per task commit:** `make test`
- **Per wave merge:** `make test && make build`
- **Phase gate:** `make build && make test` both green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Tests/ChordTyperTests/ChordEngineTests.swift` — covers all CHRD-01 through CHRD-05 + integration paths
- [ ] `Sources/ChordTyper/ChordDetector.swift` — the implementation file itself

*(No new test infrastructure needed — XCTest and project target already configured.)*

---

## Security Domain

This phase adds no authentication, session management, or user data persistence. The only
security-relevant consideration is key suppression and replay — addressed by CHRD-05 and the
`isReplaying` guard. No ASVS categories apply to a local keystroke state machine.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase `Sources/ChordTyper/EventTapManager.swift` — thread safety pattern, injectable closures, logging conventions [VERIFIED: existing codebase]
- Existing codebase `Tests/ChordTyperTests/EventTapManagerTests.swift` — test structure and injection pattern [VERIFIED: existing codebase]
- `CLAUDE.md` — coding conventions, file responsibilities, testing conventions [VERIFIED: existing codebase]
- `spec.md` — chord behavior specification, encoding format, 50ms default [VERIFIED: existing codebase]
- `.planning/phases/04-chord-detection/04-CONTEXT.md` — all locked decisions D-01 through D-14 [VERIFIED: existing planning artifact]
- Apple Developer Documentation: `DispatchWorkItem` — [CITED: developer.apple.com/documentation/dispatch/dispatchworkitem]
- Apple Developer Documentation: `CGEventPost` — [CITED: developer.apple.com/documentation/coregraphics/1456527-cgeventpost]

### Secondary (MEDIUM confidence)
- Apple Developer Documentation: `OSAllocatedUnfairLock` — Swift 5.9+ atomic lock primitive [CITED: developer.apple.com/documentation/os/osallocatedunfairlock]

### Tertiary (LOW confidence)
- Virtual keycode table (A1) — training knowledge of IOKit HID usage constants; must verify in Wave 0 test [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks are Apple-native, already in project
- Architecture: HIGH — fully locked by CONTEXT.md decisions; implementation path is unambiguous
- Pitfall 1 (deadlock): HIGH — GCD non-reentrancy is documented; the fix is clear
- Pitfall 2 (keycode mapping): MEDIUM — keycode table needs Wave 0 verification test
- Threading analysis for isReplaying: LOW — recommend OSAllocatedUnfairLock to avoid uncertainty

**Research date:** 2026-05-22
**Valid until:** 2026-06-22 (stable APIs; no expiry risk)
