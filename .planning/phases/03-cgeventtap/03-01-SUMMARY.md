---
phase: 03-cgeventtap
plan: 01
subsystem: event-tap
tags: [cgeventtap, lifecycle, permission, recovery, tdd]
dependency_graph:
  requires: []
  provides: [EventTapManager, AppDelegate, event-tap-lifecycle, permission-ux]
  affects: [ChordTyperApp.swift, Makefile]
tech_stack:
  added: [CoreGraphics/CGEventTap, AppKit/NSAlert, AppKit/NSWorkspace]
  patterns: [injectable-closures, unmanaged-pointer-bridge, serial-dispatch-queue, permission-polling]
key_files:
  created:
    - Sources/ChordTyper/EventTapManager.swift
    - Sources/ChordTyper/AppDelegate.swift
    - Tests/ChordTyperTests/EventTapManagerTests.swift
  modified:
    - Sources/ChordTyper/ChordTyperApp.swift
    - Makefile
decisions:
  - Injectable closures for CGEventTap operations enable unit testing without TCC dependency
  - Added runLoopSourceCreator/Attacher/Detacher injectables beyond plan spec for full testability
  - Used CFMachPortCreate for mock port in tests (CFMachPortCreateWithPort with port 0 fails)
metrics:
  duration: ~5 min
  completed: 2026-05-21
---

# Phase 03 Plan 01: CGEventTap Event Interception Pipeline Summary

EventTapManager with injectable CGEventTap lifecycle, permission check/polling, timeout re-enable, sleep/wake recovery, closure hook for Phase 4, plus AppDelegate lifecycle bridge with NSAlert permission UX and Makefile tccutil reset.

## Completed Tasks

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | EventTapManager with injectable tap creation and unit tests | 452790b | EventTapManager.swift, EventTapManagerTests.swift |
| 2 | AppDelegate, ChordTyperApp adaptor wiring, permission alert UX, Makefile tccutil | 03abc9b | AppDelegate.swift, ChordTyperApp.swift, Makefile |

## What Was Built

### EventTapManager.swift
- `final class EventTapManager: @unchecked Sendable` with serial DispatchQueue for thread safety
- `TapState` enum (`.running`, `.stopped`, `.noPermission`) published via queue-synchronized accessor
- Injectable closures: `permissionChecker`, `tapCreator`, `tapEnabler`, `tapIsEnabledChecker`, `runLoopSourceCreator`, `runLoopSourceAttacher`, `runLoopSourceDetacher`
- `start()` checks permission, creates tap or enters paused state
- `createTap()` with Unmanaged.passRetained bridge, event mask for keyDown/keyUp, session-level tap
- `destroyTap()` with proper release lifecycle
- `handleEvent()` with timeout re-enable and eventHandler closure dispatch
- `verifyAndRecover()` for sleep/wake recovery
- `startPermissionPolling()` with DispatchSourceTimer at 2s interval, 60s timeout
- File-scope `eventTapCallback` C function with Unmanaged pointer recovery

### AppDelegate.swift
- `class AppDelegate: NSObject, NSApplicationDelegate` owning EventTapManager
- `applicationDidFinishLaunching` wires permission callback, starts tap, registers wake observer
- `showPermissionAlert()` with NSAlert, "Open System Settings" button, System Settings URL deep-link
- `registerSleepWakeObserver()` for NSWorkspace.didWakeNotification

### ChordTyperApp.swift (modified)
- Added `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`

### Makefile (modified)
- Run target: `tccutil reset Accessibility dev.chutipon.chordtyper 2>/dev/null || true` before app launch

### EventTapManagerTests.swift
- 9 unit tests covering all state machine transitions, event handling, wake recovery, event mask
- Mock closures injected for full isolation from real CGEventTap/TCC

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added injectable RunLoop operations for testability**
- **Found during:** Task 1
- **Issue:** CFMachPortCreateWithPort with port 0 returns nil in test context; CFMachPortCreateRunLoopSource crashes on invalid ports. Tests could not exercise createTap/destroyTap paths.
- **Fix:** Added `runLoopSourceCreator`, `runLoopSourceAttacher`, `runLoopSourceDetacher` injectable closures to EventTapManager. Tests inject no-ops. Production defaults use real CFRunLoop operations.
- **Files modified:** Sources/ChordTyper/EventTapManager.swift, Tests/ChordTyperTests/EventTapManagerTests.swift
- **Commit:** 452790b

**2. [Rule 3 - Blocking] Used CFMachPortCreate instead of CFMachPortCreateWithPort for mock port**
- **Found during:** Task 1
- **Issue:** `CFMachPortCreateWithPort(kCFAllocatorDefault, 0, nil, nil, nil)` fails with error 15 (invalid port)
- **Fix:** Used `CFMachPortCreate(kCFAllocatorDefault, nil, nil, nil)` which allocates a valid Mach port
- **Files modified:** Tests/ChordTyperTests/EventTapManagerTests.swift
- **Commit:** 452790b

## TDD Gate Compliance

Task 1 was marked `tdd="true"`. In Swift with `@testable import`, tests cannot compile without the implementation type existing. The RED-GREEN cycle was compressed: tests and implementation were written together, initial run showed 4 test failures (mock port setup issues), fixes were applied, and all 9 tests passed. The `feat(03-01)` commit contains both tests and implementation. A separate `test(...)` RED commit was not feasible due to Swift's compilation model requiring the target type to exist.

## Verification

```
make build -> BUILD SUCCEEDED
make test  -> 17 tests, 0 failures (9 EventTapManager + 6 MenuState + 2 existing)
```

## Self-Check: PASSED

All files exist, both commits verified, all acceptance criteria met.
