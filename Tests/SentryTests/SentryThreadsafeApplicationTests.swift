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
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isActive)
        XCTAssertTrue(sut.isApplicationInForeground)
    }
    
    func testStateAfterAsync() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)
    }
    
    func testInit_whenCalledOffMainThread_shouldDefaultToActiveAndRefreshStateOnMainQueue() throws {
        // -- Arrange --
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        // Hold back the main queue block so the provisional state is observable first.
        dispatchQueueWrapper.blockBeforeMainBlock = { false }
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let threadsafeApplication = SentryMutex<SentryThreadsafeApplication?>(nil)
        let initExpectation = expectation(description: "init off the main thread")

        // -- Act --
        // A `sync` dispatch to a global queue may run inline on the calling thread, so dispatch asynchronously
        // to guarantee the initializer runs off the main thread.
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: dispatchQueueWrapper)
            threadsafeApplication.withLock { $0 = sut }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 5)

        // -- Assert --
        let sut = try XCTUnwrap(threadsafeApplication.withLock { $0 })
        XCTAssertEqual(.active, sut.applicationState, "The state must not be read on the calling thread")
        XCTAssertEqual(0, application.unsafeApplicationStateReadCount)
        XCTAssertEqual(1, dispatchQueueWrapper.blockOnMainInvocations.count)

        // Running the main queue block refreshes the provisional state with the real one.
        let refreshState = try XCTUnwrap(dispatchQueueWrapper.blockOnMainInvocations.invocations.last)
        refreshState()
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertEqual(1, application.unsafeApplicationStateReadCount)
        XCTAssertFalse(sut.isApplicationInForeground)
    }

    func testInit_whenCalledOffMainThreadAndApplicationIsNil_shouldKeepActive() throws {
        // -- Arrange --
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let threadsafeApplication = SentryMutex<SentryThreadsafeApplication?>(nil)
        let initExpectation = expectation(description: "init off the main thread")

        // -- Act --
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryThreadsafeApplication(applicationProvider: { nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: dispatchQueueWrapper)
            threadsafeApplication.withLock { $0 = sut }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 5)

        // -- Assert --
        let sut = try XCTUnwrap(threadsafeApplication.withLock { $0 })
        XCTAssertEqual(1, dispatchQueueWrapper.blockOnMainInvocations.count)
        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
    }

    func testInit_whenCalledOnMainThread_shouldReadApplicationStateInline() {
        // -- Arrange --
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .inactive

        // -- Act --
        XCTAssertTrue(Thread.isMainThread)
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: dispatchQueueWrapper)

        // -- Assert --
        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertEqual(1, application.unsafeApplicationStateReadCount)
        XCTAssertEqual(0, dispatchQueueWrapper.blockOnMainInvocations.count)
    }

    func testBecomeInactive() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { TestSentryUIApplication() }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
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

        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        XCTAssertTrue(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)
    }
}
#endif
