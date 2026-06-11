@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
final class SentryThreadsafeApplicationTests: XCTestCase {
    func testInitialState() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper)
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isActive)
    }
    
    func testStateAfterAsync() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper)
        XCTAssertEqual(.background, sut.applicationState)
    }
    
    func testBecomeInactive() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper)
        notificationCenterWrapper.post(Notification(name: UIApplication.didEnterBackgroundNotification))
        XCTAssertEqual(.background, sut.applicationState)
    }

    // Regression for #6591: SentrySDK.start emitted a
    // `-[UIApplication applicationState] must be used from main thread only`
    // runtime warning when called from a background thread, because the
    // SentryThreadsafeApplication initializer read unsafeApplicationState
    // directly from the calling thread. The fix dispatches to main; verify
    // that even when init runs off the main thread, the underlying property
    // access lands on main.
    func testInit_OffMainThread_ReadsApplicationStateOnMainThread() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background

        let initialized = expectation(description: "ThreadsafeApplication initialized off main thread")
        var sut: SentryThreadsafeApplication?
        DispatchQueue.global(qos: .userInitiated).async {
            XCTAssertFalse(Thread.isMainThread, "test driver must run init off main")
            sut = SentryThreadsafeApplication(
                applicationProvider: { application },
                notificationCenter: notificationCenterWrapper
            )
            initialized.fulfill()
        }
        wait(for: [initialized], timeout: 1.0)

        XCTAssertEqual(true, application.unsafeApplicationStateReadOnMainThread,
                       "unsafeApplicationState must be read from the main thread")
        XCTAssertEqual(.background, sut?.applicationState,
                       "the value read on main must be propagated to _internalState")
    }
}
#endif
