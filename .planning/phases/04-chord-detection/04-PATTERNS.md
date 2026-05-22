# Phase 4: Chord Detection - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 3 (2 new, 1 modified)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Sources/ChordTyper/ChordDetector.swift` | service | event-driven | `Sources/ChordTyper/EventTapManager.swift` | role-match (same serial-queue + injectable-closure pattern) |
| `Sources/ChordTyper/AppDelegate.swift` | config/wiring | request-response | `Sources/ChordTyper/AppDelegate.swift` itself | exact (edit to existing file) |
| `Tests/ChordTyperTests/ChordEngineTests.swift` | test | event-driven | `Tests/ChordTyperTests/EventTapManagerTests.swift` | exact |

---

## Pattern Assignments

### `Sources/ChordTyper/ChordDetector.swift` (service, event-driven)

**Analog:** `Sources/ChordTyper/EventTapManager.swift`

**Imports pattern** (lines 1-6):
```swift
import ApplicationServices
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "ChordEngine")
```

**Class declaration + thread-safety annotation** (lines 20-21):
```swift
/// Thread safety: all mutable state is guarded by an internal serial DispatchQueue.
/// Annotated `@unchecked Sendable` because thread safety is manually enforced (D-05).
final class ChordEngine: @unchecked Sendable {
```

**Serial DispatchQueue pattern** (lines 84-87):
```swift
private let queue = DispatchQueue(
    label: "dev.chutipon.chordtyper.chordengine",
    qos: .userInteractive
)
```

**Injectable closure pattern** (lines 41-55 — permissionChecker/tapCreator as the model):
```swift
// EventTapManager uses this pattern for all injectable dependencies:
var permissionChecker: () -> Bool = {
    CGPreflightListenEventAccess() || AXIsProcessTrusted()
}
// ChordEngine adopts the same pattern for dictionary lookup (D-14):
var chordLookup: (String) -> String? = { _ in nil }
```

**Public entry point that dispatches sync to guard state** (lines 158, 168):
```swift
// EventTapManager exposes handleEvent — ChordEngine exposes process(event:type:)
// Both bridge from a calling thread into the serial queue.
// CRITICAL: isReplaying check BEFORE queue.sync to avoid deadlock (see Pattern 5 in RESEARCH.md)
func process(event: CGEvent, type: CGEventType) -> ChordResult {
    if _isReplaying { return .passThrough(event) }
    return queue.sync { _process(event: event, type: type) }
}
```

**State enum pattern** (lines 9-13 — TapState as the model):
```swift
// TapState is the established project pattern for state enums:
enum TapState: Equatable {
    case running
    case stopped
    case noPermission
}
// ChordEngineState follows the same shape (no raw values, Equatable):
enum ChordEngineState: Equatable {
    case idle
    case collecting
    case evaluating
}
```

**Logging pattern** (lines 125-138 — notice/warning/error/info usage):
```swift
logger.notice("CGEventTap installed and running")   // lifecycle transitions
logger.warning("CGEventTap re-enabled after timeout/userInput disable")  // recoverable anomaly
logger.error("CGEventTapCreate failed — permission revoked or system error")  // hard failure
logger.info("Tap verified healthy after wake")  // verbose/diagnostic
```

**DispatchWorkItem cancellation pattern** (lines 199-221 — DispatchSource timer as analog):
```swift
// EventTapManager uses DispatchSource timer with cancel(); DispatchWorkItem uses same idiom:
private var pollTimer: DispatchSourceTimer?
// ...
timer.cancel()
// ChordEngine analog:
private var _windowWorkItem: DispatchWorkItem?
// _windowWorkItem?.cancel(); _windowWorkItem = nil
```

**Weak self in closures** (lines 204-219):
```swift
timer.setEventHandler { [weak self] in
    guard let self else { return }
    // ...
}
// ChordEngine asyncAfter closure follows identical pattern
```

**ChordResult enum** (from CONTEXT.md D-13 — no existing analog; see Shared Patterns):
```swift
enum ChordResult {
    case passThrough(CGEvent)
    case suppress
    case chord(key: String, buffered: [CGEvent])
}
```

---

### `Sources/ChordTyper/AppDelegate.swift` (config/wiring, request-response) — EDIT

**Analog:** `Sources/ChordTyper/AppDelegate.swift` (existing file, lines 1-77)

**Existing ownership pattern** (lines 13):
```swift
let eventTapManager = EventTapManager()
```
Add ChordEngine on the next line:
```swift
let chordEngine = ChordEngine()
```

**Existing closure wiring in applicationDidFinishLaunching** (lines 17-29):
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    eventTapManager.onPermissionDenied = { [weak self] in
        DispatchQueue.main.async {
            self?.showPermissionAlert()
        }
    }
    eventTapManager.start()
    registerSleepWakeObserver()
    logger.notice("Application launched — EventTapManager started")
}
```
Wire ChordEngine into eventHandler BEFORE `eventTapManager.start()` using the same `[weak self]` + guard pattern:
```swift
eventTapManager.eventHandler = { [weak self] event in
    guard let self else { return event }
    let result = self.chordEngine.process(event: event, type: event.type)
    switch result {
    case .passThrough(let e): return e
    case .suppress:           return nil
    case .chord(_, _):        return nil  // Phase 6 handles output
    }
}
```

---

### `Tests/ChordTyperTests/ChordEngineTests.swift` (test, event-driven)

**Analog:** `Tests/ChordTyperTests/EventTapManagerTests.swift`

**Imports and class declaration** (lines 1-5):
```swift
import XCTest
@testable import ChordTyper
import CoreGraphics

final class ChordEngineTests: XCTestCase {
```

**setUp/tearDown pattern** (lines 18-55):
```swift
private var engine: ChordEngine!

override func setUp() {
    super.setUp()
    engine = ChordEngine()
    // Inject hardcoded dictionary (D-14)
    engine.chordLookup = { key in ["eht": "the", "adn": "and"][key] }
}

override func tearDown() {
    engine = nil
    super.tearDown()
}
```

**Test naming convention** (lines 59-76 — EventTapManagerTests pattern):
```swift
// Pattern: test[Class]_[scenario]_[expectedBehavior]
func testEventTapManager_initialState_isStopped()
func testEventTapManager_startWithoutPermission_stateIsNoPermission()
// ChordEngine tests follow the same convention:
// testChordEngine_threeKeysReleased_producesChordKey()
// testChordEngine_twoKeysOnly_passesThrough()
// testChordEngine_modifierHeld_abortsAndFlushes()
```

**CGEvent factory helper pattern** (lines 96-99, 110-113):
```swift
// EventTapManagerTests creates events inline:
guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
    XCTFail("Failed to create test CGEvent")
    return
}
// ChordEngineTests should extract to a private helper:
private func makeKeyEvent(keycode: UInt16, down: Bool) -> CGEvent {
    CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: down)!
}
```

**Boolean mock state injection** (lines 9-13, 31-48):
```swift
// EventTapManagerTests tracks side effects with Bool flags:
private var tapCreated: Bool = false
private var tapEnabled: Bool = false
// ChordEngineTests can track replay calls similarly:
private var postedEvents: [CGEvent] = []
```

**Assert on enum cases** (lines 100-103 — EventTapManagerTests checks nil/notNil):
```swift
// ChordEngineTests should use if-case for associated-value enums:
if case .chord(let key, _) = result {
    XCTAssertEqual(key, "eht")
} else {
    XCTFail("Expected .chord, got \(result)")
}
```

---

## Shared Patterns

### Thread Safety — Serial DispatchQueue
**Source:** `Sources/ChordTyper/EventTapManager.swift` lines 84-93
**Apply to:** `ChordDetector.swift`
```swift
private let queue = DispatchQueue(
    label: "dev.chutipon.chordtyper.chordengine",
    qos: .userInteractive
)

// Public accessors synchronize via queue.sync:
private var _tapState: TapState = .stopped
private(set) var tapState: TapState {
    get { queue.sync { _tapState } }
    set { queue.sync { _tapState = newValue } }
}
```

### Logging
**Source:** `Sources/ChordTyper/EventTapManager.swift` lines 6, 125-138
**Apply to:** `ChordDetector.swift`, `AppDelegate.swift` edits
```swift
private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "ChordEngine")
// Use .notice for lifecycle transitions, .warning for recoverable anomalies,
// .error for hard failures, .info for diagnostic/verbose.
```

### Injectable Closures for Testability
**Source:** `Sources/ChordTyper/EventTapManager.swift` lines 41-80
**Apply to:** `ChordDetector.swift`
```swift
// Declare with var + default value. Tests override in setUp.
var permissionChecker: () -> Bool = { CGPreflightListenEventAccess() || AXIsProcessTrusted() }
// ChordEngine pattern:
var chordLookup: (String) -> String? = { _ in nil }
```

### Weak Self in Async Closures
**Source:** `Sources/ChordTyper/EventTapManager.swift` lines 204-219, `AppDelegate.swift` lines 19-22
**Apply to:** `ChordDetector.swift` (DispatchWorkItem), `AppDelegate.swift` (eventHandler wiring)
```swift
// Always [weak self] + guard let self:
{ [weak self] in
    guard let self else { return }
    // use self safely
}
```

### No Force Unwraps
**Source:** `Sources/ChordTyper/EventTapManager.swift` lines 121-128 (guard let tap = ...)
**Apply to:** All new files
```swift
// Use guard let / if let / ?? — never !
// Exception in tests only: CGEvent factory helper may use ! when failure is a test bug.
```

---

## No Analog Found

All three files have analogs. No entries.

---

## Metadata

**Analog search scope:** `Sources/ChordTyper/`, `Tests/ChordTyperTests/`
**Files scanned:** 3 source files, 4 test files
**Pattern extraction date:** 2026-05-22
