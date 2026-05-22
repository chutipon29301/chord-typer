import ApplicationServices
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "ChordEngine")

// MARK: - ChordEngineState

/// Lifecycle states for the chord detection state machine (D-06).
enum ChordEngineState: Equatable {
    /// No keys held — waiting for first keyDown.
    case idle
    /// One or more keys held within the timing window — collecting chord members.
    case collecting
    /// All keys released — evaluating the collected set against the dictionary.
    case evaluating
}

// MARK: - ChordResult

/// Typed result returned from ChordEngine.process(event:type:).
/// Maps to CGEvent? in EventTapManager.eventHandler (D-13).
enum ChordResult {
    /// Pass this event through unchanged (return it from the tap callback).
    case passThrough(CGEvent)
    /// Suppress this event (return nil from the tap callback).
    case suppress
    /// A chord was recognised. key = sorted-alpha lookup key.
    /// buffered = original events (for Phase 6 context / Phase 5 dict lookup).
    case chord(key: String, buffered: [CGEvent])
}

// MARK: - ChordEngine

/// Detects simultaneous key presses within a configurable timing window,
/// produces order-independent sorted-alphabetical chord keys, and replays
/// buffered events on mismatch.
///
/// Thread safety: all mutable state is guarded by an internal serial DispatchQueue.
/// `_isReplayingLock` uses OSAllocatedUnfairLock and is checked BEFORE queue.sync to
/// avoid deadlock during replay (Pitfall 1 in RESEARCH.md).
/// Annotated `@unchecked Sendable` because thread safety is manually enforced (D-05).
final class ChordEngine: @unchecked Sendable {

    // MARK: - Public Configurable Properties

    /// Timing window in milliseconds. Keys pressed within this window of the
    /// first key are part of the same chord (CHRD-01, D-01). Default: 50ms.
    var timingWindowMs: TimeInterval = 50.0

    /// Injectable chord lookup closure (D-14). Defaults to no matches.
    /// Phase 5 replaces this with DictionaryManager. Tests inject a hardcoded dict.
    var chordLookup: (String) -> String? = { _ in nil }

    /// Injectable event poster (replaces direct CGEvent.post for testability).
    /// Default: posts via CGEvent.post at .cghidEventTap level.
    var eventPoster: (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }

    // MARK: - Private State

    private let queue = DispatchQueue(
        label: "dev.chutipon.chordtyper.chordengine",
        qos: .userInteractive
    )

    /// Current state of the chord state machine (D-06).
    private var _state: ChordEngineState = .idle

    /// Virtual keycodes of currently-held keys, keyed by the keyDown events (D-07).
    private var _heldKeys: Set<UInt16> = []

    /// All CGEvent objects buffered since entering .collecting (D-09, D-10).
    private var _bufferedEvents: [CGEvent] = []

    /// Cancellable timing window work item (D-08). Runs on self.queue (Pitfall 3).
    private var _windowWorkItem: DispatchWorkItem?

    /// Re-entry guard — checked BEFORE queue.sync to avoid deadlock (D-11, Pitfall 1).
    /// OSAllocatedUnfairLock provides atomic access from any thread.
    private let _isReplayingLock = OSAllocatedUnfairLock<Bool>(initialState: false)

    // MARK: - Static Lookup Table

    /// Static US QWERTY keycode-to-character mapping for the 26 letter keys.
    /// IME-independent — uses virtual keycodes, not Unicode string conversion (Pitfall 2).
    private let keycodeToChar: [UInt16: Character] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e",
        3: "f", 5: "g", 4: "h", 34: "i", 38: "j",
        40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
        35: "p", 12: "q", 15: "r", 1: "s", 17: "t",
        32: "u", 9: "v", 13: "w", 7: "x", 16: "y",
        6: "z"
    ]

    // MARK: - Public Interface

    /// Current state — readable for testing.
    var state: ChordEngineState {
        queue.sync { _state }
    }

    /// Process a keyboard event through the chord state machine.
    /// Returns immediately if re-entry guard is set (prevents deadlock during replay).
    func process(event: CGEvent, type: CGEventType) -> ChordResult {
        // Check re-entry flag WITHOUT acquiring queue — avoids deadlock during replay (Pitfall 1)
        if _isReplayingLock.withLock({ $0 }) {
            return .passThrough(event)
        }
        return queue.sync { _process(event: event, type: type) }
    }

    // MARK: - Private State Machine

    private func _process(event: CGEvent, type: CGEventType) -> ChordResult {
        switch type {
        case .keyDown:
            return _handleKeyDown(event: event)
        case .keyUp:
            return _handleKeyUp(event: event)
        default:
            return .passThrough(event)
        }
    }

    private func _handleKeyDown(event: CGEvent) -> ChordResult {
        let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Modifier abort (D-03, D-04): any modifier flag aborts chord and flushes buffer
        let modifierFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        if !event.flags.intersection(modifierFlags).isEmpty {
            return _abortChord(passThrough: event)
        }

        switch _state {
        case .idle:
            // First key — open timing window and start collecting (D-01)
            _heldKeys = [keycode]
            _bufferedEvents = [event]
            _state = .collecting
            _openWindow()
            logger.info("ChordEngine: window opened, collecting key \(keycode)")
            return .suppress

        case .collecting:
            // Add key to chord — window already open
            _heldKeys.insert(keycode)
            _bufferedEvents.append(event)
            let heldCount = _heldKeys.count
            logger.info("ChordEngine: collected key \(keycode), held=\(heldCount)")
            return .suppress

        case .evaluating:
            // Should not receive keyDown while evaluating — treat as pass-through
            return .passThrough(event)
        }
    }

    private func _handleKeyUp(event: CGEvent) -> ChordResult {
        let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        switch _state {
        case .idle:
            // keyUp without collecting — pass through
            return .passThrough(event)

        case .collecting:
            // Buffer the keyUp event (D-10 — replay needs full press/release cycle)
            _bufferedEvents.append(event)
            _heldKeys.remove(keycode)

            if _heldKeys.isEmpty {
                // All keys released — evaluate the chord (CHRD-04)
                _cancelWindow()
                return _evaluate()
            }
            return .suppress

        case .evaluating:
            return .passThrough(event)
        }
    }

    // MARK: - Chord Evaluation

    private func _evaluate() -> ChordResult {
        _state = .evaluating
        let buffered = _bufferedEvents

        // Collect unique keycodes from keyDown events only (D-07)
        var heldKeycodes = Set<UInt16>()
        for ev in buffered {
            if ev.type == .keyDown {
                heldKeycodes.insert(UInt16(ev.getIntegerValueField(.keyboardEventKeycode)))
            }
        }

        // 3-key minimum (CHRD-02)
        guard heldKeycodes.count >= 3 else {
            logger.notice("ChordEngine: < 3 unique keys (\(heldKeycodes.count)), replaying \(buffered.count) events")
            _replayAndReset(buffered)
            return .suppress
        }

        let sortedKey = _sortedChordKey(for: heldKeycodes)

        if let _ = chordLookup(sortedKey) {
            logger.notice("ChordEngine: chord matched '\(sortedKey)'")
            _reset()
            return .chord(key: sortedKey, buffered: buffered)
        } else {
            logger.notice("ChordEngine: no match for '\(sortedKey)', replaying \(buffered.count) events")
            _replayAndReset(buffered)
            return .suppress
        }
    }

    // MARK: - Helpers

    /// Abort chord collection: flush all buffered events as pass-through (D-03).
    private func _abortChord(passThrough event: CGEvent) -> ChordResult {
        let buffered = _bufferedEvents
        _cancelWindow()
        _reset()

        // Post all previously buffered events (if any)
        _isReplayingLock.withLock { $0 = true }
        for ev in buffered {
            eventPoster(ev)
        }
        _isReplayingLock.withLock { $0 = false }

        logger.notice("ChordEngine: modifier detected, chord aborted, flushed \(buffered.count) events")
        return .passThrough(event)
    }

    /// Replay all buffered events via eventPoster and reset state.
    private func _replayAndReset(_ events: [CGEvent]) {
        _reset()
        _isReplayingLock.withLock { $0 = true }
        for event in events {
            eventPoster(event)
        }
        _isReplayingLock.withLock { $0 = false }
    }

    /// Open the timing window (D-08). Must only be called on the serial queue.
    private func _openWindow() {
        let item = DispatchWorkItem { [weak self] in
            // Runs on self.queue — same serial queue (Pitfall 3)
            guard let self = self else { return }
            logger.info("ChordEngine: timing window expired, evaluating")
            _ = self._evaluate()
        }
        _windowWorkItem = item
        queue.asyncAfter(deadline: .now() + timingWindowMs / 1000.0, execute: item)
    }

    /// Cancel the timing window work item (Pitfall 4 — cancel on every state exit).
    private func _cancelWindow() {
        _windowWorkItem?.cancel()
        _windowWorkItem = nil
    }

    /// Reset all mutable state to idle (Pitfall 6).
    private func _reset() {
        _heldKeys = []
        _bufferedEvents = []
        _cancelWindow()
        _state = .idle
    }

    /// Convert a set of virtual keycodes to a sorted-alphabetical chord key (D-07, Pattern 3).
    private func _sortedChordKey(for keycodes: Set<UInt16>) -> String {
        keycodes
            .compactMap { keycodeToChar[$0] }
            .sorted()
            .map(String.init)
            .joined()
    }
}
