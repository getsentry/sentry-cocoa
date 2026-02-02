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
}
#endif
