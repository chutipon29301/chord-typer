import XCTest
@testable import ChordTyper
import CoreGraphics

/// Tests for ChordEngine safety mechanisms:
/// 1. Replayed event marking — prevents infinite replay loops
/// 2. Kill switch — emergency disable via triple-Escape
/// 3. Circuit breaker — auto-disable on event flood
final class SafetyTests: XCTestCase {

    private var engine: ChordEngine!
    private var postedEvents: [CGEvent] = []

    override func setUp() {
        super.setUp()
        postedEvents = []
        engine = ChordEngine()
        engine.chordLookup = { _ in nil }
        engine.eventPoster = { [unowned self] event in
            self.postedEvents.append(event)
        }
        engine.replayDispatcher = { $0() }
    }

    override func tearDown() {
        engine = nil
        postedEvents = []
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

    // MARK: - 1. Replayed Event Marking

    /// Replayed events must be tagged so they pass through without re-entering chord detection.
    func testReplayedEvents_areMarkedWithUserData() {
        // Type 2 keys (below chord threshold) → triggers replay
        let a   = makeKeyEvent(keycode: 0,  down: true)
        let s   = makeKeyEvent(keycode: 1,  down: true)
        let aUp = makeKeyEvent(keycode: 0,  down: false)
        let sUp = makeKeyEvent(keycode: 1,  down: false)

        _ = engine.process(event: a,   type: .keyDown)
        _ = engine.process(event: s,   type: .keyDown)
        _ = engine.process(event: aUp, type: .keyUp)
        _ = engine.process(event: sUp, type: .keyUp)

        // All replayed events must have the replay marker set
        XCTAssertGreaterThan(postedEvents.count, 0, "Should have replayed events")
        for event in postedEvents {
            XCTAssertEqual(
                event.getIntegerValueField(.eventSourceUserData),
                ChordEngine.replayMarker,
                "Replayed event must have replayMarker in userData"
            )
        }
    }

    /// Events with the replay marker must pass through immediately without processing.
    func testMarkedEvent_passesThrough_withoutProcessing() {
        let event = makeKeyEvent(keycode: 0, down: true)
        event.setIntegerValueField(.eventSourceUserData, value: ChordEngine.replayMarker)

        let result = engine.process(event: event, type: .keyDown)

        if case .passThrough = result {
            // correct
        } else {
            XCTFail("Marked replay event must return .passThrough, got \(result)")
        }
        XCTAssertEqual(engine.state, .idle, "Marked event must not change engine state")
    }

    /// Simulates the real replay loop scenario: events posted by replay should not
    /// re-enter chord collection when fed back through process().
    func testReplayLoop_doesNotOccur() {
        var replayCount = 0

        engine.eventPoster = { [unowned self] event in
            self.postedEvents.append(event)
            replayCount += 1
        }

        // Simulate what happens in production: replay dispatcher posts events,
        // those events come back through the tap callback → process().
        // With marking, they should pass through immediately.
        engine.replayDispatcher = { [unowned self] block in
            block()
            // Simulate re-entry: feed all posted events back through process()
            for event in self.postedEvents {
                let result = self.engine.process(event: event, type: event.type)
                if case .passThrough = result {
                    // correct — marked event passed through
                } else {
                    XCTFail("Re-entered replayed event should passThrough, got \(result)")
                }
            }
        }

        let a   = makeKeyEvent(keycode: 0,  down: true)
        let s   = makeKeyEvent(keycode: 1,  down: true)
        let aUp = makeKeyEvent(keycode: 0,  down: false)
        let sUp = makeKeyEvent(keycode: 1,  down: false)

        _ = engine.process(event: a,   type: .keyDown)
        _ = engine.process(event: s,   type: .keyDown)
        _ = engine.process(event: aUp, type: .keyUp)
        _ = engine.process(event: sUp, type: .keyUp)

        // Replay should happen exactly once (4 events), not loop
        XCTAssertEqual(replayCount, 4, "Replay must happen exactly once per event, not loop")
    }

    /// Abort path also marks replayed events.
    func testAbortReplay_eventsAreMarked() {
        let a = makeKeyEvent(keycode: 0, down: true)
        _ = engine.process(event: a, type: .keyDown)

        let cmdB = makeKeyEvent(keycode: 11, down: true, modifiers: .maskCommand)
        _ = engine.process(event: cmdB, type: .keyDown)

        for event in postedEvents {
            XCTAssertEqual(
                event.getIntegerValueField(.eventSourceUserData),
                ChordEngine.replayMarker,
                "Abort-replayed event must have replayMarker"
            )
        }
    }

    // MARK: - 2. Kill Switch (Triple-Escape)

    /// Three rapid Escape presses should disable chord detection.
    func testKillSwitch_tripleEscape_disablesEngine() {
        let esc1 = makeKeyEvent(keycode: 53, down: true)
        let esc1Up = makeKeyEvent(keycode: 53, down: false)
        let esc2 = makeKeyEvent(keycode: 53, down: true)
        let esc2Up = makeKeyEvent(keycode: 53, down: false)
        let esc3 = makeKeyEvent(keycode: 53, down: true)
        let esc3Up = makeKeyEvent(keycode: 53, down: false)

        _ = engine.process(event: esc1,   type: .keyDown)
        _ = engine.process(event: esc1Up, type: .keyUp)
        _ = engine.process(event: esc2,   type: .keyDown)
        _ = engine.process(event: esc2Up, type: .keyUp)
        _ = engine.process(event: esc3,   type: .keyDown)
        _ = engine.process(event: esc3Up, type: .keyUp)

        XCTAssertTrue(engine.isDisabled, "Triple-Escape must disable the engine")
    }

    /// When disabled, all events pass through without processing.
    func testKillSwitch_whenDisabled_allEventsPassThrough() {
        engine.isDisabled = true

        let a = makeKeyEvent(keycode: 0, down: true)
        let result = engine.process(event: a, type: .keyDown)

        if case .passThrough = result {
            // correct
        } else {
            XCTFail("Disabled engine must return .passThrough, got \(result)")
        }
        XCTAssertEqual(engine.state, .idle, "Disabled engine state must remain .idle")
    }

    /// Single or double Escape should not disable the engine.
    func testKillSwitch_singleEscape_doesNotDisable() {
        let esc = makeKeyEvent(keycode: 53, down: true)
        let escUp = makeKeyEvent(keycode: 53, down: false)

        _ = engine.process(event: esc,   type: .keyDown)
        _ = engine.process(event: escUp, type: .keyUp)

        XCTAssertFalse(engine.isDisabled, "Single Escape must not disable the engine")
    }

    /// Escape presses too far apart should not trigger kill switch.
    func testKillSwitch_slowEscapes_doesNotDisable() {
        engine.killSwitchWindowMs = 100  // very short window for testing

        let esc1 = makeKeyEvent(keycode: 53, down: true)
        let esc1Up = makeKeyEvent(keycode: 53, down: false)

        _ = engine.process(event: esc1,   type: .keyDown)
        _ = engine.process(event: esc1Up, type: .keyUp)

        // Wait longer than the window
        Thread.sleep(forTimeInterval: 0.15)

        let esc2 = makeKeyEvent(keycode: 53, down: true)
        let esc2Up = makeKeyEvent(keycode: 53, down: false)
        let esc3 = makeKeyEvent(keycode: 53, down: true)
        let esc3Up = makeKeyEvent(keycode: 53, down: false)

        _ = engine.process(event: esc2,   type: .keyDown)
        _ = engine.process(event: esc2Up, type: .keyUp)
        _ = engine.process(event: esc3,   type: .keyDown)
        _ = engine.process(event: esc3Up, type: .keyUp)

        XCTAssertFalse(engine.isDisabled, "Spaced-out Escapes must not trigger kill switch")
    }

    /// Re-enabling after kill switch should work.
    func testKillSwitch_reEnable_acceptsEventsAgain() {
        engine.isDisabled = true
        XCTAssertTrue(engine.isDisabled)

        engine.isDisabled = false

        let a = makeKeyEvent(keycode: 0, down: true)
        let result = engine.process(event: a, type: .keyDown)
        if case .suppress = result {
            // correct — collecting again
        } else {
            XCTFail("Re-enabled engine must collect keys, got \(result)")
        }
    }

    // MARK: - 3. Circuit Breaker

    /// Exceeding the event threshold should trip the circuit breaker.
    func testCircuitBreaker_excessiveEvents_disablesEngine() {
        engine.circuitBreakerThreshold = 10
        engine.circuitBreakerWindowMs = 5000

        // Rapidly process more events than the threshold allows
        for i: UInt16 in 0..<12 {
            let keycode = i % 26
            let event = makeKeyEvent(keycode: keycode, down: true)
            _ = engine.process(event: event, type: .keyDown)
            if engine.isDisabled { break }
        }

        XCTAssertTrue(engine.isDisabled, "Circuit breaker must trip after exceeding threshold")
    }

    /// Normal typing volume should not trip the circuit breaker.
    func testCircuitBreaker_normalTyping_doesNotTrip() {
        engine.circuitBreakerThreshold = 50
        engine.circuitBreakerWindowMs = 1000

        // Type 5 key press/release cycles — well under threshold
        for i: UInt16 in 0..<5 {
            let down = makeKeyEvent(keycode: i, down: true)
            let up = makeKeyEvent(keycode: i, down: false)
            _ = engine.process(event: down, type: .keyDown)
            _ = engine.process(event: up,   type: .keyUp)
        }

        XCTAssertFalse(engine.isDisabled, "Normal typing must not trip circuit breaker")
    }

    /// Escape keyDown events should NOT count toward the circuit breaker.
    /// Use 2 Escape presses (below kill switch threshold of 3) with a very low
    /// circuit breaker threshold to verify Escapes are excluded from the count.
    func testCircuitBreaker_escapeKeys_doNotCount() {
        engine.circuitBreakerThreshold = 2
        engine.circuitBreakerWindowMs = 5000

        // 2 Escape press/release cycles — below kill switch threshold (3)
        // but would exceed circuit breaker threshold (2) if Escapes were counted
        for _ in 0..<2 {
            let esc = makeKeyEvent(keycode: 53, down: true)
            let escUp = makeKeyEvent(keycode: 53, down: false)
            _ = engine.process(event: esc,   type: .keyDown)
            _ = engine.process(event: escUp, type: .keyUp)
        }

        XCTAssertFalse(engine.isDisabled, "Escape keys must not count toward circuit breaker")
    }
}
