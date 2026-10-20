@_spi(Private) import SentryTestUtils
#if canImport(UIKit)
import UIKit
#endif
#if SWIFT_PACKAGE
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

    func testInit_whenCalledOffMainThreadBeforeLaunch_shouldResolveStateAtDidFinishLaunching() throws {
        // -- Arrange --
        // The dependency container is first accessed off the main thread before UIApplication exists, so the main
        // queue block finds no application. In a background launch, didFinishLaunching is then the only
        // notification that can correct the provisional state.
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        dispatchQueueWrapper.blockBeforeMainBlock = { false }
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let applicationAvailable = SentryMutex(false)
        let threadsafeApplication = SentryMutex<SentryThreadsafeApplication?>(nil)
        let initExpectation = expectation(description: "init off the main thread")

        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable.withLock { $0 } ? application : nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: dispatchQueueWrapper)
            threadsafeApplication.withLock { $0 = sut }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 5)
        let sut = try XCTUnwrap(threadsafeApplication.withLock { $0 })
        let refreshState = try XCTUnwrap(dispatchQueueWrapper.blockOnMainInvocations.invocations.last)
        refreshState()
        XCTAssertEqual(.active, sut.applicationState)

        // -- Act --
        applicationAvailable.withLock { $0 = true }
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        // -- Assert --
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)
        XCTAssertFalse(sut.isActive)
    }

    func testInit_whenCalledOffMainThreadAndApplicationBecomesAvailableBeforeMainQueueBlock_shouldResolveStateAndIgnoreLaunch() throws {
        // -- Arrange --
        // UIApplication finishes launching after init registered the launch observer but before the main queue
        // block runs. The notification was posted before the observer existed, so only the main queue re-check
        // can resolve the state, and it must remove the launch observer so a later post cannot overwrite it.
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        dispatchQueueWrapper.blockBeforeMainBlock = { false }
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        let applicationAvailable = SentryMutex(false)
        let threadsafeApplication = SentryMutex<SentryThreadsafeApplication?>(nil)
        let initExpectation = expectation(description: "init off the main thread")

        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable.withLock { $0 } ? application : nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: dispatchQueueWrapper)
            threadsafeApplication.withLock { $0 = sut }
            initExpectation.fulfill()
        }
        wait(for: [initExpectation], timeout: 5)
        let sut = try XCTUnwrap(threadsafeApplication.withLock { $0 })
        XCTAssertEqual(.active, sut.applicationState)
        applicationAvailable.withLock { $0 = true }

        // -- Act --
        let resolveState = try XCTUnwrap(dispatchQueueWrapper.blockOnMainInvocations.invocations.last)
        resolveState()

        // -- Assert --
        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)

        notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertEqual(.active, sut.applicationState)

        application.unsafeApplicationState = .background
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))
        XCTAssertEqual(.active, sut.applicationState, "The launch observer must be removed once the state is resolved")
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

    func testApplicationNilAtInit_shouldAssumeActiveUntilLaunch() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

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
        let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable ? application : nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
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
        let sut = SentryThreadsafeApplication(applicationProvider: { applicationAvailable ? application : nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

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
        let sut = SentryThreadsafeApplication(applicationProvider: { application }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        application.unsafeApplicationState = .background
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        XCTAssertEqual(.inactive, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
    }

    func testApplicationBecomesAvailableBeforeLaunchObserverIsRegistered_shouldResolveState() {
        // UIApplication finished launching after the first availability check but before the
        // didFinishLaunching observer was registered, so the notification is never received.
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let application = TestSentryUIApplication()
        application.unsafeApplicationState = .background
        var providerCalls = 0
        let sut = SentryThreadsafeApplication(applicationProvider: {
            providerCalls += 1
            return providerCalls > 1 ? application : nil
        }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        XCTAssertEqual(.background, sut.applicationState)
        XCTAssertFalse(sut.isApplicationInForeground)

        notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))
        XCTAssertEqual(.active, sut.applicationState)

        application.unsafeApplicationState = .background
        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))
        XCTAssertEqual(.active, sut.applicationState)
    }

    func testApplicationNilAtInitAndAtLaunch_shouldKeepActiveDefault() {
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sut = SentryThreadsafeApplication(applicationProvider: { nil }, notificationCenter: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

        notificationCenterWrapper.post(Notification(name: UIApplication.didFinishLaunchingNotification))

        XCTAssertEqual(.active, sut.applicationState)
        XCTAssertTrue(sut.isApplicationInForeground)
    }
}
#endif
