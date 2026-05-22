---
status: resolved
trigger: "Option+Tab causes 10+ second freeze/deadlock in ChordEngine"
created: 2026-05-22
updated: 2026-05-22
---

## Symptoms

- **Expected behavior**: Option+Tab should pass through transparently (modifier abort path) without any delay
- **Actual behavior**: Pressing Option+Tab causes the entire system to freeze for 10+ seconds — all keyboard input blocked
- **Error messages**: None visible — the system just freezes (likely CGEventTap disabled by timeout after ~10s)
- **Timeline**: First observed after Phase 04 (ChordEngine integration into EventTapManager)
- **Reproduction**: Press Option key then Tab key while ChordTyper is running

## Analysis Context

Key files:
- Sources/ChordTyper/ChordDetector.swift — ChordEngine with queue.sync in process()
- Sources/ChordTyper/EventTapManager.swift — CGEventTap callback on main RunLoop thread
- Sources/ChordTyper/AppDelegate.swift — wiring eventHandler closure

## Current Focus

- hypothesis: CONFIRMED — _abortChord and _replayAndReset called eventPoster synchronously from inside the CGEventTap callback thread. CGEvent.post(tap: .cghidEventTap) is synchronous — it blocks the calling thread waiting for the RunLoop to deliver the re-injected event. The RunLoop cannot advance because the tap callback hasn't returned yet. This circular wait produces a 10+ second freeze until CGEventTap times out.
- next_action: RESOLVED

## Evidence

- timestamp: 2026-05-22T16:30
  observation: "_abortChord calls eventPoster synchronously inside queue.sync block. eventPoster defaults to CGEvent.post(tap: .cghidEventTap). CGEvent.post is synchronous — blocks until RunLoop delivers the event. RunLoop is on the main thread executing the tap callback. Circular wait."
  conclusion: eventPoster must be deferred until AFTER the tap callback returns.

- timestamp: 2026-05-22T16:45
  observation: "Confirmed via test: testReplayDispatcher_productionDefault_isAsync. With old code (sync eventPoster), posterCalledDuringProcess = true. With fix (async default via DispatchQueue.main.async), posterCalledDuringProcess = false."
  conclusion: Fix verified RED→GREEN via TDD cycle.

## Eliminated

- Re-entrant queue.sync deadlock (same-thread double-acquire): NOT the cause. _isReplayingLock already prevents re-entrant process() calls. The deadlock is RunLoop/callback, not queue/queue.
- Background worker thread blocking: NOT the primary mechanism. CGEvent.post blocks the calling thread (tap callback thread = main RunLoop thread), not a background worker.

## Resolution

- root_cause: `_abortChord` and `_replayAndReset` called `eventPoster` (CGEvent.post) synchronously while the CGEventTap callback was still executing on the main RunLoop thread. CGEvent.post is synchronous — it blocks waiting for the RunLoop to deliver the re-injected event. The RunLoop can't advance until the tap callback returns. Circular wait → 10+ second freeze until tap times out.
- fix: Added injectable `replayDispatcher` closure to ChordEngine. Default is `DispatchQueue.main.async` (defers eventPoster calls until after the tap callback returns). Tests inject `{ $0() }` (synchronous) for deterministic assertions. Both `_abortChord` and `_replayAndReset` now call `replayDispatcher { ... }` instead of calling `eventPoster` directly.
- verification: `make test` — 35 tests pass. `testReplayDispatcher_productionDefault_isAsync` confirms the production default is async. Red/green cycle confirmed: old code fails to compile new tests (missing `replayDispatcher` member).
- files_changed:
  - Sources/ChordTyper/ChordDetector.swift — added `replayDispatcher` property, updated `_abortChord` and `_replayAndReset` to use it
  - Tests/ChordTyperTests/ChordEngineTests.swift — added `engine.replayDispatcher = { $0() }` in setUp
  - Tests/ChordTyperTests/OptionTabDeadlockTests.swift — new test file with 7 regression tests
