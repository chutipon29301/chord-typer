import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "dev.chutipon.chordtyper", category: "AppDelegate")

/// Bridges EventTapManager to the macOS application lifecycle.
/// Owns the EventTapManager instance, presents permission alerts,
/// and observes sleep/wake for tap recovery (D-04).
class AppDelegate: NSObject, NSApplicationDelegate {

    /// EventTapManager instance — owns tap lifecycle (D-01).
    let eventTapManager = EventTapManager()

    /// ChordEngine instance — detects simultaneous keypresses (D-12).
    let chordEngine = ChordEngine()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire ChordEngine into EventTapManager (D-12, D-13)
        eventTapManager.eventHandler = { [weak self] event in
            guard let self else { return event }
            let result = self.chordEngine.process(event: event, type: event.type)
            switch result {
            case .passThrough(let e): return e
            case .suppress:           return nil
            case .chord(_, _):        return nil  // Phase 6 handles text output
            }
        }
        logger.notice("ChordEngine wired into EventTapManager")

        // Set permission denied callback to show alert on main queue (D-05)
        eventTapManager.onPermissionDenied = { [weak self] in
            DispatchQueue.main.async {
                self?.showPermissionAlert()
            }
        }

        // Start the event tap (D-03)
        eventTapManager.start()

        // Register sleep/wake observer (D-10)
        registerSleepWakeObserver()

        logger.notice("Application launched — EventTapManager started")
    }

    // MARK: - Permission Alert

    /// Present an NSAlert guiding the user to grant Accessibility permission (D-05).
    /// After dismissal, starts permission polling regardless of user choice (D-06).
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "ChordTyper needs Accessibility access to intercept keystrokes for chord detection. Please grant permission in System Settings."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
                logger.info("Opened System Settings for Accessibility permission")
            } else {
                logger.error("Failed to create System Settings URL for Accessibility")
            }
        }

        // Start polling regardless of choice (D-06)
        eventTapManager.startPermissionPolling()
        logger.notice("Permission polling started after alert dismissal")
    }

    // MARK: - Sleep/Wake Recovery

    /// Register observer for system wake notifications (D-10).
    /// On wake, verify the tap is still healthy and recover if needed.
    private func registerSleepWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            logger.info("System wake detected — verifying CGEventTap")
            self.eventTapManager.verifyAndRecover()
        }
        logger.info("Sleep/wake observer registered")
    }
}
