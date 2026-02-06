@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || os(macOS)

private class MockDelegate: TelemetryBufferItemForwardingDelegate {
    var forwardItemsCallCount = 0

    func forwardItems() {
        forwardItemsCallCount += 1
    }
}

final class DefaultTelemetryBufferDataForwardingTriggersTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_registersNotificationObservers() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()

        // -- Act --
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        // -- Assert --
        XCTAssertGreaterThan(notificationCenter.observerCount, 0)
        XCTAssertNotNil(sut)
    }

    // MARK: - willResignActive Tests

    func testWillResignActive_whenDelegateSet_invokesDelegate() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        let delegate = MockDelegate()

        sut.setDelegate(delegate)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(delegate.forwardItemsCallCount, 1)
    }

    func testWillResignActive_whenDelegateNotSet_doesNotCrash() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        // Should not crash when delegate is nil
        XCTAssertNotNil(sut)
    }

    // MARK: - willTerminate Tests

    func testWillTerminate_whenDelegateSet_invokesDelegate() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        let delegate = MockDelegate()

        sut.setDelegate(delegate)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        XCTAssertEqual(delegate.forwardItemsCallCount, 1)
    }

    func testWillTerminate_whenDelegateNotSet_doesNotCrash() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        // Should not crash when delegate is nil
        XCTAssertNotNil(sut)
    }

    // MARK: - Multiple Notifications Tests

    func testMultipleNotifications_invokesDelegateMultipleTimes() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        let delegate = MockDelegate()

        sut.setDelegate(delegate)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(delegate.forwardItemsCallCount, 3)
    }

    // MARK: - Delegate Replacement Tests

    func testSetDelegate_replacesPreviousDelegate() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        let firstDelegate = MockDelegate()
        let secondDelegate = MockDelegate()

        sut.setDelegate(firstDelegate)
        sut.setDelegate(secondDelegate)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(firstDelegate.forwardItemsCallCount, 0)
        XCTAssertEqual(secondDelegate.forwardItemsCallCount, 1)
    }

    // MARK: - Deinit Tests

    func testDeinit_removesObservers() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let delegate = MockDelegate()
        var sut: DefaultTelemetryBufferDataForwardingTriggers? = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        sut?.setDelegate(delegate)

        // -- Act --
        sut = nil
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        XCTAssertEqual(delegate.forwardItemsCallCount, 0)
    }
}
#endif // os(iOS) || os(tvOS) || os(macOS)
