# Phase 3: CGEventTap - Research

**Researched:** 2026-05-21
**Domain:** CoreGraphics Quartz Event Services — CGEventTap lifecycle, permission UX, resilience
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**EventTap Lifecycle**
- D-01: Dedicated `EventTapManager` class owns tap lifecycle (create, enable, disable, destroy) — separate from AppDelegate
- D-02: Plain class with serial `DispatchQueue` for state mutations, not an actor — CGEventTap callback is a C function pointer that can't be async
- D-03: Create tap on app launch (`applicationDidFinishLaunching`) — immediate permission feedback
- D-04: Introduce AppDelegate via `@NSApplicationDelegateAdaptor(AppDelegate.self)` in `ChordTyperApp`

**Permission UX**
- D-05: Show `NSAlert` with "Open Settings" button on launch when Accessibility permission is missing
- D-06: After alert dismissal, poll `CGPreflightListenEventAccess()` every 2 seconds; auto-create tap when granted; stop after ~60s
- D-07: Use `CGPreflightListenEventAccess()` for permission check (not `AXIsProcessTrusted()`)
- D-08: App keeps running in paused state if permission not granted — menubar shows "Grant Accessibility Permission" item

**Resilience Strategy**
- D-09: On `kCGEventTapDisabledByTimeout`, immediately re-enable via `CGEvent.tapEnable(tap:enable:)` inside callback
- D-10: Subscribe to `NSWorkspace.didWakeNotification` — verify RunLoopSource validity on wake, destroy/recreate if needed
- D-11: Add `tccutil reset Accessibility dev.chutipon.chordtyper` to Makefile `run` target
- D-12: Detect permission revocation via tap failure (nil from `CGEventTapCreate` or events stop arriving)

**Event Pass-Through Design**
- D-13: Closure-based handler property: `eventHandler: ((CGEvent) -> CGEvent?)` — Phase 3 sets pass-through; Phase 4 replaces
- D-14: Intercept `.keyDown` and `.keyUp` events only — modifier keys (`.flagsChanged`) skipped
- D-15: Install tap at session level (`kCGSessionEventTap`) — sufficient for Phase 3; HID level revisited in Phase 6 if Thai issues surface
- D-16: EventTapManager publishes tap state enum (`.running`, `.stopped`, `.noPermission`) via observable property

### Claude's Discretion

None specified.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EVNT-01 | CGEventTap created at session level (`kCGSessionEventTap` + `kCGHeadInsertEventTap`) | D-15; `CGEvent.tapCreate` API signature verified; `.defaultTap` options required for event suppression in future phases |
| EVNT-02 | Tap intercepts keyDown and keyUp events | D-14; `CGEventMask` bit composition: `(1 << CGEventType.keyDown.rawValue) \| (1 << CGEventType.keyUp.rawValue)` |
| EVNT-03 | App checks `AXIsProcessTrusted()` and guides user to System Settings if permission missing | REQUIREMENTS.md says `AXIsProcessTrusted()`; D-07 says `CGPreflightListenEventAccess()` — see Pitfall 1 for resolution |
| EVNT-04 | Tap handles `kCGEventTapDisabledByTimeout` by re-enabling | D-09; standard pattern: check `type == .tapDisabledByTimeout` in callback, call `CGEvent.tapEnable(tap:enable:)` |
| EVNT-05 | Tap recovers after sleep/wake via NSWorkspace notification | D-10; `NSWorkspace.shared.notificationCenter` observer for `.didWakeNotification` |
</phase_requirements>

---

## Summary

Phase 3 establishes the low-level event interception pipeline for ChordTyper. The core artifact is `EventTapManager` — a plain class backed by a serial `DispatchQueue` that creates, manages, and recovers a `CGEventTap` at `kCGSessionEventTap` location. This phase implements a completely transparent tap (pass-through only), exposes a closure hook for Phase 4 chord detection, and publishes tap state for the menubar UI.

The main technical challenges are: (1) safely bridging a C callback to a Swift class instance using the `Unmanaged` pointer pattern while satisfying `SWIFT_STRICT_CONCURRENCY=complete`, (2) integrating `@NSApplicationDelegateAdaptor` into the existing SwiftUI `@main` App struct without disrupting Phase 2 menubar wiring, and (3) handling the TCC silent-disable race that occurs when the app binary is re-signed during development (the `tccutil reset` Makefile fix is the practical mitigation).

Permission handling uses `CGPreflightListenEventAccess()` (Input Monitoring privilege, not the broader Accessibility privilege checked by `AXIsProcessTrusted()`). For tap options, `.defaultTap` (not `.listenOnly`) is required — even in this pass-through phase — because Phase 6 will return `nil` from the callback to suppress keystrokes. A `listenOnly` tap cannot suppress events and cannot be promoted in-place.

**Primary recommendation:** Build `EventTapManager` as a `final class` with `nonisolated(unsafe)` or `@unchecked Sendable` annotation guarded by an internal serial queue. Use `Unmanaged.passRetained(self).toOpaque()` for the callback userInfo, and `Unmanaged<EventTapManager>.fromOpaque(refcon!).takeUnretainedValue()` to recover `self` inside the C callback.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CGEventTap lifecycle (create/enable/disable/destroy) | EventTapManager (background) | AppDelegate (launches on main thread) | Tap operations are thread-safe C calls; RunLoopSource added to current RunLoop on background thread or main RunLoop |
| Accessibility permission check | EventTapManager | AppDelegate (UI presentation) | CGPreflightListenEventAccess is a C API callable from any thread; alert presentation must happen on main thread |
| Permission polling | EventTapManager (DispatchQueue timer) | — | Keeps permission-checking logic co-located with tap creation logic |
| Sleep/wake recovery | AppDelegate (NSWorkspace observer) | EventTapManager (recreate tap) | didWakeNotification delivered on main thread; AppDelegate delegates recreation to EventTapManager |
| Tap state publishing | EventTapManager (source of truth) | AppDelegate bridges to SwiftUI | EventTapManager owns the enum; AppDelegate / SwiftUI observe via @Published or callback |
| Event handler hook | EventTapManager (closure property) | Phase 4 injects chord detector | Clean seam; Phase 3 sets identity closure; Phase 4 replaces without changing EventTapManager |
| Pass-through transparency | CGEventTap callback | — | Return `Unmanaged.passUnretained(event)` for all non-special event types |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CoreGraphics (Quartz Event Services) | macOS 13+ (API stable since 10.4) | `CGEventTapCreate`, `CGEvent.tapEnable`, `CGEventPost` | Only public API for HID/session-level keystroke interception; no alternative [CITED: developer.apple.com/documentation/coregraphics] |
| AppKit | macOS 13+ | `NSAlert`, `NSWorkspace`, `NSApplication` | Required for permission UX (NSAlert) and sleep/wake notifications (NSWorkspace) [CITED: developer.apple.com/documentation/appkit] |
| Foundation | macOS 13+ | `DispatchQueue`, `CFRunLoop`, `CFMachPort` | Tap RunLoopSource management; serial queue for EventTapManager state [CITED: developer.apple.com/documentation/foundation] |
| SwiftUI | 5 (macOS 13+) | `@NSApplicationDelegateAdaptor`, `MenuBarExtra` | Bridges AppDelegate into the existing SwiftUI App struct [CITED: developer.apple.com/documentation/swiftui] |

### No Supporting Libraries

This phase has no external dependencies. All capabilities are provided by Apple system frameworks. [CITED: CLAUDE.md — "Zero third-party dependencies"]

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `kCGSessionEventTap` | `kCGHIDEventTap` | HID level intercepts before IME (needed for Phase 6 Thai); session level sufficient for Phase 3 pass-through. CLAUDE.md specifies HID; D-15 defers escalation to Phase 6 when Thai issues actually surface. |
| `.defaultTap` options | `.listenOnly` | listenOnly cannot suppress events; unusable for Phase 6. Use `.defaultTap` from Phase 3 to avoid a tap recreation |
| `CGPreflightListenEventAccess()` | `AXIsProcessTrusted()` | See Pitfall 1 — these check different TCC privileges. D-07 locks `CGPreflightListenEventAccess()`. |
| Plain class + DispatchQueue | Swift actor | Actor can't be used directly in a C callback (no `async` in C function pointer); D-02 locks the plain class pattern |

**Installation:** No packages to install — Apple frameworks only.

---

## Package Legitimacy Audit

> Not applicable. This phase installs zero external packages. All dependencies are Apple system frameworks included with macOS and Xcode.

---

## Architecture Patterns

### System Architecture Diagram

```
applicationDidFinishLaunching
        │
        ▼
  EventTapManager.start()
        │
        ├──► CGPreflightListenEventAccess()
        │         │
        │    false ▼                true ▼
        │    NSAlert ("Open Settings")   CGEvent.tapCreate(
        │         │                        tap: .cgSessionEventTap,
        │    pollTimer (2s)               place: .headInsertEventTap,
        │         │                        options: .defaultTap,
        │         └──► (on grant) ───────► eventsOfInterest: keyDown|keyUp,
        │                                  callback: eventTapCallback,
        │                                  userInfo: Unmanaged.passRetained(self).toOpaque()
        │                                )
        │                                  │
        │                         CFMachPortCreateRunLoopSource
        │                         CFRunLoopAddSource(.commonModes)
        │                         CGEvent.tapEnable(tap:enable:true)
        │                                  │
        │                    tapState = .running (published)
        │
        ▼
  NSWorkspace.didWakeNotification ──► verifyTap()
                                           │
                                    tapIsEnabled?
                                    No ──► destroyTap() ──► start()

  CGEventTap Callback (C function, background thread):
        │
        ├── type == .tapDisabledByTimeout
        │       └──► CGEvent.tapEnable(tap:enable:true)  [immediate re-enable]
        │            log("tap re-enabled after timeout")
        │            return nil
        │
        ├── type == .keyDown or .keyUp
        │       └──► eventHandler?(event) ?? event  [closure hook for Phase 4]
        │            return Unmanaged.passUnretained(result)
        │
        └── all other types
                └──► return Unmanaged.passUnretained(event)  [transparent pass-through]
```

### Recommended Project Structure

```
Sources/ChordTyper/
├── ChordTyperApp.swift          # existing — add @NSApplicationDelegateAdaptor
├── AppDelegate.swift            # NEW — owns EventTapManager, bridges to SwiftUI
├── EventTapManager.swift        # NEW — tap lifecycle, permission, resilience
Tests/ChordTyperTests/
├── EventTapManagerTests.swift   # NEW — unit tests for re-enable, state machine
├── ChordTyperSmokeTests.swift   # existing
├── DictionaryBundleTests.swift  # existing
└── MenuStateTests.swift         # existing
Makefile                         # MODIFY — add tccutil reset to run target
```

### Pattern 1: CGEventTap C Callback to Swift Class (Unmanaged Bridge)

**What:** Pass `self` through the C `userInfo` void pointer using `Unmanaged`, recover it safely inside the C callback function.

**When to use:** Every time a C API takes a `void *userInfo` / `refcon` that is delivered to a callback — required for CGEventTap.

```swift
// Source: Quartz Event Services documentation + Unmanaged Swift stdlib
// https://developer.apple.com/documentation/coregraphics/cgeventtapcallback

final class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let queue = DispatchQueue(label: "dev.chutipon.chordtyper.eventtap",
                                      qos: .userInteractive)

    // IMPORTANT: must hold a strong reference; passRetained increments retain count
    private var selfRetained: Unmanaged<EventTapManager>?

    func createTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        // Store retained pointer — must outlive the tap
        selfRetained = Unmanaged.passRetained(self)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: eventTapCallback,
            userInfo: selfRetained!.toOpaque()
        )

        guard let tap = eventTap else {
            selfRetained?.release()
            selfRetained = nil
            // tap creation failed — permission revoked or system error
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func destroyTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        // Release the passRetained reference — tap is gone, callback will never fire again
        selfRetained?.release()
        selfRetained = nil
    }
}

// C-compatible callback — must be a free function or static method, not a closure
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(proxy: proxy, type: type, event: event)
}
```

**Critical detail:** The callback must be a `private func` at file scope (or a `static func`), not a closure or instance method. Swift's C function pointer bridging requires `@convention(c)` which cannot capture context. [CITED: developer.apple.com/documentation/coregraphics/cgeventtapcallback]

### Pattern 2: Timeout Re-Enable Inside Callback

**What:** When macOS disables the tap for taking too long, immediately re-enable inside the same callback invocation.

```swift
// Source: Ghostty issue #11883, Apple Quartz Event Services documentation
func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout:
        // Re-enable immediately — this is the documented pattern
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.warning("CGEventTap re-enabled after kCGEventTapDisabledByTimeout")
        }
        return nil  // no event to pass through for this pseudo-event

    case .tapDisabledByUserInput:
        // Less common; same recovery
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return nil

    case .keyDown, .keyUp:
        let result = eventHandler?(event) ?? event
        return Unmanaged.passUnretained(result)

    default:
        return Unmanaged.passUnretained(event)
    }
}
```

**Warning:** `tapDisabledByTimeout` is a pseudo-event type — the `event` parameter may be invalid. Never pass it through; return `nil`. [CITED: developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout]

### Pattern 3: Sleep/Wake Recovery

**What:** After system wake, the tap RunLoopSource may be invalid. Destroy and recreate.

```swift
// Source: Apple NSWorkspace.didWakeNotification documentation
// Register in AppDelegate.applicationDidFinishLaunching:
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.eventTapManager.recoverFromWake()
}

// In EventTapManager:
func recoverFromWake() {
    guard let tap = eventTap else {
        // Was never created (permission not granted) — re-check permission
        start()
        return
    }
    if !CGEvent.tapIsEnabled(tap: tap) {
        logger.info("Tap disabled after wake — recreating")
        destroyTap()
        createTap()
    }
}
```

### Pattern 4: Permission Check and Polling

**What:** `CGPreflightListenEventAccess()` checks Input Monitoring privilege (the correct check for `.defaultTap`). Pair with `CGRequestListenEventAccess()` to show the system prompt.

```swift
// Source: developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess
func start() {
    if CGPreflightListenEventAccess() {
        createTap()
    } else {
        showPermissionAlert()
        startPermissionPolling()
    }
}

private func showPermissionAlert() {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "ChordTyper needs Accessibility access to intercept keystrokes. Please grant permission in System Settings."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}

private var pollTimer: DispatchSourceTimer?
private var pollCount = 0

private func startPermissionPolling() {
    pollTimer = DispatchSource.makeTimerSource(queue: queue)
    pollTimer?.schedule(deadline: .now() + 2, repeating: 2)
    pollTimer?.setEventHandler { [weak self] in
        guard let self else { return }
        self.pollCount += 1
        if CGPreflightListenEventAccess() {
            self.pollTimer?.cancel()
            self.pollTimer = nil
            self.createTap()
        } else if self.pollCount >= 30 {  // ~60 seconds
            self.pollTimer?.cancel()
            self.pollTimer = nil
        }
    }
    pollTimer?.resume()
}
```

### Pattern 5: Swift 6 Strict Concurrency Compliance

**What:** `SWIFT_STRICT_CONCURRENCY=complete` means the compiler checks all Sendable crossings. The CGEventTap C callback runs on whatever thread the RunLoop is on — this is not under Swift's actor system.

**Approach for D-02 (plain class with DispatchQueue):**

```swift
// The class is NOT an actor. Annotate as @unchecked Sendable because we
// manually enforce thread safety via `queue.sync` / `queue.async`.
// This is the correct pattern when a C callback makes actor isolation impossible.
final class EventTapManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.chutipon.chordtyper.eventtap",
                                      qos: .userInteractive)
    // All mutable state accessed only via queue.sync { } or queue.async { }
    private var _tapState: TapState = .stopped
    var tapState: TapState {
        queue.sync { _tapState }
    }
}
```

**Why not `nonisolated(unsafe)`:** `nonisolated(unsafe)` suppresses warnings on individual stored properties; `@unchecked Sendable` on the whole class is the documented Swift 6 pattern for lock-guarded types. [ASSUMED — Swift 6 migration guide pattern; training knowledge, not verified via Context7 this session]

### Anti-Patterns to Avoid

- **Never use a Swift closure as the CGEventTapCallback:** Closures can capture context but cannot be passed as `@convention(c)` function pointers. Use a file-scope `private func` or `static func`.
- **Never access `self` properties directly inside the C callback:** The callback runs on an unspecified thread. All access must go through the serial queue or be read-only immutable state.
- **Never return the timeout pseudo-event:** `tapDisabledByTimeout` and `tapDisabledByUserInput` types deliver a `nil`-or-invalid event; passing it through crashes or produces undefined behavior.
- **Never skip `passRetained` bookkeeping:** If `selfRetained` is released while the tap is still installed, the callback will hold a dangling pointer. Always pair `passRetained` with `release` in `destroyTap()`.
- **Never assume `tapCreate` succeeds after permission is granted:** On Xcode rebuilds, TCC may silently invalidate prior grants. Always nil-check the return value.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Event interception below IME | Custom kernel extension / NSEvent monitor | `CGEventTap` at `.cgSessionEventTap` | NSEvent is post-IME; kernel extensions are unsupported in modern macOS |
| Timeout recovery | Custom watchdog timer polling `tapIsEnabled` | Handle `.tapDisabledByTimeout` in callback + immediate `tapEnable` | Documented pattern; callback fires synchronously when tap is disabled |
| Thread safety for C callback state | `@MainActor` or actor isolation | Serial `DispatchQueue` + `@unchecked Sendable` | C callbacks cannot be `async`; actor isolation cannot cross C function pointer boundary |
| TCC permission polling | OS notification (no such notification exists) | 2-second `DispatchSourceTimer` polling `CGPreflightListenEventAccess()` | macOS provides no callback/notification for "permission just granted" |
| SystemSettings URL | Hardcoded path | `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` | URL scheme is stable across macOS 13–15; deep-links directly to Accessibility pane |

**Key insight:** The CGEventTap API is a thin C layer. Every complexity — memory management, threading, recovery — must be handled explicitly. There are no higher-level wrappers in the zero-dependency constraint.

---

## Common Pitfalls

### Pitfall 1: Permission API Mismatch — `CGPreflightListenEventAccess()` vs `AXIsProcessTrusted()`

**What goes wrong:** REQUIREMENTS.md EVNT-03 references `AXIsProcessTrusted()`; D-07 locks `CGPreflightListenEventAccess()`. These check different TCC privileges.

**Why it happens:** `AXIsProcessTrusted()` checks the Accessibility privilege (Privacy & Security > Accessibility). `CGPreflightListenEventAccess()` checks the Input Monitoring privilege. For a `.defaultTap` that will later suppress events, Accessibility permission is what macOS enforces — not Input Monitoring.

**Resolution for this phase:** Use `CGPreflightListenEventAccess()` as locked in D-07 (it matches the specific TCC right needed for the event tap). If the tap still fails to create or fires no events despite `CGPreflightListenEventAccess() == true`, add an `AXIsProcessTrusted()` secondary check. The REQUIREMENTS.md wording is slightly imprecise; D-07 is the authoritative decision. [CITED: developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess, developer.apple.com/forums/thread/758554]

**Warning signs:** `CGPreflightListenEventAccess() == true` but `CGEventTapCreate` returns `nil`.

### Pitfall 2: TCC Silent Disable After Rebuild

**What goes wrong:** Rebuild, re-sign, `open ChordTyper.app` — tap appears created (`tapCreate` returns non-nil, `tapIsEnabled` returns `true`), but no callbacks ever fire.

**Why it happens:** TCC ties permission grants to code identity (signature). A rebuild with ad-hoc signing creates a new identity. macOS Launch Services triggers stricter TCC re-evaluation than direct binary execution. The tap is created but silently suppressed. [CITED: danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/]

**How to avoid:** D-11 adds `tccutil reset Accessibility dev.chutipon.chordtyper` to the Makefile `run` target. This forces TCC to re-prompt on each development launch, avoiding the stale-grant silent-disable state.

**Warning signs:** Keystrokes appear in target apps (tap is transparent) but no `os.log` output from callback function.

### Pitfall 3: `passRetained` / `release` Mismatch

**What goes wrong:** Dangling pointer crash or memory leak in the C callback.

**Why it happens:** `Unmanaged.passRetained(self).toOpaque()` increments the Swift retain count. If `selfRetained` is released (or the `EventTapManager` is deallocated) before `destroyTap()` is called, the callback receives a dangling pointer.

**How to avoid:** Store `selfRetained` as an instance property. Only release it in `destroyTap()` after disabling and removing the RunLoopSource, ensuring no further callbacks can fire.

**Warning signs:** EXC_BAD_ACCESS in `eventTapCallback` referencing the `refcon` pointer.

### Pitfall 4: RunLoop Source on Wrong Thread

**What goes wrong:** Tap is created but never receives events; no crash, just silence.

**Why it happens:** `CFRunLoopAddSource` must target the RunLoop that is actually running. If `EventTapManager` is created on the main thread but `CFRunLoopGetCurrent()` is called on a background queue, the source is added to a RunLoop that never runs.

**How to avoid:** Use `CFRunLoopGetMain()` explicitly to attach the source to the main RunLoop (which SwiftUI always runs). Alternative: create the tap on the main thread via `DispatchQueue.main.async`.

**Warning signs:** No callback invocations, `CGEvent.tapIsEnabled(tap:)` returns `true`.

### Pitfall 5: C Callback Cannot Be a Swift Closure

**What goes wrong:** Compiler error: "a C function pointer cannot be formed from a closure that captures context".

**Why it happens:** `CGEventTapCallback` is `@convention(c)` — it must be a free function or static method. Swift closures capture context and therefore cannot be passed as bare C function pointers.

**How to avoid:** Define the callback as a file-scope `private func` with the exact signature matching `CGEventTapCallBack`. Use the `userInfo`/`refcon` pattern to recover the `EventTapManager` instance.

**Warning signs:** Compiler error at the `CGEvent.tapCreate(callback:)` call site if a closure is passed.

### Pitfall 6: `@NSApplicationDelegateAdaptor` + Existing SwiftUI State

**What goes wrong:** Introducing `AppDelegate` loses the existing `@AppStorage` state from `ChordTyperApp`, or the app gets two copies of state.

**Why it happens:** `@NSApplicationDelegateAdaptor` does not replace the `@main` App struct — it adds a delegate alongside it. Both live independently. State owned by the App struct (`@AppStorage` in `ChordTyperApp`) is unaffected.

**How to avoid:** Keep all existing `@AppStorage` keys in `ChordTyperApp.swift` unchanged. `AppDelegate` reads `UserDefaults` directly when it needs `chordTyperEnabled` at tap creation time.

**Warning signs:** Duplicate `@AppStorage` declarations in both `ChordTyperApp` and `AppDelegate`, causing conflicting state.

---

## Code Examples

### Complete EventTapManager Skeleton

```swift
// EventTapManager.swift
// Source: Quartz Event Services + Unmanaged Swift stdlib pattern
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "EventTap")

enum TapState {
    case running
    case stopped
    case noPermission
}

// @unchecked Sendable: thread safety enforced via internal serial `queue`.
// Required by SWIFT_STRICT_CONCURRENCY=complete because EventTapManager is
// passed across concurrency boundaries (AppDelegate → closure → callback).
final class EventTapManager: @unchecked Sendable {

    // Closure hook — Phase 3 leaves nil (pass-through); Phase 4 assigns chord detector
    var eventHandler: ((CGEvent) -> CGEvent?)?

    private let queue = DispatchQueue(label: "dev.chutipon.chordtyper.eventtap",
                                      qos: .userInteractive)
    private var _tapState: TapState = .stopped
    private(set) var tapState: TapState {
        get { queue.sync { _tapState } }
        set { queue.sync { _tapState = newValue } }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    // Must hold passRetained reference for the tap's lifetime
    private var selfRetained: Unmanaged<EventTapManager>?

    // Called from AppDelegate.applicationDidFinishLaunching (main thread)
    func start() {
        if CGPreflightListenEventAccess() {
            createTap()
        } else {
            tapState = .noPermission
            // AppDelegate presents NSAlert — see Permission UX pattern
        }
    }

    func createTap() {
        let keyMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        )
        let retained = Unmanaged.passRetained(self)
        selfRetained = retained

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyMask,
            callback: eventTapCallback,
            userInfo: retained.toOpaque()
        ) else {
            retained.release()
            selfRetained = nil
            tapState = .noPermission
            logger.error("CGEventTapCreate failed — permission revoked or system error")
            return
        }

        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        tapState = .running
        logger.info("CGEventTap installed and running")
    }

    func destroyTap() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        selfRetained?.release()
        selfRetained = nil
        tapState = .stopped
    }

    // Called by callback (background thread) — only touches queue-protected state
    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                logger.warning("CGEventTap re-enabled after timeout/userInput disable")
            }
            return nil
        case .keyDown, .keyUp:
            let result = eventHandler?(event) ?? event
            return Unmanaged.passUnretained(result)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

// File-scope C function — cannot be a closure (would violate @convention(c))
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
```

### AppDelegate Integration

```swift
// AppDelegate.swift — new file in Sources/ChordTyper/
import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventTapManager = EventTapManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        eventTapManager.start()
        registerSleepWakeObservers()
    }

    private func registerSleepWakeObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            logger.info("System wake — verifying CGEventTap")
            if let tap = self.eventTapManager.eventTap,
               !CGEvent.tapIsEnabled(tap: tap) {
                logger.warning("Tap disabled after wake — recreating")
                self.eventTapManager.destroyTap()
                self.eventTapManager.start()
            }
        }
    }
}
```

### ChordTyperApp.swift Modification (add adaptor only)

```swift
// Minimal change to ChordTyperApp.swift — add one line
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
// All existing @AppStorage and MenuBarExtra code is unchanged
```

### Makefile `run` Target Modification (D-11)

```makefile
run: build
	tccutil reset Accessibility dev.chutipon.chordtyper 2>/dev/null || true
	open "$(APP_PATH)"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Carbon `InstallEventHandler` / `RegisterEventHotKey` | `CGEventTap` | macOS 12 (Carbon deprecated) | Carbon is unsupported for arbitrary keystroke interception |
| `NSEvent.addGlobalMonitorForEvents` | `CGEventTap` at session/HID level | Always separate APIs | NSEvent is post-IME; cannot suppress events |
| Global `AppDelegate` as NSApplication delegate | `@NSApplicationDelegateAdaptor` in SwiftUI App struct | SwiftUI (macOS 11+) | Pure AppDelegate entry point not needed with SwiftUI; adaptor bridges both |

**Deprecated/outdated:**
- Carbon event handlers: Formally deprecated macOS 12; removed from Swift overlay. Do not use.
- `NSEvent` global monitors for chord detection: Operates above IME; Thai key codes are pre-transformed.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `@unchecked Sendable` on a class guarded by a serial DispatchQueue is the correct Swift 6 pattern (vs. `nonisolated(unsafe)` per property) | Architecture Patterns / Pattern 5 | Minor — both approaches compile; wrong choice causes lint warnings but not bugs |
| A2 | `CFRunLoopGetMain()` is the correct RunLoop target for the tap's RunLoopSource when EventTapManager is initialized on the main thread | Architecture Patterns / Pattern 1 | Medium — using wrong RunLoop means tap receives no events; silent failure |
| A3 | `CGPreflightListenEventAccess()` checks the same TCC right that `CGEventTapCreate` with `.defaultTap` requires (not `AXIsProcessTrusted()`) | Pitfall 1 / Permission UX | Medium — if the wrong permission is checked, the permission gate passes but tap creation still fails |

**If this table is empty:** Not empty — three assumptions flagged above.

---

## Open Questions

1. **Permission privilege: `CGPreflightListenEventAccess()` vs `AXIsProcessTrusted()` for `.defaultTap`**
   - What we know: D-07 locks `CGPreflightListenEventAccess()`. EVNT-03 names `AXIsProcessTrusted()`. Search results indicate `.defaultTap` requires Accessibility (checked by `AXIsProcessTrusted`) while `.listenOnly` requires Input Monitoring (checked by `CGPreflightListenEventAccess()`). [MEDIUM confidence from Apple forums]
   - What's unclear: Which TCC right macOS enforces for `.defaultTap` at `kCGSessionEventTap` — empirical testing needed.
   - Recommendation: Implement D-07 (`CGPreflightListenEventAccess()`); if tap creation still fails, add a fallback `AXIsProcessTrusted()` check. The two checks are not mutually exclusive.

2. **`eventTap` property visibility for AppDelegate wake recovery**
   - What we know: The `eventTap: CFMachPort?` property needs to be accessible for `CGEvent.tapIsEnabled(tap:)` check in the wake handler, but it's an implementation detail of `EventTapManager`.
   - What's unclear: Whether to expose it as `private(set)` or encapsulate entirely behind a `isRunning: Bool` property.
   - Recommendation: Add `var isRunning: Bool { tapState == .running }` and a `verifyAndRecover()` method on `EventTapManager`; `AppDelegate` calls `verifyAndRecover()` without needing direct `CFMachPort` access.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Swift | All source compilation | Yes | 6.3.2 (Xcode 26.5) | — |
| xcodebuild | `make build`, `make test` | Yes | Xcode 26.5 | — |
| xcodegen | `make generate` | Yes | 2.45.4 | — |
| CoreGraphics (CGEventTap) | EVNT-01, EVNT-02, EVNT-04 | Yes (system framework) | macOS 13+ API | — |
| tccutil | D-11 Makefile run target | Yes (system tool) | macOS system | 2>/dev/null guard in Makefile |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** `tccutil` is guarded with `|| true` in the Makefile — if it fails (e.g., on CI where TCC doesn't apply), the build proceeds normally.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (system, no install) |
| Config file | project.yml (ChordTyperTests target) |
| Quick run command | `xcodebuild -scheme ChordTyperTests -configuration Debug -derivedDataPath .build test` |
| Full suite command | `make test` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EVNT-01 | Tap created at session level with headInsert | unit | `make test` (EventTapManagerTests) | Wave 0 |
| EVNT-02 | Only keyDown and keyUp events intercepted | unit | `make test` (EventTapManagerTests) | Wave 0 |
| EVNT-03 | Permission state machine: noPermission → running | unit | `make test` (EventTapManagerTests) | Wave 0 |
| EVNT-04 | `tapDisabledByTimeout` triggers re-enable | unit | `make test` (EventTapManagerTests) | Wave 0 |
| EVNT-05 | Sleep/wake recovery calls destroyTap + start | unit | `make test` (EventTapManagerTests) | Wave 0 |

**Testing strategy note:** `CGEventTapCreate` requires Accessibility permission and cannot be called in XCTest without a running host app with TCC grant. All `EventTapManager` tests must mock or stub the tap creation. Recommended approach: inject `tapCreator: (CGEventMask, UnsafeMutableRawPointer) -> CFMachPort?` closure into `EventTapManager` so tests supply a mock `CFMachPort` without real TCC interaction. The timeout re-enable logic is testable by calling `handleEvent(type: .tapDisabledByTimeout, event:)` directly.

### Sampling Rate

- **Per task commit:** `make test`
- **Per wave merge:** `make test`
- **Phase gate:** `make build && make test` green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/ChordTyperTests/EventTapManagerTests.swift` — covers EVNT-01 through EVNT-05 (state machine, timeout re-enable, wake recovery)
- [ ] Injectable `tapCreator` closure on `EventTapManager` — enables unit tests without real CGEventTap (avoids TCC dependency in CI/unit test context)

---

## Security Domain

> `security_enforcement` not explicitly false in config.json — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | Yes (partial) | TCC permission check before tap creation; tap disabled if permission revoked |
| V5 Input Validation | No (Phase 3 is pass-through only) | — |
| V6 Cryptography | No | — |

### Known Threat Patterns for CGEventTap

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Event tap installed without user consent | Elevation of Privilege | `CGPreflightListenEventAccess()` gate before tap creation; NSAlert informs user |
| Tap logs all keystrokes to persistent storage | Information Disclosure | Phase 3 has no persistence; callback only calls `eventHandler` closure |
| Synthetic events injected by tap (re-entry) | Tampering | Phase 3 is pass-through — no synthetic events created. Phase 5+ will mark synthetic events to prevent re-entry (TXTO-05) |
| Tap remains active in password fields | Information Disclosure | Phase 3 is pass-through only; SECR-01/02 in Phase 10 handle secure input detection |

---

## Sources

### Primary (HIGH confidence)
- [developer.apple.com/documentation/coregraphics/1454426-cgeventtapcreate](https://developer.apple.com/documentation/coregraphics/1454426-cgeventtapcreate) — `CGEventTapCreate` API, tap locations, placement, options, callback signature
- [developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout) — timeout event type behavior
- [developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap:enable:)?language=objc](https://developer.apple.com/documentation/coregraphics/cgevent/tapenable(tap:enable:)?language=objc) — re-enable API
- [developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()) — Input Monitoring privilege check
- [developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess()](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess()) — Input Monitoring privilege request
- [developer.apple.com/documentation/appkit/nsworkspace/didwakenotification](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification) — sleep/wake notification
- CLAUDE.md — Technology stack, coding conventions, build commands, file responsibilities

### Secondary (MEDIUM confidence)
- [github.com/ghostty-org/ghostty/issues/11883](https://github.com/ghostty-org/ghostty/issues/11883) — `kCGEventTapDisabledByTimeout` real-world failure and fix pattern
- [danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/) — TCC silent-disable after code signing rebuild
- [developer.apple.com/forums/thread/758554](https://developer.apple.com/forums/thread/758554) — CGPreflightListenEventAccess vs AXIsProcessTrusted privilege distinction
- [gist.github.com/osnr/23eb05b4e0bcd335c06361c4fabadd6f](https://gist.github.com/osnr/23eb05b4e0bcd335c06361c4fabadd6f) — Unmanaged/passRetained CGEventTap pattern in Swift
- [jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) — NSAlert + System Settings URL pattern

### Tertiary (LOW confidence)
- WebSearch results on Swift 6 strict concurrency + DispatchQueue class pattern — informational, not authoritative for SWIFT_STRICT_CONCURRENCY=complete behavior

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Apple frameworks only; no package choices
- Architecture: HIGH — All patterns sourced from Apple documentation or widely-verified real-world implementations (Ghostty, community gists)
- Pitfalls: HIGH — TCC silent-disable and Unmanaged memory patterns sourced from documented incidents and official docs
- Swift 6 concurrency approach: MEDIUM — `@unchecked Sendable` guidance from training knowledge; not Context7-verified this session

**Research date:** 2026-05-21
**Valid until:** 2026-11-21 (stable API; CGEventTap has been stable since macOS 10.4)
