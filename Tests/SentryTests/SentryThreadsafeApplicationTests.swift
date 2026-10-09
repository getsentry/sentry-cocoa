@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
#if canImport(UIKit)
import UIKit
#endif
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
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
    
    func testInit_whenCalledOffMainThread_shouldDefaultToActiveWithoutReadingApplicationState() throws {
        // -- Arrange --
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let applicationProviderCallCount = SentryMutex(0)
        let threadsafeApplication = SentryMutex<SentryThreadsafeApplication?>(nil)
        let initExpectation = expectation(description: "init off the main thread")

        // -- Act --
        // A `sync` dispatch to a global queue may run inline on the calling thread, so dispatch asynchronously
        // to guarantee the initializer runs off the main thread.
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryThreadsafeApplication(applicationProvider: {
                applicationProviderCallCount.withLock { $0 += 1 }
                return application
            }, notificationCenter: notificationCenterWrapper)
            threadsafeApplication.withLock { $0 = sut }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 5)

        // -- Assert --
        let sut = try XCTUnwrap(threadsafeApplication.withLock { $0 })
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertEqual(0, applicationProviderCallCount.withLock { $0 })
        XCTAssertEqual(0, application.unsafeApplicationStateReadCount)

        // The lifecycle notifications must still correct the defaulted state.
        notificationCenterWrapper.post(Notification(name: UIApplication.didEnterBackgroundNotification))
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)
    }

    func testInit_whenCalledOnMainThread_shouldReadApplicationState() {
        // -- Arrange --
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .inactive

        // -- Act --
        XCTAssertTrue(Thread.isMainThread)
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper)

        // -- Assert --
        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertEqual(1, application.unsafeApplicationStateReadCount)
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
