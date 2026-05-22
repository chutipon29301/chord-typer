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

// MARK: - ChordEngine (STUB — RED phase)

/// Minimal stub to allow tests to compile.
/// All behavior tests will fail until Task 2 implements the state machine.
///
/// Thread safety: all mutable state is guarded by an internal serial DispatchQueue.
/// `isReplaying` is accessed outside queue.sync to avoid deadlock during replay (Pitfall 1).
/// Annotated `@unchecked Sendable` because thread safety is manually enforced (D-05).
final class ChordEngine: @unchecked Sendable {

    // MARK: - Public Configurable Properties

    /// Timing window in milliseconds (CHRD-01, D-01). Default: 50ms.
    var timingWindowMs: TimeInterval = 50.0

    /// Injectable chord lookup closure (D-14). Defaults to no matches.
    var chordLookup: (String) -> String? = { _ in nil }

    /// Injectable event poster (replaces direct CGEvent.post for testability).
    var eventPoster: (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }

    // MARK: - Private State

    private let queue = DispatchQueue(
        label: "dev.chutipon.chordtyper.chordengine",
        qos: .userInteractive
    )

    private var _state: ChordEngineState = .idle

    /// Re-entry guard — checked BEFORE queue.sync to avoid deadlock (D-11, Pitfall 1).
    private let _isReplayingLock = OSAllocatedUnfairLock<Bool>(initialState: false)

    // MARK: - Public Interface

    /// Current state — readable for testing.
    var state: ChordEngineState {
        queue.sync { _state }
    }

    /// Process a keyboard event. Stub: always passes through.
    func process(event: CGEvent, type: CGEventType) -> ChordResult {
        // Stub implementation — Task 2 replaces this with full state machine
        if _isReplayingLock.withLock({ $0 }) {
            return .passThrough(event)
        }
        return .passThrough(event)
    }
}
