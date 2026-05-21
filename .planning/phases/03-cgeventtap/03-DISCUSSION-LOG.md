# Phase 3: CGEventTap - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-21
**Phase:** 03-CGEventTap
**Areas discussed:** EventTap lifecycle, Permission UX, Resilience strategy, Event pass-through design

---

## EventTap Lifecycle

### How should CGEventTap be managed?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated EventTapManager | Standalone class owns tap lifecycle. AppDelegate creates on launch, tears down on quit. Clean separation. | ✓ |
| AppDelegate owns tap directly | AppDelegate creates and manages CGEventTap inline. Simpler but mixes concerns. | |
| Global singleton | Shared EventTapManager accessible anywhere. Easy access but harder to test. | |

**User's choice:** Dedicated EventTapManager
**Notes:** None

### Actor vs plain class?

| Option | Description | Selected |
|--------|-------------|----------|
| Plain class + DispatchQueue | C callback can't be async. Serial DispatchQueue for state mutations. Natural fit. | ✓ |
| Actor with synchronous callback bridge | Actor isolates state but requires Task { await ... } bridging — adds latency. | |

**User's choice:** Plain class + DispatchQueue
**Notes:** None

### When to create tap?

| Option | Description | Selected |
|--------|-------------|----------|
| On app launch | Create in applicationDidFinishLaunching. Immediate permission feedback. | ✓ |
| Lazily on first enable | Only create when user enables. Delays permission prompt. | |

**User's choice:** On app launch
**Notes:** None

### How to introduce AppDelegate?

| Option | Description | Selected |
|--------|-------------|----------|
| @NSApplicationDelegateAdaptor | Add adaptor to ChordTyperApp. SwiftUI stays entry point. | ✓ |
| Replace @main with AppDelegate-based entry | Traditional NSApplicationMain. More control but loses SwiftUI scene lifecycle. | |

**User's choice:** @NSApplicationDelegateAdaptor
**Notes:** None

---

## Permission UX

### How to handle missing permission?

| Option | Description | Selected |
|--------|-------------|----------|
| NSAlert with Open Settings button | Modal alert explaining why permission is needed, deep-links to System Settings. | ✓ |
| Inline menubar message only | Change menubar dropdown to show permission required. Less intrusive but easy to miss. | |
| Dedicated onboarding window | Small SwiftUI window with step-by-step instructions. Most helpful but more work. | |

**User's choice:** NSAlert with Open Settings button
**Notes:** None

### Poll or require restart?

| Option | Description | Selected |
|--------|-------------|----------|
| Poll with timer | Poll CGPreflightListenEventAccess() every 2s. Auto-create tap when granted. Stop after ~60s. | ✓ |
| Require app restart | Show alert, user grants, then must relaunch. Simpler but worse UX. | |
| DistributedNotificationCenter | Listen for TCC changes. Unreliable on recent macOS. | |

**User's choice:** Poll with timer
**Notes:** None

### AXIsProcessTrusted vs CGPreflightListenEventAccess?

| Option | Description | Selected |
|--------|-------------|----------|
| AXIsProcessTrusted() | Standard Accessibility check. Works on macOS 10.9+. | |
| CGPreflightListenEventAccess() | Newer CoreGraphics-specific check (macOS 10.15+). More precise for event tap permission. | ✓ |

**User's choice:** CGPreflightListenEventAccess()
**Notes:** More precise for event tap use case. Pair with CGRequestListenEventAccess() to trigger system prompt.

### Behavior without permission?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep running, paused | App stays in menubar with paused icon. Menu shows grant permission item. | ✓ |
| Quit with explanation | Final alert then terminate. Forces restart after granting. | |

**User's choice:** Keep running, paused
**Notes:** None

---

## Resilience Strategy

### Handle kCGEventTapDisabledByTimeout?

| Option | Description | Selected |
|--------|-------------|----------|
| Immediate re-enable in callback | Call CGEvent.tapEnable immediately. Standard pattern (Ghostty, Hammerspoon). | ✓ |
| Re-enable with backoff delay | Wait 100ms before re-enabling. More cautious. | |
| Notify user and require manual re-enable | Show notification, user clicks to re-enable. Safest but worst UX. | |

**User's choice:** Immediate re-enable in callback
**Notes:** None

### Sleep/wake recovery?

| Option | Description | Selected |
|--------|-------------|----------|
| NSWorkspace wake notification + verify tap | Subscribe to didWakeNotification. Check tap validity, recreate if needed. | ✓ |
| Periodic health check timer | Background timer every 30s checks tap health. Catches more but wastes cycles. | |

**User's choice:** NSWorkspace wake notification + verify tap
**Notes:** None

### TCC reset in Makefile?

| Option | Description | Selected |
|--------|-------------|----------|
| Add to Makefile run target | tccutil reset before launching in make run. Prevents silent-disable during dev. | ✓ |
| Document only | Note workaround in README. Developer runs manually. | |
| Separate make target | make reset-tcc as standalone. Doesn't pollute normal run flow. | |

**User's choice:** Add to Makefile run target
**Notes:** Addresses STATE.md blocker about TCC silent-disable after rebuild

### Detect permission revocation?

| Option | Description | Selected |
|--------|-------------|----------|
| Detect via tap failure | If CGEventTapCreate returns nil or events stop, treat as revocation. No extra polling. | ✓ |
| Active polling | Periodically check CGPreflightListenEventAccess(). Proactive but adds overhead. | |

**User's choice:** Detect via tap failure
**Notes:** None

---

## Event Pass-Through Design

### Callback structure for Phase 4 integration?

| Option | Description | Selected |
|--------|-------------|----------|
| Closure-based handler property | eventHandler: ((CGEvent) -> CGEvent?) property. Phase 3 pass-through, Phase 4 replaces. | ✓ |
| Delegate protocol | EventTapDelegate protocol. More structured but more boilerplate. | |
| Direct integration placeholder | Modify callback body in Phase 4. Simplest now, requires internal edits later. | |

**User's choice:** Closure-based handler property
**Notes:** None

### Event types to intercept?

| Option | Description | Selected |
|--------|-------------|----------|
| keyDown + keyUp only | Sufficient for chord detection. Skip flagsChanged. | ✓ |
| keyDown + keyUp + flagsChanged | Also intercept modifier keys. Future-proofs for modifier-based chords. | |
| All keyboard events | Maximum flexibility but unnecessary events. | |

**User's choice:** keyDown + keyUp only
**Notes:** None

### Tap level?

| Option | Description | Selected |
|--------|-------------|----------|
| Session level — kCGSessionEventTap | Sufficient for chord detection. Matches EVNT-01. Less privileged. | ✓ |
| HID level — kCGHIDEventTap | Hardware level. CLAUDE.md mentions for Thai IME. May need more entitlements. | |

**User's choice:** Session level — kCGSessionEventTap
**Notes:** CLAUDE.md recommends HID for Thai IME but session is sufficient as starting point. Revisit in Phase 6 if Thai output issues arise.

### Expose tap state to UI?

| Option | Description | Selected |
|--------|-------------|----------|
| Published property via Combine/observation | Publish state enum (.running, .stopped, .noPermission). Menubar reflects actual tap state. | ✓ |
| Delegate callback to AppDelegate | Manual wiring, no Combine. | |
| No exposure in Phase 3 | Keep internal. Add observability later if needed. | |

**User's choice:** Published property via Combine/observation
**Notes:** None

---

## Claude's Discretion

None — user made all decisions explicitly.

## Deferred Ideas

None — discussion stayed within phase scope.
