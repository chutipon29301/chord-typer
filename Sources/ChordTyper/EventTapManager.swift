import ApplicationServices
import CoreGraphics
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "EventTap")

/// Tap state representing the current lifecycle stage of the event tap.
enum TapState: Equatable {
    case running
    case stopped
    case noPermission
}

/// Manages the CGEventTap lifecycle: creation, permission checks, timeout recovery,
/// sleep/wake recovery, and provides a closure hook for event processing.
///
/// Thread safety: all mutable state is guarded by an internal serial DispatchQueue.
/// Annotated `@unchecked Sendable` because thread safety is manually enforced (D-02).
final class EventTapManager: @unchecked Sendable {

    // MARK: - Public Properties

    /// Closure hook for event processing. Phase 3 leaves nil (pass-through);
    /// Phase 4 assigns chord detection logic (D-13).
    var eventHandler: ((CGEvent) -> CGEvent?)?

    /// Callback invoked on the main queue when permission is denied.
    /// AppDelegate sets this to present the NSAlert.
    var onPermissionDenied: (() -> Void)?

    /// Static event mask covering keyDown and keyUp (D-14).
    static let eventMask: CGEventMask = CGEventMask(
        (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
    )

    // MARK: - Injectable Dependencies (for testability)

    /// Permission checker — checks both Input Monitoring (CGPreflightListenEventAccess)
    /// and Accessibility (AXIsProcessTrusted) since .defaultTap may require either (D-07, Pitfall 1).
    var permissionChecker: () -> Bool = {
        CGPreflightListenEventAccess() || AXIsProcessTrusted()
    }

    /// Tap creator — defaults to real CGEvent.tapCreate call.
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

    /// Tap enabler — defaults to CGEvent.tapEnable (D-09).
    var tapEnabler: (CFMachPort, Bool) -> Void = { tap, enable in
        CGEvent.tapEnable(tap: tap, enable: enable)
    }

    /// Tap enabled checker — defaults to CGEvent.tapIsEnabled.
    var tapIsEnabledChecker: (CFMachPort) -> Bool = { tap in
        CGEvent.tapIsEnabled(tap: tap)
    }

    /// RunLoop source creator — defaults to CFMachPortCreateRunLoopSource.
    var runLoopSourceCreator: (CFMachPort) -> CFRunLoopSource? = { port in
        CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    }

    /// RunLoop source attacher — defaults to CFRunLoopAddSource on main RunLoop.
    var runLoopSourceAttacher: (CFRunLoopSource) -> Void = { source in
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    /// RunLoop source detacher — defaults to CFRunLoopRemoveSource on main RunLoop.
    var runLoopSourceDetacher: (CFRunLoopSource) -> Void = { source in
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }

    // MARK: - Private State

    private let queue = DispatchQueue(
        label: "dev.chutipon.chordtyper.eventtap",
        qos: .userInteractive
    )

    private var _tapState: TapState = .stopped
    private(set) var tapState: TapState {
        get { queue.sync { _tapState } }
        set { queue.sync { _tapState = newValue } }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var selfRetained: Unmanaged<EventTapManager>?

    private var pollTimer: DispatchSourceTimer?
    private var pollCount = 0

    // MARK: - Lifecycle

    /// Start the event tap. Checks permission first; if denied, sets state to
    /// .noPermission and calls onPermissionDenied callback.
    func start() {
        if permissionChecker() {
            createTap()
        } else {
            tapState = .noPermission
            logger.warning("Accessibility permission not granted — entering paused state")
            onPermissionDenied?()
        }
    }

    /// Create the CGEventTap and attach it to the main RunLoop.
    func createTap() {
        let retained = Unmanaged.passRetained(self)
        selfRetained = retained

        guard let tap = tapCreator(EventTapManager.eventMask, retained.toOpaque()) else {
            retained.release()
            selfRetained = nil
            tapState = .noPermission
            logger.error("CGEventTapCreate failed — permission revoked or system error")
            onPermissionDenied?()
            return
        }

        eventTap = tap
        let src = runLoopSourceCreator(tap)
        runLoopSource = src
        if let src {
            runLoopSourceAttacher(src)
        }
        tapEnabler(tap, true)
        tapState = .running
        logger.notice("CGEventTap installed and running")
    }

    /// Disable and remove the tap, release retained self reference.
    func destroyTap() {
        if let tap = eventTap {
            tapEnabler(tap, false)
        }
        if let src = runLoopSource {
            runLoopSourceDetacher(src)
        }
        eventTap = nil
        runLoopSource = nil
        selfRetained?.release()
        selfRetained = nil
        tapState = .stopped
        logger.notice("CGEventTap destroyed")
    }

    /// Handle events from the C callback. Called on the RunLoop thread.
    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                tapEnabler(tap, true)
                logger.warning("CGEventTap re-enabled after timeout/userInput disable")
            }
            return nil

        case .keyDown, .keyUp:
            let result = eventHandler?(event) ?? event
            return Unmanaged.passUnretained(result)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Recovery

    /// Verify the tap is healthy and recover if not (D-10).
    /// Called after system wake or when tap state may be stale.
    func verifyAndRecover() {
        if let tap = eventTap {
            if !tapIsEnabledChecker(tap) {
                logger.warning("Tap disabled — recreating")
                destroyTap()
                start()
            } else {
                logger.info("Tap verified healthy after wake")
            }
        } else {
            logger.info("No tap exists — attempting start")
            start()
        }
    }

    // MARK: - Permission Polling

    /// Start polling for permission grant every 2 seconds (D-06).
    /// Stops after 30 iterations (~60 seconds) or when permission is granted.
    func startPermissionPolling() {
        pollCount = 0
        let timer = DispatchSource.makeTimerSource(queue: queue)
        pollTimer = timer
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.pollCount += 1
            if self.permissionChecker() {
                self.pollTimer?.cancel()
                self.pollTimer = nil
                logger.notice("Permission granted during polling — creating tap")
                DispatchQueue.main.async {
                    self.createTap()
                }
            } else if self.pollCount >= 30 {
                self.pollTimer?.cancel()
                self.pollTimer = nil
                logger.notice("Permission polling timed out after ~60 seconds")
            }
        }
        timer.resume()
    }
}

// MARK: - C Callback

/// File-scope C-compatible callback function with exact CGEventTapCallBack signature.
/// Recovers the EventTapManager instance via Unmanaged pointer bridge.
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
