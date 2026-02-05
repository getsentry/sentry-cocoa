@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || os(macOS)
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

    func testWillResignActive_whenCallbackRegistered_invokesCallback() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        var callbackInvocations = 0

        sut.registerForwardItemsCallback {
            callbackInvocations += 1
        }

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(callbackInvocations, 1)
    }

    func testWillResignActive_whenCallbackNotRegistered_doesNotCrash() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        // Should not crash when callback is nil
        XCTAssertNotNil(sut)
    }

    // MARK: - willTerminate Tests

    func testWillTerminate_whenCallbackRegistered_invokesCallback() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        var callbackInvocations = 0

        sut.registerForwardItemsCallback {
            callbackInvocations += 1
        }

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        XCTAssertEqual(callbackInvocations, 1)
    }

    func testWillTerminate_whenCallbackNotRegistered_doesNotCrash() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        // Should not crash when callback is nil
        XCTAssertNotNil(sut)
    }

    // MARK: - Multiple Notifications Tests

    func testMultipleNotifications_invokesCallbackMultipleTimes() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        var callbackInvocations = 0

        sut.registerForwardItemsCallback {
            callbackInvocations += 1
        }

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertEqual(callbackInvocations, 3)
    }

    // MARK: - Callback Replacement Tests

    func testRegisterCallback_replacePreviousCallback() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        var firstCallbackInvoked = false
        var secondCallbackInvoked = false

        sut.registerForwardItemsCallback {
            firstCallbackInvoked = true
        }

        sut.registerForwardItemsCallback {
            secondCallbackInvoked = true
        }

        // -- Act --
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertFalse(firstCallbackInvoked)
        XCTAssertTrue(secondCallbackInvoked)
    }

    // MARK: - Deinit Tests

    func testDeinit_removesObservers() {
        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        var sut: DefaultTelemetryBufferDataForwardingTriggers? = DefaultTelemetryBufferDataForwardingTriggers(notificationCenter: notificationCenter)
        var callbackInvocations = 0

        sut?.registerForwardItemsCallback {
            callbackInvocations += 1
        }

        // -- Act --
        sut = nil
        notificationCenter.post(Notification(name: CrossPlatformApplication.willResignActiveNotification))
        notificationCenter.post(Notification(name: CrossPlatformApplication.willTerminateNotification))

        // -- Assert --
        XCTAssertEqual(callbackInvocations, 0)
    }
}
#endif // os(iOS) || os(tvOS) || os(macOS)
