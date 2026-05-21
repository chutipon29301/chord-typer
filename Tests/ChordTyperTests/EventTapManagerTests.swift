import XCTest
@testable import ChordTyper
import CoreGraphics

final class EventTapManagerTests: XCTestCase {

    private var manager: EventTapManager!

    // Mock state
    private var permissionGranted: Bool = false
    private var tapCreated: Bool = false
    private var tapEnabled: Bool = false
    private var reEnableCalled: Bool = false

    // A real CFMachPort for mock usage
    private var mockPort: CFMachPort!

    override func setUp() {
        super.setUp()
        permissionGranted = false
        tapCreated = false
        tapEnabled = false
        reEnableCalled = false

        // Create a real CFMachPort via CFMachPortCreate (allocates a new Mach port)
        mockPort = CFMachPortCreate(kCFAllocatorDefault, nil, nil, nil)

        manager = EventTapManager()

        // Inject mock closures — bypass real CGEventTap and RunLoop operations
        manager.permissionChecker = { [unowned self] in
            self.permissionGranted
        }
        manager.tapCreator = { [unowned self] _, _ in
            self.tapCreated = true
            return self.permissionGranted ? self.mockPort : nil
        }
        manager.tapEnabler = { [unowned self] _, enabled in
            self.tapEnabled = enabled
            if enabled { self.reEnableCalled = true }
        }
        manager.tapIsEnabledChecker = { [unowned self] _ in
            self.tapEnabled
        }
        // No-op RunLoop operations for tests
        manager.runLoopSourceCreator = { _ in nil }
        manager.runLoopSourceAttacher = { _ in }
        manager.runLoopSourceDetacher = { _ in }
    }

    override func tearDown() {
        manager = nil
        mockPort = nil
        super.tearDown()
    }

    // MARK: - State Machine Tests

    func testEventTapManager_initialState_isStopped() {
        let fresh = EventTapManager()
        XCTAssertEqual(fresh.tapState, .stopped)
    }

    func testEventTapManager_startWithoutPermission_stateIsNoPermission() {
        permissionGranted = false
        manager.start()
        XCTAssertEqual(manager.tapState, .noPermission)
    }

    func testEventTapManager_startWithPermission_stateIsRunning() {
        permissionGranted = true
        manager.start()
        XCTAssertTrue(tapCreated, "tapCreator should have been called")
        XCTAssertEqual(manager.tapState, .running)
    }

    func testEventTapManager_destroyTap_stateIsStopped() {
        // First start to get into running state
        permissionGranted = true
        manager.start()
        XCTAssertEqual(manager.tapState, .running)

        // Now destroy
        manager.destroyTap()
        XCTAssertEqual(manager.tapState, .stopped)
    }

    // MARK: - Event Handling Tests

    func testEventTapManager_timeoutEvent_reEnablesCalled() {
        permissionGranted = true
        manager.start()
        reEnableCalled = false

        // Simulate timeout event — create a minimal event for the call
        guard let event = CGEvent(source: nil) else {
            XCTFail("Failed to create test CGEvent")
            return
        }
        let result = manager.handleEvent(type: .tapDisabledByTimeout, event: event)
        XCTAssertTrue(reEnableCalled, "tapEnabler should be called with true on timeout")
        XCTAssertNil(result, "Timeout pseudo-event should return nil")
    }

    func testEventTapManager_keyDownEvent_passedThrough() {
        permissionGranted = true
        manager.start()

        // No eventHandler set — event should pass through unchanged
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            XCTFail("Failed to create test CGEvent")
            return
        }
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result, "keyDown event should be passed through")
    }

    func testEventTapManager_keyDownEvent_handlerCalled() {
        permissionGranted = true
        manager.start()

        var handlerInvoked = false
        manager.eventHandler = { event in
            handlerInvoked = true
            return event
        }

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            XCTFail("Failed to create test CGEvent")
            return
        }
        let _ = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertTrue(handlerInvoked, "eventHandler closure should be invoked for keyDown")
    }

    // MARK: - Wake Recovery Tests

    func testEventTapManager_wakeRecovery_recreatesTapWhenDisabled() {
        permissionGranted = true
        manager.start()
        XCTAssertEqual(manager.tapState, .running)

        // Simulate tap becoming disabled (e.g., after sleep)
        tapEnabled = false
        tapCreated = false

        manager.verifyAndRecover()

        // Should have recreated the tap
        XCTAssertTrue(tapCreated, "verifyAndRecover should recreate tap when disabled")
    }

    // MARK: - Event Mask Tests

    func testEventTapManager_eventMask_coversKeyDownAndKeyUp() {
        let expectedMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        )
        XCTAssertEqual(EventTapManager.eventMask, expectedMask,
            "Event mask must include both keyDown and keyUp")
    }
}
