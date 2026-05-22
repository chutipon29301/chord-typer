# Phase 4: Chord Detection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 4-Chord Detection
**Areas discussed:** Timing window behavior, State machine design, Key replay on mismatch, Integration boundary

---

## Timing Window Behavior

### When does the timing window start?

| Option | Description | Selected |
|--------|-------------|----------|
| First keydown starts window | Window opens on first keydown event. Keys within 50ms of first key are part of chord. Matches ZipChord. | ✓ |
| Each new key resets window | Window resets/extends on each new key press. More forgiving but risks false positives. | |
| Rolling window from last key | Window measured backwards from most recent keydown. | |

**User's choice:** First keydown starts window

### Late key behavior (after window closes)

| Option | Description | Selected |
|--------|-------------|----------|
| Starts a new chord | Late key treated as first keydown of fresh chord. Previous chord evaluates on its own keys. | ✓ |
| Passed through as normal | Late key goes straight to app, not collected. | |
| Extends the window once | Grace period extension if 2 keys already collected. | |

**User's choice:** Starts a new chord

### Modifier key handling

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore modifiers entirely | Modifiers don't count toward chords and don't interfere. | |
| Cancel chord if modifier held | Any modifier held during collection aborts chord, passes everything through. | ✓ |
| Strip modifier flags from keys | Collect base keycode ignoring modifier state. | |

**User's choice:** Cancel chord if modifier held

### Modifier detection mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Check CGEvent flags on keyDown | Inspect event.flags on each keyDown. No changes to event mask. | ✓ |
| Add .flagsChanged to event mask | Expand EventTapManager's mask. More precise but changes Phase 3 setup. | |

**User's choice:** Check CGEvent flags on keyDown

---

## State Machine Design

### Concurrency model

| Option | Description | Selected |
|--------|-------------|----------|
| Plain class + serial queue | Matches EventTapManager pattern. No async bridging in hot path. | ✓ |
| Swift actor | Cleaner concurrency but requires Task { await } from C callback. | |

**User's choice:** Plain class + serial queue

### State machine states

| Option | Description | Selected |
|--------|-------------|----------|
| 3 states: idle/collecting/evaluating | Minimal. idle→collecting on keyDown, collecting→evaluating on all-released or window expiry, evaluating→idle after match or replay. | ✓ |
| 4 states: idle/collecting/evaluating/replaying | Adds explicit replaying state for re-entry prevention. | |

**User's choice:** 3 states

### Key tracking data structure

| Option | Description | Selected |
|--------|-------------|----------|
| Set<UInt16> of virtual keycodes | IME-independent raw keycodes. Convert to characters at lookup time. | ✓ |
| Set<Character> of typed characters | Immediate character conversion. Layout-dependent. | |
| Array<(keycode, timestamp)> ordered | Tracks both keycode and timing. | |

**User's choice:** Set<UInt16> of virtual keycodes

### Timer implementation

| Option | Description | Selected |
|--------|-------------|----------|
| DispatchQueue.asyncAfter | Cancellable DispatchWorkItem on serial queue. Simple, no timer objects. | ✓ |
| DispatchSourceTimer | More infrastructure, consistent with EventTapManager's pattern. | |
| Timestamp comparison on each event | Purely event-driven, no timer. Can't force-evaluate if no events arrive. | |

**User's choice:** DispatchQueue.asyncAfter

---

## Key Replay on Mismatch

### Replay mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Replay original CGEvent objects | Buffer originals during collection. Post via CGEventPost. Preserves exact metadata. | ✓ |
| Create synthetic CGEvents | Store keycodes only, create fresh events. Loses original metadata. | |
| NSEvent injection | Higher-level API, adds AppKit dependency. | |

**User's choice:** Replay original CGEvent objects

### Re-entry prevention

| Option | Description | Selected |
|--------|-------------|----------|
| Boolean flag on ChordEngine | isReplaying flag, pass through immediately when set. Synchronous on same thread. | ✓ |
| Mark events with userData field | Sentinel value via setIntegerValueField. Survives across threads. | |
| Temporarily detach event handler | Set handler to nil during replay. Creates bypass window. | |

**User's choice:** Boolean flag

### Replay scope

| Option | Description | Selected |
|--------|-------------|----------|
| Both keyDown and keyUp | Complete press/release cycles. Apps see proper key state. | ✓ |
| KeyDown only | Physical keyUps arrive naturally. Fewer synthetic events. | |

**User's choice:** Both keyDown and keyUp

---

## Integration Boundary

### ChordEngine ownership

| Option | Description | Selected |
|--------|-------------|----------|
| AppDelegate owns ChordEngine | Creates it, wires to EventTapManager. Peer of EventTapManager. | ✓ |
| EventTapManager owns ChordEngine | Encapsulated but overloads EventTapManager responsibility. | |
| ChordTyperApp (SwiftUI) owns it | Enables SwiftUI observation but mixes UI with event processing. | |

**User's choice:** AppDelegate owns ChordEngine

### Match result communication

| Option | Description | Selected |
|--------|-------------|----------|
| Return enum from process() | ChordResult enum: .passThrough, .suppress, .chord(key, buffered). Typed, synchronous. | ✓ |
| Callback closure for matches | onChordDetected closure. Separates detection from output. | |

**User's choice:** Return enum from process()

### Test strategy for matches

| Option | Description | Selected |
|--------|-------------|----------|
| Injectable lookup closure | chordLookup: (String) -> String? with stub dictionary in tests. Full path coverage. | ✓ |
| Detection only, no lookup | Only test chord key formation and state machine. No match testing until Phase 5. | |

**User's choice:** Injectable lookup closure

---

## Claude's Discretion

None — user made explicit choices for all areas.

## Deferred Ideas

None — discussion stayed within phase scope.
