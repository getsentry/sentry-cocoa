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

    func testApplicationNilAtInit_shouldAssumeActiveUntilLaunch() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { nil }, notificationCenter: notificationCenterWrapper)

        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isActive)
        XCTAssertTrue(sut.isApplicationInForeground)
    }

    func testApplicationNilAtInit_shouldResolveStateAtDidFinishLaunching() {
        // A background launch: the SDK started before UIApplication existed (SwiftUI App.init), and
        // the system launched the process in the background, so no lifecycle notification follows.
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        var applicationAvailable = false
        let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable ? application : nil }, notificationCenter: notificationCenterWrapper)
        XCTAssertTrue(sut.isApplicationInForeground)

        applicationAvailable = true
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)
    }

    func testApplicationNilAtInit_foregroundLaunch_shouldFollowLifecycleAfterLaunch() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .inactive
        var applicationAvailable = false
        let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable ? application : nil }, notificationCenter: notificationCenterWrapper)

        applicationAvailable = true
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))
        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)

        notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isActive)
    }

    func testApplicationAvailableAtInit_shouldIgnoreDidFinishLaunching() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .inactive
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper)

        application.unsafeApplicationState = .background
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
    }

    func testApplicationNilAtInitAndAtLaunch_shouldKeepActiveDefault() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { nil }, notificationCenter: notificationCenterWrapper)

        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
    }
}
#endif
