@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS)
import UIKit

final class SentryAppStateManagerTests: XCTestCase {
    private static let dsnAsString = TestConstants.dsnForTestCase(type: SentryAppStateManagerTests.self)

    private final class MockDependencies: SentryAppStateManager.Dependencies {
        let debuggerStatusProvider: SentryDebuggerStatusProvider
        let fileManager: SentryFileManager?
        let sysctlWrapper: SentrySysctl
        let dispatchQueueWrapper: SentryDispatchQueueWrapper
        let notificationCenterWrapper: SentryNSNotificationCenterWrapper

        init(
            debuggerStatusProvider: SentryDebuggerStatusProvider,
            fileManager: SentryFileManager,
            sysctlWrapper: SentrySysctl,
            dispatchQueueWrapper: SentryDispatchQueueWrapper,
            notificationCenterWrapper: SentryNSNotificationCenterWrapper
        ) {
            self.debuggerStatusProvider = debuggerStatusProvider
            self.fileManager = fileManager
            self.sysctlWrapper = sysctlWrapper
            self.dispatchQueueWrapper = dispatchQueueWrapper
            self.notificationCenterWrapper = notificationCenterWrapper
        }
    }

    private class Fixture {

        let options: Options
        let fileManager: SentryFileManager
        let currentDate = TestCurrentDateProvider()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()
        let sysctl = TestSysctl()
        let dependencies: MockDependencies

        init() throws {
            options = Options()
            options.dsn = SentryAppStateManagerTests.dsnAsString
            options.releaseName = TestData.appState.releaseName
            
            fileManager = try XCTUnwrap(SentryFileManager(
                options: options,
                dateProvider: currentDate,
                dispatchQueueWrapper: dispatchQueue
            ))
            dependencies = MockDependencies(
                debuggerStatusProvider: sysctl,
                fileManager: fileManager,
                sysctlWrapper: sysctl,
                dispatchQueueWrapper: dispatchQueue,
                notificationCenterWrapper: notificationCenterWrapper
            )
        }

        func getSut() -> SentryAppStateManager {
            SentryAppStateManager(releaseName: options.releaseName, dependencies: dependencies)
        }
    }

    private var fixture: Fixture!
    private var sut: SentryAppStateManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        fixture = try Fixture()
        sut = fixture.getSut()
    }

    override func tearDown() {
        super.tearDown()
        sut.stop(withForce: true)
        fixture.fileManager.deleteAppState()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }

    func testStartStoresAppState() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())
    }

    func testBuildCurrentAppState_whenDebuggerAttached_shouldMarkStateAsDebugging() {
        fixture.sysctl.internalIsBeingTraced = true

        let appState = sut.buildCurrentAppState()

        XCTAssertTrue(appState.isDebugging)
    }

    func testStartOnlyRunsLogicWhenStartCountBecomesOne() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())

        fixture.fileManager.deleteAppState()

        sut.start()
        XCTAssertNil(fixture.fileManager.readAppState())
    }

    func testStopDoesNotDeleteAppState() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        XCTAssertNotNil(fixture.fileManager.readAppState())

        sut.stop()
        XCTAssertNotNil(fixture.fileManager.readAppState())
    }

    func testStopUpdatesAppState() {
        sut.start()

        let stateBeforeStop = fixture.fileManager.readAppState()
        XCTAssertTrue(stateBeforeStop!.isSDKRunning)

        sut.stop(withForce: true)

        let stateAfterStop = fixture.fileManager.readAppState()
        XCTAssertFalse(stateAfterStop!.isSDKRunning)
    }

    func testDidBecomeActiveUpdatesAppState() {
        // -- Arrange --
        sut.start()

        // -- Act --
        fixture.notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))

        // -- Assert --
        XCTAssertTrue(fixture.fileManager.readAppState()!.isActive)
    }

    func testWillResignActiveUpdatesAppState() {
        // -- Arrange --
        sut.start()
        fixture.notificationCenterWrapper.post(Notification(name: UIApplication.didBecomeActiveNotification))

        // -- Act --
        fixture.notificationCenterWrapper.post(Notification(name: UIApplication.willResignActiveNotification))

        // -- Assert --
        XCTAssertFalse(fixture.fileManager.readAppState()!.isActive)
    }

    func testWillTerminateUpdatesAppState() {
        // -- Arrange --
        sut.start()

        // -- Act --
        fixture.notificationCenterWrapper.post(Notification(name: UIApplication.willTerminateNotification))

        // -- Assert --
        XCTAssertTrue(fixture.fileManager.readAppState()!.wasTerminated)
    }

    func testForcedStop() {
        XCTAssertNil(fixture.fileManager.readAppState())

        sut.start()
        sut.start()
        sut.start()

        sut.stop()
        XCTAssertEqual(sut.startCount, 2)

        sut.stop(withForce: true)
        XCTAssertEqual(sut.startCount, 0)

        XCTAssertEqual(fixture.notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 4)
    }

    func testUpdateAppState() {
        sut.storeCurrentAppState()

        XCTAssertFalse(fixture.fileManager.readAppState()!.wasTerminated)

        sut.updateAppState { state in
            state.wasTerminated = true
        }

        XCTAssertEqual(fixture.fileManager.readAppState()!.wasTerminated, true)
    }
}
#endif
