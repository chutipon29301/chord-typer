import XCTest
@testable import ChordTyper
import CoreGraphics

final class ChordEngineTests: XCTestCase {

    private var engine: ChordEngine!
    private var postedEvents: [CGEvent] = []

    override func setUp() {
        super.setUp()
        postedEvents = []
        engine = ChordEngine()
        // Inject hardcoded dictionary per D-14
        engine.chordLookup = { key in
            ["eht": "the", "adn": "and"][key]
        }
        // Inject event poster to capture replay events without real CGEventPost
        engine.eventPoster = { [unowned self] event in
            self.postedEvents.append(event)
        }
    }

    override func tearDown() {
        engine = nil
        postedEvents = []
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeKeyEvent(keycode: UInt16, down: Bool) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: down) else {
            XCTFail("Failed to create CGEvent for keycode \(keycode) down=\(down)")
            // Return a dummy event to keep test flowing (will still fail on assertions)
            return CGEvent(source: nil)!
        }
        return event
    }

    // MARK: - Initial State

    func testChordEngine_initialState_isIdle() {
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Configurable Timing Window

    func testChordEngine_configurableTimingWindow() {
        // Default is 50ms (CHRD-01)
        XCTAssertEqual(engine.timingWindowMs, 50.0)
        // Must accept custom value
        engine.timingWindowMs = 100.0
        XCTAssertEqual(engine.timingWindowMs, 100.0)
    }

    // MARK: - Three Key Chord Detection (CHRD-01, CHRD-03, CHRD-04)

    func testChordEngine_threeKeysReleased_producesChordKey() {
        // T(17) + H(4) + E(14) down then all up
        let t = makeKeyEvent(keycode: 17, down: true)
        let h = makeKeyEvent(keycode: 4,  down: true)
        let e = makeKeyEvent(keycode: 14, down: true)
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
            XCTAssertEqual(key, "eht")
        } else {
            XCTFail("Expected .chord(key: \"eht\"), got \(result)")
        }
    }

    // MARK: - Order Independence (CHRD-03)

    func testChordEngine_differentKeyOrder_sameChordKey() {
        // H+E+T order (different from T+H+E above)
        let h   = makeKeyEvent(keycode: 4,  down: true)
        let e   = makeKeyEvent(keycode: 14, down: true)
        let t   = makeKeyEvent(keycode: 17, down: true)
        let hUp = makeKeyEvent(keycode: 4,  down: false)
        let eUp = makeKeyEvent(keycode: 14, down: false)
        let tUp = makeKeyEvent(keycode: 17, down: false)

        _ = engine.process(event: h,   type: .keyDown)
        _ = engine.process(event: e,   type: .keyDown)
        _ = engine.process(event: t,   type: .keyDown)
        _ = engine.process(event: hUp, type: .keyUp)
        _ = engine.process(event: eUp, type: .keyUp)
        let result = engine.process(event: tUp, type: .keyUp)

        if case .chord(let key, _) = result {
            XCTAssertEqual(key, "eht", "H+E+T and T+H+E must produce the same chord key")
        } else {
            XCTFail("Expected .chord, got \(result)")
        }
    }

    // MARK: - 2-Key Minimum Not Met (CHRD-02)

    func testChordEngine_twoKeysOnly_passesThrough() {
        // Only 2 keys — should NOT produce .chord
        let a   = makeKeyEvent(keycode: 0,  down: true)
        let s   = makeKeyEvent(keycode: 1,  down: true)
        let aUp = makeKeyEvent(keycode: 0,  down: false)
        let sUp = makeKeyEvent(keycode: 1,  down: false)

        _ = engine.process(event: a,   type: .keyDown)
        _ = engine.process(event: s,   type: .keyDown)
        _ = engine.process(event: aUp, type: .keyUp)
        let result = engine.process(event: sUp, type: .keyUp)

        // Must NOT be a .chord — either .suppress (replay path) or .passThrough
        if case .chord = result {
            XCTFail("2 keys should not produce .chord, got \(result)")
        }
    }

    // MARK: - Evaluates on All Keys Released, Not on KeyDown (CHRD-04)

    func testChordEngine_evaluatesOnAllKeysReleased_notOnKeyDown() {
        let t = makeKeyEvent(keycode: 17, down: true)
        let h = makeKeyEvent(keycode: 4,  down: true)
        let e = makeKeyEvent(keycode: 14, down: true)

        let r1 = engine.process(event: t, type: .keyDown)
        let r2 = engine.process(event: h, type: .keyDown)
        let r3 = engine.process(event: e, type: .keyDown)

        // All keyDown results must be .suppress — chord not yet formed
        if case .chord = r1 { XCTFail("keyDown should not produce .chord (r1): \(r1)") }
        if case .chord = r2 { XCTFail("keyDown should not produce .chord (r2): \(r2)") }
        if case .chord = r3 { XCTFail("keyDown should not produce .chord (r3): \(r3)") }
    }

    // MARK: - Unmatched Chord Replays Events (CHRD-05)

    func testChordEngine_unmatchedChord_replaysAllEvents() {
        // X+Y+Z — not in dictionary
        let x   = makeKeyEvent(keycode: 7,  down: true)
        let y   = makeKeyEvent(keycode: 16, down: true)
        let z   = makeKeyEvent(keycode: 6,  down: true)
        let xUp = makeKeyEvent(keycode: 7,  down: false)
        let yUp = makeKeyEvent(keycode: 16, down: false)
        let zUp = makeKeyEvent(keycode: 6,  down: false)

        _ = engine.process(event: x,   type: .keyDown)
        _ = engine.process(event: y,   type: .keyDown)
        _ = engine.process(event: z,   type: .keyDown)
        _ = engine.process(event: xUp, type: .keyUp)
        _ = engine.process(event: yUp, type: .keyUp)
        _ = engine.process(event: zUp, type: .keyUp)

        // All 6 events (3 keyDown + 3 keyUp) should have been replayed
        XCTAssertEqual(postedEvents.count, 6, "All 6 buffered events should be replayed on mismatch")
    }

    func testChordEngine_unmatchedChord_buffersKeyDownAndKeyUp() {
        // Verifies D-10: both keyDown AND keyUp events are buffered and replayed
        let x   = makeKeyEvent(keycode: 7,  down: true)
        let y   = makeKeyEvent(keycode: 16, down: true)
        let z   = makeKeyEvent(keycode: 6,  down: true)
        let xUp = makeKeyEvent(keycode: 7,  down: false)
        let yUp = makeKeyEvent(keycode: 16, down: false)
        let zUp = makeKeyEvent(keycode: 6,  down: false)

        _ = engine.process(event: x,   type: .keyDown)
        _ = engine.process(event: y,   type: .keyDown)
        _ = engine.process(event: z,   type: .keyDown)
        _ = engine.process(event: xUp, type: .keyUp)
        _ = engine.process(event: yUp, type: .keyUp)
        _ = engine.process(event: zUp, type: .keyUp)

        let downCount = postedEvents.filter { $0.type == .keyDown }.count
        let upCount   = postedEvents.filter { $0.type == .keyUp   }.count
        XCTAssertEqual(downCount, 3, "Should replay 3 keyDown events")
        XCTAssertEqual(upCount,   3, "Should replay 3 keyUp events")
    }

    // MARK: - Modifier Key Abort (D-03, D-04)

    func testChordEngine_modifierKeyHeld_abortsChord() {
        // Press A first (no modifier), then Cmd+B — modifier should abort chord
        let a = makeKeyEvent(keycode: 0, down: true)
        _ = engine.process(event: a, type: .keyDown)
        XCTAssertEqual(engine.state, .collecting)

        // Create a keyDown event with Command modifier
        guard let cmdEvent = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) else {
            XCTFail("Failed to create modifier CGEvent")
            return
        }
        cmdEvent.flags = .maskCommand

        let result = engine.process(event: cmdEvent, type: .keyDown)

        // After modifier abort, state should be idle
        XCTAssertEqual(engine.state, .idle)
        // Result should pass through the modifier event itself
        if case .passThrough = result {
            // correct
        } else {
            XCTFail("Modifier keyDown should abort chord and return .passThrough, got \(result)")
        }
    }

    // MARK: - Re-entry Guard (D-11)

    func testChordEngine_isReplayingGuard_preventsReEntry() {
        // When the eventPoster is called (simulating replay), any re-entrant
        // process() call must return .passThrough immediately without queuing.
        var reentrantResult: ChordResult? = nil

        engine.eventPoster = { [unowned self] event in
            // Simulate re-entrant call during replay
            reentrantResult = self.engine.process(event: event, type: event.type)
            self.postedEvents.append(event)
        }

        // Trigger an unmatched chord to invoke replay
        let x   = makeKeyEvent(keycode: 7,  down: true)
        let y   = makeKeyEvent(keycode: 16, down: true)
        let z   = makeKeyEvent(keycode: 6,  down: true)
        let xUp = makeKeyEvent(keycode: 7,  down: false)
        let yUp = makeKeyEvent(keycode: 16, down: false)
        let zUp = makeKeyEvent(keycode: 6,  down: false)

        _ = engine.process(event: x,   type: .keyDown)
        _ = engine.process(event: y,   type: .keyDown)
        _ = engine.process(event: z,   type: .keyDown)
        _ = engine.process(event: xUp, type: .keyUp)
        _ = engine.process(event: yUp, type: .keyUp)
        _ = engine.process(event: zUp, type: .keyUp)

        // Re-entrant call during replay must return .passThrough
        if let result = reentrantResult {
            if case .passThrough = result {
                // correct — re-entry guard worked
            } else {
                XCTFail("Re-entrant process() call should return .passThrough, got \(result)")
            }
        } else {
            XCTFail("eventPoster was not called — replay did not occur")
        }
    }

    // MARK: - Sorted Chord Key Encoding

    func testChordEngine_sortedChordKey_keycodeMapping() {
        // Keycodes 0(a), 11(b), 8(c) should produce "abc"
        let a   = makeKeyEvent(keycode: 0,  down: true)
        let b   = makeKeyEvent(keycode: 11, down: true)
        let c   = makeKeyEvent(keycode: 8,  down: true)
        let aUp = makeKeyEvent(keycode: 0,  down: false)
        let bUp = makeKeyEvent(keycode: 11, down: false)
        let cUp = makeKeyEvent(keycode: 8,  down: false)

        // Inject lookup for "abc"
        engine.chordLookup = { key in
            ["abc": "abc-word"][key]
        }

        _ = engine.process(event: a,   type: .keyDown)
        _ = engine.process(event: b,   type: .keyDown)
        _ = engine.process(event: c,   type: .keyDown)
        _ = engine.process(event: aUp, type: .keyUp)
        _ = engine.process(event: bUp, type: .keyUp)
        let result = engine.process(event: cUp, type: .keyUp)

        if case .chord(let key, _) = result {
            XCTAssertEqual(key, "abc", "Keycodes 0,11,8 should produce sorted key 'abc'")
        } else {
            XCTFail("Expected .chord with key 'abc', got \(result)")
        }
    }
}
