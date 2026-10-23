@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS)
class SentryHingeObserverTests: XCTestCase {

    private var notificationCenterWrapper: TestNSNotificationCenterWrapper!
    private var dispatchQueueWrapper: TestSentryDispatchQueueWrapper!
    private var application: TestSentryUIApplication!

    override func setUp() {
        super.setUp()
        notificationCenterWrapper = TestNSNotificationCenterWrapper()
        dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        application = TestSentryUIApplication()
    }

    private func getSut() -> SentryHingeObserver {
        SentryHingeObserver(
            applicationProvider: { [application] in application },
            notificationCenterWrapper: notificationCenterWrapper,
            dispatchQueueWrapper: dispatchQueueWrapper
        )
    }

    func testCurrentState_whenNoUpdateWasObserved_shouldBeNil() {
        // -- Arrange --
        let sut = getSut()

        // -- Act --
        sut.start { _ in }

        // -- Assert --
        XCTAssertNil(sut.currentState)
    }

    func testStop_whenNotStarted_shouldNotRemoveObservers() {
        // -- Arrange --
        let sut = getSut()
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
    }

    func testHingeStatus_rawValues_shouldMatchUIHingeStatus() {
        XCTAssertEqual(SentryHingeStatus.unknown.rawValue, 0)
        XCTAssertEqual(SentryHingeStatus.closed.rawValue, 1)
        XCTAssertEqual(SentryHingeStatus.partiallyOpen.rawValue, 2)
        XCTAssertEqual(SentryHingeStatus.fullyOpen.rawValue, 3)
    }

    // Same gate as SentryHingeObserver: the iOS 27.1 SDK is the first one shipping UIHingeInteraction.
    #if canImport(SwiftUI, _version: 8.0.85)

    // Hinge updates are only delivered by foldable hardware, so these tests cover the window
    // attachment and the status mapping, which run on every iOS 27.1 device.

    private func skipUnlessHingeIsAvailable() throws {
        guard #available(iOS 27.1, *) else {
            throw XCTSkip("UIHingeInteraction requires iOS 27.1")
        }
    }

    /// UIKit posts `didBecomeKeyNotification` with the window as object to observers that
    /// registered without an object. The notification center double only delivers to observers
    /// registered for the same object, so deliver the notification the way NotificationCenter does.
    private func postDidBecomeKey(for window: UIWindow, to sut: SentryHingeObserver) throws {
        let invocation = try XCTUnwrap(notificationCenterWrapper.addObserverWithObjectInvocations.first)
        _ = sut.perform(invocation.selector, with: Notification(name: UIWindow.didBecomeKeyNotification, object: window))
    }

    private func hingeInteractions(of window: UIWindow) -> [UIInteraction] {
        guard #available(iOS 27.1, *) else {
            return []
        }
        return window.interactions.filter { $0 is UIHingeInteraction }
    }

    func testStart_whenHingeIsAvailable_shouldAttachInteractionToWindows() throws {
        try skipUnlessHingeIsAvailable()

        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        sut.start { _ in }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 1)
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.first?.name, UIWindow.didBecomeKeyNotification)
        XCTAssertEqual(hingeInteractions(of: window).count, 1)
    }

    func testStart_whenCalledTwice_shouldAttachOneInteractionPerWindow() throws {
        try skipUnlessHingeIsAvailable()

        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        sut.start { _ in }
        sut.start { _ in }

        // -- Assert --
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 1)
        XCTAssertEqual(hingeInteractions(of: window).count, 1)
    }

    func testWindowDidBecomeKey_whenStarted_shouldAttachInteractionToNewWindow() throws {
        try skipUnlessHingeIsAvailable()

        // -- Arrange --
        application.windows = []
        let sut = getSut()
        sut.start { _ in }
        let window = UIWindow(frame: .zero)

        // -- Act --
        try postDidBecomeKey(for: window, to: sut)

        // -- Assert --
        XCTAssertEqual(hingeInteractions(of: window).count, 1)
    }

    func testWindowDidBecomeKey_whenStopped_shouldNotAttachInteraction() throws {
        try skipUnlessHingeIsAvailable()

        // -- Arrange --
        application.windows = []
        let sut = getSut()
        sut.start { _ in }
        sut.stop()
        let window = UIWindow(frame: .zero)

        // -- Act --
        try postDidBecomeKey(for: window, to: sut)

        // -- Assert --
        XCTAssertEqual(hingeInteractions(of: window).count, 0)
    }

    func testStop_whenStarted_shouldRemoveInteractionsAndObserver() throws {
        try skipUnlessHingeIsAvailable()

        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()
        sut.start { _ in }
        notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.removeAll()

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertEqual(hingeInteractions(of: window).count, 0)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 1)
        XCTAssertEqual(notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.first?.name, UIWindow.didBecomeKeyNotification)
    }

    func testHingeStatus_whenInitializedFromUIHingeStatus_shouldMapEveryCase() throws {
        guard #available(iOS 27.1, *) else {
            throw XCTSkip("UIHinge.Status requires iOS 27.1")
        }

        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.unknown), .unknown)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.closed), .closed)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.partiallyOpen), .partiallyOpen)
        XCTAssertEqual(SentryHingeStatus(UIHinge.Status.fullyOpen), .fullyOpen)
    }

    #else

    func testStart_whenCompiledWithoutHingeSDK_shouldNotObserveWindows() {
        // -- Arrange --
        let window = UIWindow(frame: .zero)
        application.windows = [window]
        let sut = getSut()

        // -- Act --
        sut.start { _ in XCTFail("Handler must not be called") }

        // -- Assert --
        XCTAssertFalse(SentryHingeObserver.isSupported)
        XCTAssertEqual(notificationCenterWrapper.addObserverWithObjectInvocations.count, 0)
        XCTAssertEqual(dispatchQueueWrapper.blockOnMainInvocations.count, 0)
        // UIKit attaches its own interactions to a window, so only check for the hinge one.
        XCTAssertFalse(window.interactions.contains { NSStringFromClass(type(of: $0)) == "UIHingeInteraction" })
    }

    #endif // canImport(SwiftUI, _version: 8.0.85)
}
#endif // os(iOS)
