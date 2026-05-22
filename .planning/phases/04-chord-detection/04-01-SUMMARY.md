---
phase: 04-chord-detection
plan: "01"
subsystem: chord-detection
tags: [chord-engine, state-machine, tdd, cgevent, swift]
dependency_graph:
  requires: [03-cgeventtap]
  provides: [ChordEngine, ChordResult, ChordEngineState]
  affects: [EventTapManager.eventHandler, AppDelegate]
tech_stack:
  added: []
  patterns:
    - Serial DispatchQueue for thread-safe state machine (plain class, not actor)
    - OSAllocatedUnfairLock for re-entry guard outside queue.sync
    - Cancellable DispatchWorkItem for timing window on same serial queue
    - Injectable eventPoster closure for testable replay without real CGEventPost
    - Static US QWERTY keycode-to-char table for IME-independent sorted-alpha encoding
key_files:
  created:
    - Sources/ChordTyper/ChordDetector.swift
    - Tests/ChordTyperTests/ChordEngineTests.swift
  modified:
    - Sources/ChordTyper/AppDelegate.swift
decisions:
  - "ChordEngine uses plain class + serial DispatchQueue (not actor) — CGEventTap callbacks are synchronous C code; cannot use await"
  - "OSAllocatedUnfairLock for isReplaying guard checked BEFORE queue.sync — prevents deadlock during CGEvent.post replay"
  - "Static US QWERTY keycode-to-char table (not CGEvent.keyboardGetUnicodeString) — IME-independent, consistent with Thai IME active"
  - "ChordResult.chord(key:buffered:) carries both sorted-alpha key and original events — Phase 6 needs both for output"
  - "AppDelegate wires ChordEngine before eventTapManager.start() — ensures no events pass through without chord processing"
metrics:
  duration: "~6 min"
  completed_date: "2026-05-22"
  tasks_completed: 3
  files_changed: 3
---

# Phase 4 Plan 1: ChordEngine State Machine Summary

ChordEngine three-state machine (idle→collecting→evaluating) with 50ms timing window, sorted-alpha chord key encoding, and injectable replay/lookup closures — wired into EventTapManager via AppDelegate.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write failing ChordEngine tests + stub (RED) | 5f257cd | ChordDetector.swift (stub), ChordEngineTests.swift |
| 2 | Implement ChordEngine state machine (GREEN) | 50050d2 | ChordDetector.swift (full) |
| 3 | Wire ChordEngine into AppDelegate | a01bf73 | AppDelegate.swift |

## What Was Built

**ChordDetector.swift** — Full state machine implementation:
- `ChordEngineState` enum: `.idle`, `.collecting`, `.evaluating`
- `ChordResult` enum: `.passThrough(CGEvent)`, `.suppress`, `.chord(key:buffered:)`
- `ChordEngine` final class with serial DispatchQueue, OSAllocatedUnfairLock re-entry guard
- Static keycodeToChar table for US QWERTY 26 letter keys (IME-independent)
- `process(event:type:)` — main entry point, re-entry guard checked before queue.sync
- Timing window via cancellable DispatchWorkItem on same serial queue
- Modifier abort (Cmd/Shift/Option/Control) flushes buffer and resets state
- Injectable `chordLookup`, `eventPoster` closures for testability

**ChordEngineTests.swift** — 11 tests covering all CHRD requirements:
- `testChordEngine_threeKeysReleased_producesChordKey` — T+H+E → "eht"
- `testChordEngine_differentKeyOrder_sameChordKey` — H+E+T → "eht" (order independence)
- `testChordEngine_twoKeysOnly_passesThrough` — 2 keys never produce .chord
- `testChordEngine_evaluatesOnAllKeysReleased_notOnKeyDown` — keyDown returns .suppress
- `testChordEngine_unmatchedChord_replaysAllEvents` — 6 events replayed on mismatch
- `testChordEngine_unmatchedChord_buffersKeyDownAndKeyUp` — both down+up replayed (D-10)
- `testChordEngine_modifierKeyHeld_abortsChord` — modifier aborts, state → idle
- `testChordEngine_isReplayingGuard_preventsReEntry` — re-entry returns .passThrough
- `testChordEngine_initialState_isIdle` — fresh engine is .idle
- `testChordEngine_configurableTimingWindow` — default 50ms, accepts custom values
- `testChordEngine_sortedChordKey_keycodeMapping` — keycodes 0,11,8 → "abc"

**AppDelegate.swift** — ChordEngine wired into EventTapManager:
- `chordEngine` property (peer of `eventTapManager`)
- `eventHandler` closure maps `ChordResult` to `CGEvent?` for the tap callback
- Wired before `eventTapManager.start()` per D-12

## Verification

All plan verification criteria met:
1. `make build` succeeds with zero errors
2. `make test` passes all 28 tests (17 existing + 11 new ChordEngine tests)
3. ChordDetector.swift contains ChordEngine, ChordResult, ChordEngineState
4. AppDelegate.swift contains chordEngine property and eventHandler wiring
5. `grep -c "testChordEngine"` returns 11

## TDD Gate Compliance

- RED gate: commit `5f257cd` — `test(04-01): add failing ChordEngine tests + stub (RED)` — 8 tests failing
- GREEN gate: commit `50050d2` — `feat(04-01): implement ChordEngine state machine (GREEN)` — all 11 pass
- REFACTOR gate: no refactor needed — code is clean as written

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CGEventPost deprecated API**
- **Found during:** Task 1 stub compilation
- **Issue:** `CGEventPost(.cghidEventTap, $0)` is replaced by `$0.post(tap: .cghidEventTap)` in Swift 6
- **Fix:** Changed `eventPoster` default to use `$0.post(tap: .cghidEventTap)`
- **Files modified:** Sources/ChordTyper/ChordDetector.swift
- **Commit:** 5f257cd

**2. [Rule 1 - Bug] String interpolation with captured property in logger**
- **Found during:** Task 2 GREEN compilation
- **Issue:** Swift 6 strict concurrency required explicit `self` capture in string interpolation within DispatchWorkItem closure context
- **Fix:** Extracted `_heldKeys.count` to a local variable before logger call
- **Files modified:** Sources/ChordTyper/ChordDetector.swift
- **Commit:** 50050d2

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. `ChordEngine` processes in-memory CGEvent objects only; no persistence or network boundary. Threat mitigations T-04-01 (isReplaying re-entry guard) and T-04-04 (modifier abort) are implemented as specified.

## Known Stubs

None — all data paths are wired. `chordLookup` defaults to `{ _ in nil }` (returns no matches) which is intentional: Phase 5 (DictionaryManager) replaces this closure. The ChordEngine correctly handles the no-match path by replaying buffered events.

## Self-Check: PASSED

Files verified:
- Sources/ChordTyper/ChordDetector.swift: FOUND
- Tests/ChordTyperTests/ChordEngineTests.swift: FOUND
- Sources/ChordTyper/AppDelegate.swift: FOUND (modified)

Commits verified:
- 5f257cd: FOUND (RED phase)
- 50050d2: FOUND (GREEN phase)
- a01bf73: FOUND (AppDelegate wiring)
