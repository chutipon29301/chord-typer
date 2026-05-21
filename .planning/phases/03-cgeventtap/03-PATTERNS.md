# Phase 3: CGEventTap - Pattern Map

**Mapped:** 2026-05-21
**Files analyzed:** 5 (3 new, 1 modified, 1 config-modified)
**Analogs found:** 4 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Sources/ChordTyper/EventTapManager.swift` | service | event-driven | `Sources/ChordTyper/ChordTyperApp.swift` | partial (same logger, AppStorage, AppKit patterns) |
| `Sources/ChordTyper/AppDelegate.swift` | controller | event-driven | `Sources/ChordTyper/ChordTyperApp.swift` | role-match (App lifecycle, NSWorkspace, os.log) |
| `Sources/ChordTyper/ChordTyperApp.swift` | config (modify) | request-response | self | exact |
| `Tests/ChordTyperTests/EventTapManagerTests.swift` | test | event-driven | `Tests/ChordTyperTests/MenuStateTests.swift` | role-match (XCTest structure, setUp, naming convention) |
| `Makefile` | config (modify) | batch | self | exact |

## Pattern Assignments

### `Sources/ChordTyper/EventTapManager.swift` (service, event-driven)

**Analog:** `Sources/ChordTyper/ChordTyperApp.swift`

**Imports pattern** (ChordTyperApp.swift lines 1-5):
```swift
import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppMenu")
```

For EventTapManager, adjust to:
```swift
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "EventTap")
```

**Logger pattern** — use file-level `private let logger`, same subsystem `"dev.chutipon.chordtyper"`, category matches file role. Never use `print()`.

**NSWorkspace pattern** (ChordTyperApp.swift line 42):
```swift
NSWorkspace.shared.open(dictionariesURL)
```
Wake recovery uses `NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, ...)` — same `NSWorkspace.shared` access point.

**Guard-let error path pattern** (ChordTyperApp.swift lines 35-44):
```swift
guard let resourceURL = Bundle.main.resourceURL else {
    logger.error("Bundle resourceURL is nil — cannot locate dictionaries")
    return
}
```
Apply the same guard/logger.error pattern for `CGEventTapCreate` failure:
```swift
guard let tap = CGEvent.tapCreate(...) else {
    retained.release()
    selfRetained = nil
    tapState = .noPermission
    logger.error("CGEventTapCreate failed — permission revoked or system error")
    return
}
```

**Core pattern** — no direct codebase analog for CGEventTap; use RESEARCH.md code examples verbatim. Key structural elements extracted from research:

```swift
// @unchecked Sendable: manual thread safety via serial DispatchQueue (D-02, RESEARCH Pattern 5)
final class EventTapManager: @unchecked Sendable {
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
    private var selfRetained: Unmanaged<EventTapManager>?
}
```

**C callback bridge pattern** (RESEARCH Pattern 1 — file-scope function, not a closure):
```swift
// Must be file-scope private func — closures cannot be @convention(c)
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

**Timeout re-enable pattern** (RESEARCH Pattern 2):
```swift
case .tapDisabledByTimeout, .tapDisabledByUserInput:
    if let tap = eventTap {
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.warning("CGEventTap re-enabled after timeout/userInput disable")
    }
    return nil  // pseudo-event — never pass through
```

**TapState enum** — mirrors the menubar enabled/disabled toggle pattern from ChordTyperApp, but as a tri-state:
```swift
enum TapState {
    case running
    case stopped
    case noPermission
}
```

**Permission check + polling** (RESEARCH Pattern 4):
```swift
func start() {
    if CGPreflightListenEventAccess() {
        createTap()
    } else {
        tapState = .noPermission
        showPermissionAlert()
        startPermissionPolling()
    }
}
```

**Injectable tapCreator for testability** (RESEARCH Validation Architecture):
```swift
// Inject mock tap creator in tests — avoids TCC dependency
var tapCreator: (CGEventMask, UnsafeMutableRawPointer) -> CFMachPort? = { mask, userInfo in
    CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: eventTapCallback,
        userInfo: userInfo
    )
}
```

---

### `Sources/ChordTyper/AppDelegate.swift` (controller, event-driven)

**Analog:** `Sources/ChordTyper/ChordTyperApp.swift`

**Imports pattern** (ChordTyperApp.swift lines 1-5):
```swift
import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppDelegate")
```

**Class declaration pattern** — plain `NSObject` subclass conforming to `NSApplicationDelegate`, matching D-02 (plain class, not actor):
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    let eventTapManager = EventTapManager()
    ...
}
```

**NSWorkspace notification pattern** (from ChordTyperApp.swift line 42 — same `NSWorkspace.shared` entry point, different API):
```swift
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    guard let self else { return }
    logger.info("System wake — verifying CGEventTap")
    self.eventTapManager.verifyAndRecover()
}
```

**NSAlert permission UX pattern** (RESEARCH Pattern 4 — no existing codebase analog):
```swift
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
```

**AppStorage access without @AppStorage** (D-context Pitfall 6 — AppDelegate reads UserDefaults directly):
```swift
// AppDelegate reads UserDefaults directly — never duplicate @AppStorage declarations
let isEnabled = UserDefaults.standard.bool(forKey: "chordTyperEnabled")
```

---

### `Sources/ChordTyper/ChordTyperApp.swift` (config, modify)

**Analog:** self (existing file, lines 1-55)

**Modification:** Add a single property declaration inside `ChordTyperApp` struct body, after the `@AppStorage` declarations (after line 12):

```swift
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

**Do not change** any existing `@AppStorage` declarations, `menuBarIcon`, `body`, or `MenuBarExtra` contents. This is a one-line addition.

---

### `Tests/ChordTyperTests/EventTapManagerTests.swift` (test, event-driven)

**Analog:** `Tests/ChordTyperTests/MenuStateTests.swift`

**Imports and class structure** (MenuStateTests.swift lines 1-9):
```swift
import XCTest

final class EventTapManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // reset state before each test
    }
    ...
}
```

**Test naming convention** (MenuStateTests.swift lines 19-26) — `test[Component]_[scenario]_[expectedBehavior]`:
```swift
func testMenuState_menuBarIcon_activeShouldBeKeyboardFill() { ... }
func testMenuState_menuBarIcon_pausedShouldBeKeyboardBadgeEllipsis() { ... }
```

Apply the same naming pattern:
```swift
func testEventTapManager_timeoutDisable_reEnablesImmediately() { ... }
func testEventTapManager_noPermission_tapStateIsNoPermission() { ... }
func testEventTapManager_keyDownEvent_passedThroughByDefaultHandler() { ... }
func testEventTapManager_wakeRecovery_callsDestroyAndStart() { ... }
```

**Private helper pattern** (MenuStateTests.swift lines 15-17):
```swift
// Mirror the logic under test as a pure function for isolated testing
private func iconName(for enabled: Bool) -> String { ... }
```

Apply same approach for testable tap state transitions — test `handleEvent(type:event:)` directly without real CGEventTap.

**XCTest async/expectation pattern** — for any async state transitions, use `XCTestExpectation` matching existing test style (synchronous preferred, no `async` test methods in existing files).

---

### `Makefile` (config, modify)

**Analog:** self (existing file, lines 15-16)

**Current `run` target** (Makefile lines 15-16):
```makefile
run: build
	open "$(APP_PATH)"
```

**Modified `run` target** (D-11):
```makefile
run: build
	tccutil reset Accessibility dev.chutipon.chordtyper 2>/dev/null || true
	open "$(APP_PATH)"
```

**Pattern note:** The `2>/dev/null || true` guard matches Makefile resilience convention — command failure never blocks the target. No other Makefile targets change.

---

## Shared Patterns

### Logger Declaration
**Source:** `Sources/ChordTyper/ChordTyperApp.swift` lines 5
**Apply to:** `EventTapManager.swift`, `AppDelegate.swift`
```swift
private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "<FileRole>")
```
- `EventTapManager.swift` category: `"EventTap"`
- `AppDelegate.swift` category: `"AppDelegate"`
- Use `logger.info()`, `logger.warning()`, `logger.error()` — never `print()`
- Log privacy: use `\(value, privacy: .public)` for non-sensitive diagnostic values

### Guard-let Error Handling
**Source:** `Sources/ChordTyper/ChordTyperApp.swift` lines 35-44
**Apply to:** `EventTapManager.swift` tap creation, AppDelegate delegate method guard clauses
```swift
guard let x = optionalValue else {
    logger.error("Descriptive failure message")
    return  // or early return with state update
}
```
No force unwraps (`!`) anywhere — enforced by CLAUDE.md.

### No Force Unwraps
**Source:** CLAUDE.md coding conventions
**Apply to:** All new files
```swift
// WRONG:
let tap = CGEvent.tapCreate(...)!

// RIGHT:
guard let tap = CGEvent.tapCreate(...) else {
    logger.error("CGEventTapCreate failed")
    return
}
```

### AppKit NSWorkspace Access
**Source:** `Sources/ChordTyper/ChordTyperApp.swift` line 42
**Apply to:** `AppDelegate.swift` (sleep/wake observer, permission Settings URL)
```swift
NSWorkspace.shared.open(url)
NSWorkspace.shared.notificationCenter.addObserver(...)
```

### XCTest File Structure
**Source:** `Tests/ChordTyperTests/MenuStateTests.swift` lines 1-9
**Apply to:** `Tests/ChordTyperTests/EventTapManagerTests.swift`
```swift
import XCTest

final class <Name>Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        // teardown any state
    }

    // MARK: - <Group Name>

    func test<Component>_<scenario>_<expectedBehavior>() {
        // Arrange
        // Act
        // Assert
    }
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Sources/ChordTyper/EventTapManager.swift` (core CGEventTap logic) | service | event-driven | No event-driven services with C callback bridge exist in the codebase yet — use RESEARCH.md Pattern 1-5 code examples directly |

Note: `EventTapManager.swift` has partial analogs (logger, guard patterns, NSWorkspace) from `ChordTyperApp.swift`, but the CGEventTap lifecycle, `Unmanaged` bridge, `@unchecked Sendable`, and `DispatchSourceTimer` polling have no codebase precedent. Planner must use RESEARCH.md code examples for those sections.

---

## Metadata

**Analog search scope:** `Sources/ChordTyper/`, `Tests/ChordTyperTests/`, `Makefile`, `project.yml`
**Files scanned:** 7 (`ChordTyperApp.swift`, `ChordTyperSmokeTests.swift`, `MenuStateTests.swift`, `DictionaryBundleTests.swift`, `Makefile`, `project.yml`, `Resources/ChordTyper.entitlements`)
**Pattern extraction date:** 2026-05-21
