import XCTest
@testable import ChordTyper
import CoreGraphics

/// Regression tests for the Option+Tab deadlock (bug: option-tab-deadlock).
///
/// Root cause: _abortChord and _replayAndReset called eventPoster synchronously from
/// within the CGEventTap callback. CGEvent.post(tap: .cghidEventTap) is synchronous —
/// it blocks the tap callback waiting for the RunLoop to deliver the re-injected event.
/// The RunLoop cannot deliver the event because it is busy executing the tap callback.
/// This circular wait produces a 10+ second system freeze until the tap times out.
///
/// Fix: eventPoster calls are now scheduled via `replayDispatcher`, which defaults to
/// `DispatchQueue.main.async`. This defers CGEvent.post until AFTER the tap callback
/// returns, breaking the circular wait.
///
/// Test structure:
/// - Section 1: Verify `replayDispatcher` default is async (not inline).
/// - Section 2: Verify Option+Tab correctness with synchronous dispatcher (tests).
/// - Section 3: Verify engine state recovery after abort.
final class OptionTabDeadlockTests: XCTestCase {

    private var engine: ChordEngine!

    override func setUp() {
        super.setUp()
        engine = ChordEngine()
        engine.chordLookup = { _ in nil }
        engine.eventPoster = { _ in }
        // Use synchronous dispatcher by default for tests — overridden in async tests below.
        engine.replayDispatcher = { $0() }
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeKeyEvent(keycode: UInt16, down: Bool, modifiers: CGEventFlags = []) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: down) else {
            XCTFail("Failed to create CGEvent keycode=\(keycode) down=\(down)")
            return CGEvent(source: nil)!
        }
        if !modifiers.isEmpty {
            event.flags = modifiers
        }
        return event
    }

    // MARK: - Section 1: replayDispatcher Default Is Async (Deadlock Fix Verification)

    /// Verifies that the production default `replayDispatcher` is asynchronous
    /// (`DispatchQueue.main.async`), not synchronous (inline). This is the structural
    /// invariant that prevents the Option+Tab deadlock.
    ///
    /// If the default is synchronous, this test fails because the poster is called
    /// before process() returns (while the observation window is open). With the correct
    /// async default, the poster is called AFTER process() returns (on next main RunLoop turn).
    func testReplayDispatcher_productionDefault_isAsync() {
        // Create a fresh engine WITHOUT overriding replayDispatcher — tests the production default.
        let productionEngine = ChordEngine()
        productionEngine.chordLookup = { _ in nil }

        var posterCalledDuringProcess = false
        var processHasReturned = false

        productionEngine.eventPoster = {_ in
            // If this fires BEFORE processHasReturned is set, the dispatcher is sync (BUG).
            if !processHasReturned {
                posterCalledDuringProcess = true
            }
        }

        let tab = makeKeyEvent(keycode: 48, down: true)
        let optionTab = makeKeyEvent(keycode: 48, down: true, modifiers: .maskAlternate)

        // Buffer Tab
        _ = productionEngine.process(event: tab, type: .keyDown)

        // Trigger abort — with async dispatcher, eventPoster fires after this returns
        _ = productionEngine.process(event: optionTab, type: .keyDown)
        processHasReturned = true

        // Pump the main RunLoop briefly to allow the async-dispatched block to execute
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertFalse(posterCalledDuringProcess,
            "DEADLOCK BUG: replayDispatcher default is synchronous. " +
            "eventPoster was called while process() was still on the call stack. " +
            "The default must be DispatchQueue.main.async to prevent CGEvent.post from " +
            "blocking inside the tap callback (option-tab-deadlock).")
    }

    /// Same as above for the _replayAndReset path (unmatched chord).
    func testReplayDispatcher_productionDefault_isAsync_replayPath() {
        let productionEngine = ChordEngine()
        productionEngine.chordLookup = { _ in nil }

        var posterCalledDuringProcess = false
        var lastProcessHasReturned = false

        productionEngine.eventPoster = { _ in
            if !lastProcessHasReturned {
                posterCalledDuringProcess = true
            }
        }

        let x   = makeKeyEvent(keycode: 7,  down: true)
        let y   = makeKeyEvent(keycode: 16, down: true)
        let z   = makeKeyEvent(keycode: 6,  down: true)
        let xUp = makeKeyEvent(keycode: 7,  down: false)
        let yUp = makeKeyEvent(keycode: 16, down: false)
        let zUp = makeKeyEvent(keycode: 6,  down: false)

        _ = productionEngine.process(event: x,   type: .keyDown)
        _ = productionEngine.process(event: y,   type: .keyDown)
        _ = productionEngine.process(event: z,   type: .keyDown)
        _ = productionEngine.process(event: xUp, type: .keyUp)
        _ = productionEngine.process(event: yUp, type: .keyUp)
        _ = productionEngine.process(event: zUp, type: .keyUp)
        lastProcessHasReturned = true

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertFalse(posterCalledDuringProcess,
            "DEADLOCK BUG: replayDispatcher default is synchronous in _replayAndReset path.")
    }

    // MARK: - Section 2: Option+Tab Correctness (synchronous dispatcher for test determinism)

    /// Verifies that an Option+Tab with no buffered keys passes through immediately.
    func testOptionTab_withNoBufferedKeys_passesThroughImmediately() {
        let optionTab = makeKeyEvent(keycode: 48, down: true, modifiers: .maskAlternate)

        let result = engine.process(event: optionTab, type: .keyDown)

        if case .passThrough = result {
            // correct
        } else {
            XCTFail("Option+Tab with no buffered keys must return .passThrough, got \(result)")
        }
        XCTAssertEqual(engine.state, .idle)
    }

    /// Verifies that Option+Tab with a buffered key aborts the chord, flushes the
    /// buffer via eventPoster, and returns .passThrough for the Option+Tab itself.
    func testOptionTab_withBufferedKey_abortsFlushesAndPassesThrough() {
        var flushedCount = 0
        engine.eventPoster = { _ in flushedCount += 1 }

        let tab = makeKeyEvent(keycode: 48, down: true)
        _ = engine.process(event: tab, type: .keyDown)
        XCTAssertEqual(engine.state, .collecting)

        let optionTab = makeKeyEvent(keycode: 48, down: true, modifiers: .maskAlternate)
        let result = engine.process(event: optionTab, type: .keyDown)

        if case .passThrough = result {
            // correct
        } else {
            XCTFail("Option+Tab must abort chord and return .passThrough, got \(result)")
        }
        XCTAssertEqual(engine.state, .idle, "State must be .idle after abort")
        XCTAssertEqual(flushedCount, 1, "One buffered Tab event must be flushed via eventPoster")
    }

    /// Verifies all four modifier types (Cmd, Shift, Option, Ctrl) abort the chord.
    func testModifiers_allFourTypes_abortChord() {
        let modifiers: [(CGEventFlags, String)] = [
            (.maskCommand,   "Command"),
            (.maskShift,     "Shift"),
            (.maskAlternate, "Option"),
            (.maskControl,   "Control")
        ]

        for (modFlag, modName) in modifiers {
            engine = ChordEngine()
            engine.chordLookup = { _ in nil }
            engine.replayDispatcher = { $0() }
            engine.eventPoster = { _ in }

            let a = makeKeyEvent(keycode: 0, down: true)
            _ = engine.process(event: a, type: .keyDown)
            XCTAssertEqual(engine.state, .collecting, "\(modName): should be collecting after 'a'")

            let modEvent = makeKeyEvent(keycode: 0, down: true, modifiers: modFlag)
            let result = engine.process(event: modEvent, type: .keyDown)

            if case .passThrough = result {
                // correct
            } else {
                XCTFail("\(modName): modifier must return .passThrough, got \(result)")
            }
            XCTAssertEqual(engine.state, .idle, "\(modName): must be .idle after abort")
        }
    }

    // MARK: - Section 3: Engine Recovery After Abort

    /// Verifies that after a modifier abort, the engine immediately accepts new events.
    func testOptionTab_afterAbort_engineAcceptsNewEvents() {
        let tab = makeKeyEvent(keycode: 48, down: true)
        _ = engine.process(event: tab, type: .keyDown)

        let optionTab = makeKeyEvent(keycode: 48, down: true, modifiers: .maskAlternate)
        _ = engine.process(event: optionTab, type: .keyDown)

        XCTAssertEqual(engine.state, .idle)

        let a = makeKeyEvent(keycode: 0, down: true)
        let r = engine.process(event: a, type: .keyDown)
        if case .suppress = r {
            // correct
        } else {
            XCTFail("Engine must accept new keyDown after abort, got \(r)")
        }
        XCTAssertEqual(engine.state, .collecting)
    }

    /// Verifies that a full chord cycle works after a prior abort.
    func testOptionTab_afterAbort_chordCycleSucceeds() {
        engine.chordLookup = { key in
            ["eht": "the"][key]
        }

        // First: abort a chord
        let tab = makeKeyEvent(keycode: 48, down: true)
        _ = engine.process(event: tab, type: .keyDown)
        let optionTab = makeKeyEvent(keycode: 48, down: true, modifiers: .maskAlternate)
        _ = engine.process(event: optionTab, type: .keyDown)
        XCTAssertEqual(engine.state, .idle)

        // Then: complete a valid chord
        let t   = makeKeyEvent(keycode: 17, down: true)
        let h   = makeKeyEvent(keycode: 4,  down: true)
        let e   = makeKeyEvent(keycode: 14, down: true)
        let tUp = makeKeyEvent(keycode: 17, down: false)
        let hUp = makeKeyEvent(keycode: 4,  down: false)
        let eUp = makeKeyEvent(keycode: 14, down: false)

        _ = engine.process(event: t,   type: .keyDown)
        _ = engine.process(event: h,   type: .keyDown)
        _ = engine.process(event: e,   type: .keyDown)
        _ = engine.process(event: tUp, type: .keyUp)
        _ = engine.process(event: hUp, type: .keyUp)
        let result = engine.process(event: eUp, type: .keyUp)

        if case .chord(let key, _) = result {
            XCTAssertEqual(key, "eht", "Chord after abort must work correctly")
        } else {
            XCTFail("Expected .chord(key: 'eht') after abort recovery, got \(result)")
        }
    }
}
