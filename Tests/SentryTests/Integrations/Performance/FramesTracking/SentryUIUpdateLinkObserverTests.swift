@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if (os(iOS) || os(tvOS)) && !targetEnvironment(macCatalyst)
/// The unit tests run without a host app, so there is no window scene to create a `UIUpdateLink`
/// from. These tests only cover how the observer finds scenes. The sample apps cover the rest.
final class SentryUIUpdateLinkObserverTests: XCTestCase {

    private let notificationNames = [
        UIScene.willConnectNotification,
        UIScene.didDisconnectNotification,
        UIWindow.didBecomeVisibleNotification
    ]

    @available(iOS 18.0, tvOS 18.0, *)
    private func makeSut(notificationCenter: TestNSNotificationCenterWrapper) -> SentryUIUpdateLinkObserver {
        SentryUIUpdateLinkObserver(
            notificationCenter: notificationCenter,
            dispatchQueueWrapper: SentryDispatchQueueWrapper(),
            applicationProvider: { TestSentryUIApplication() }
        )
    }

    func testStart_shouldObserveScenesAndWindows() throws {
        guard #available(iOS 18.0, tvOS 18.0, *) else { throw XCTSkip("UIUpdateLink requires iOS 18") }

        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = makeSut(notificationCenter: notificationCenter)

        // -- Act --
        sut.start { _ in }

        // -- Assert --
        let observedNames = notificationCenter.addObserverWithObjectInvocations.invocations.map { $0.name }
        XCTAssertEqual(observedNames, notificationNames)
    }

    func testStart_whenCalledTwice_shouldObserveOnce() throws {
        guard #available(iOS 18.0, tvOS 18.0, *) else { throw XCTSkip("UIUpdateLink requires iOS 18") }

        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = makeSut(notificationCenter: notificationCenter)

        // -- Act --
        sut.start { _ in }
        sut.start { _ in }

        // -- Assert --
        XCTAssertEqual(notificationCenter.observerCount, notificationNames.count)
    }

    func testStop_shouldStopObservingScenesAndWindows() throws {
        guard #available(iOS 18.0, tvOS 18.0, *) else { throw XCTSkip("UIUpdateLink requires iOS 18") }

        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = makeSut(notificationCenter: notificationCenter)
        sut.start { _ in }

        // -- Act --
        sut.stop()

        // -- Assert --
        XCTAssertEqual(notificationCenter.observerCount, 0)
    }

    func testDeinit_shouldStopObservingScenesAndWindows() throws {
        guard #available(iOS 18.0, tvOS 18.0, *) else { throw XCTSkip("UIUpdateLink requires iOS 18") }

        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()

        // -- Act --
        autoreleasepool {
            let sut = makeSut(notificationCenter: notificationCenter)
            sut.start { _ in }
        }

        // -- Assert --
        let removedNames = notificationCenter.removeObserverWithNameAndObjectInvocations.invocations.map { $0.name }
        XCTAssertEqual(removedNames, notificationNames)
    }

    func testSceneNotifications_whenObjectIsNotAWindowScene_shouldNotCallHandler() throws {
        guard #available(iOS 18.0, tvOS 18.0, *) else { throw XCTSkip("UIUpdateLink requires iOS 18") }

        // -- Arrange --
        let notificationCenter = TestNSNotificationCenterWrapper()
        let sut = makeSut(notificationCenter: notificationCenter)
        var handlerCalls = 0
        sut.start { _ in handlerCalls += 1 }

        // -- Act --
        for name in notificationNames {
            notificationCenter.post(Notification(name: name))
        }

        // -- Assert --
        XCTAssertEqual(handlerCalls, 0)
    }

    func testMakeFrameSource_whenOptionEnabled_shouldUseUIUpdateLinkWhenAvailable() {
        // -- Arrange --
        let options = Options()
        options.experimental.enableUIUpdateLinkFramesTracking = true
        let previousOptions = SentryDependencyContainer.sharedInstance().startOptions
        SentryDependencyContainer.sharedInstance().startOptions = options
        defer { SentryDependencyContainer.sharedInstance().startOptions = previousOptions }

        // -- Act --
        let source = SentryDependencyContainer.sharedInstance().makeFrameSource()

        // -- Assert --
        if #available(iOS 18.0, tvOS 18.0, *) {
            XCTAssertTrue(source is SentryUpdateLinkFrameSource)
        } else {
            XCTAssertTrue(source is SentryDisplayLinkFrameSource)
        }
    }

    func testMakeFrameSource_whenOptionDisabled_shouldUseDisplayLink() {
        // -- Arrange --
        let previousOptions = SentryDependencyContainer.sharedInstance().startOptions
        SentryDependencyContainer.sharedInstance().startOptions = Options()
        defer { SentryDependencyContainer.sharedInstance().startOptions = previousOptions }

        // -- Act --
        let source = SentryDependencyContainer.sharedInstance().makeFrameSource()

        // -- Assert --
        XCTAssertTrue(source is SentryDisplayLinkFrameSource)
    }

    func testMakeFrameSource_whenNoStartOptions_shouldUseDisplayLink() {
        // -- Arrange --
        let previousOptions = SentryDependencyContainer.sharedInstance().startOptions
        SentryDependencyContainer.sharedInstance().startOptions = nil
        defer { SentryDependencyContainer.sharedInstance().startOptions = previousOptions }

        // -- Act --
        let source = SentryDependencyContainer.sharedInstance().makeFrameSource()

        // -- Assert --
        XCTAssertTrue(source is SentryDisplayLinkFrameSource)
    }
}
#endif
