@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS)
final class SentryThreadsafeApplicationTests: XCTestCase {
    func testInitialState() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper)
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isActive)
        XCTAssertTrue(sut.isApplicationInForeground)
    }
    
    func testStateAfterAsync() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper)
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)
    }
    
    func testBecomeInactive() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper)
        notificationCenterWrapper.post(Notification(name: UIApplication.didEnterBackgroundNotification))
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)

        notificationCenterWrapper.post(Notification(name: UIApplication.willEnterForegroundNotification))
        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)

        notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertTrue(sut.isApplicationInForeground)
        XCTAssertTrue(sut.isActive)
    }

    func testIsApplicationInForeground_whenApplicationIsInactive_shouldReturnTrue() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .inactive

        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper)

        XCTAssertTrue(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)
    }
}
#endif
