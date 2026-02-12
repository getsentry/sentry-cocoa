#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

private final class MockHangTracker: SentryHangTracker {
    var removeLateRunLoopObserverInvocations = Invocations<UUID>()
    var removeFinishedRunLoopObserverInvocations = Invocations<UUID>()
    var addLateRunLoopObserverInvocations = Invocations<((UUID, TimeInterval) -> Void)>()
    var addFinishedRunLoopObserverInvocations = Invocations<((RunLoopIteration) -> Void)>()

    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID {
        let id = UUID()
        addLateRunLoopObserverInvocations.record(handler)
        return id
    }

    func removeLateRunLoopObserver(id: UUID) {
        removeLateRunLoopObserverInvocations.record(id)
    }

    func addFinishedRunLoopObserver(handler: @escaping (RunLoopIteration) -> Void) -> UUID {
        let id = UUID()
        addFinishedRunLoopObserverInvocations.record(handler)
        return id
    }

    func removeFinishedRunLoopObserver(id: UUID) {
        removeFinishedRunLoopObserverInvocations.record(id)
    }
}

final class SentryWatchdogTerminationHangTrackerTests: XCTestCase {

    private func createSut(
        mockTracker: MockHangTracker = MockHangTracker(),
        queue: TestSentryDispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    ) throws -> (SentryWatchdogTerminationHangTracker, MockHangTracker, TestSentryDispatchQueueWrapper, SentryFileManager, SentryAppStateManager) {
        let options = Options()
        options.dsn = TestConstants.dsnForTestCase(type: SentryWatchdogTerminationHangTrackerTests.self)
        options.releaseName = TestData.appState.releaseName
        let fileManager = try SentryFileManager(
            options: options,
            dateProvider: TestCurrentDateProvider(),
            dispatchQueueWrapper: queue
        )
        let crashWrapper = TestSentryCrashWrapper(processInfoWrapper: ProcessInfo.processInfo)
        let appStateManager = SentryAppStateManager(
            releaseName: options.releaseName,
            crashWrapper: crashWrapper,
            fileManager: fileManager,
            sysctlWrapper: SentryDependencyContainer.sharedInstance().sysctlWrapper
        )
        appStateManager.start()

        let sut = SentryWatchdogTerminationHangTracker(
            queue: queue,
            hangTracker: mockTracker,
            appStateManager: appStateManager,
            timeoutInterval: 1.0
        )
        return (sut, mockTracker, queue, fileManager, appStateManager)
    }

    /// Waits for Invocations.record to complete (it uses async dispatch).
    private func waitForInvocations(timeout: TimeInterval = 0.1) {
        let expectation = XCTestExpectation(description: "Wait for async record")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    override func tearDown() {
        clearTestState()
        super.tearDown()
    }

    func testStop_whenCalledMultipleTimes_shouldOnlyRemoveObserversOnce() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, _, _) = try createSut(mockTracker: mockTracker, queue: queue)

        sut.start()

        // -- Act --
        sut.stop()
        sut.stop()
        sut.stop()

        // -- Assert --
        // With the fix, callbackId is set to nil after first stop(), so subsequent
        // stop() calls return early without triggering remove. Without the fix,
        // each stop() would call remove with the same (now stale) UUIDs.
        XCTAssertEqual(mockTracker.removeLateRunLoopObserverInvocations.count, 1)
        XCTAssertEqual(mockTracker.removeFinishedRunLoopObserverInvocations.count, 1)
    }

    func testStop_whenNeverStarted_shouldNotCallRemove() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, _, _) = try createSut(mockTracker: mockTracker, queue: queue)

        // -- Act --
        sut.stop()
        sut.stop()

        // -- Assert --
        XCTAssertEqual(mockTracker.removeLateRunLoopObserverInvocations.count, 0)
        XCTAssertEqual(mockTracker.removeFinishedRunLoopObserverInvocations.count, 0)
    }

    func testStart_whenCalled_shouldRegisterBothObservers() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, _, _) = try createSut(mockTracker: mockTracker, queue: queue)

        // -- Act --
        sut.start()
        waitForInvocations()

        // -- Assert --
        XCTAssertEqual(mockTracker.addLateRunLoopObserverInvocations.count, 1)
        XCTAssertEqual(mockTracker.addFinishedRunLoopObserverInvocations.count, 1)
    }

    func testStartStopStartStop_shouldAllowRestart() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, _, _) = try createSut(mockTracker: mockTracker, queue: queue)

        // -- Act --
        sut.start()
        sut.stop()
        sut.start()
        sut.stop()

        // -- Assert --
        XCTAssertEqual(mockTracker.removeLateRunLoopObserverInvocations.count, 2)
        XCTAssertEqual(mockTracker.removeFinishedRunLoopObserverInvocations.count, 2)
    }

    func testHangDetection_whenIntervalExceedsThreshold_shouldCallHangStarted() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, fileManager, appStateManager) = try createSut(mockTracker: mockTracker, queue: queue)
        _ = appStateManager // Keep alive so hangStarted can update app state
        sut.start()
        waitForInvocations()

        let lateHandler = try XCTUnwrap(mockTracker.addLateRunLoopObserverInvocations.last)
        let hangId = UUID()

        // -- Act --
        lateHandler(hangId, 2.0)

        // -- Assert --
        let appState = try XCTUnwrap(fileManager.readAppState())
        XCTAssertTrue(appState.isANROngoing)
    }

    func testHangStopped_whenNoHangActive_shouldNotCallHangStopped() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, fileManager, _) = try createSut(mockTracker: mockTracker, queue: queue)
        sut.start()
        waitForInvocations()

        let finishedHandler = try XCTUnwrap(mockTracker.addFinishedRunLoopObserverInvocations.last)

        // -- Act --
        finishedHandler(RunLoopIteration(startTime: 0, endTime: 0.001))

        // -- Assert --
        let appState = try XCTUnwrap(fileManager.readAppState())
        XCTAssertFalse(appState.isANROngoing)
    }

    func testHangStopped_whenHangWasActive_shouldCallHangStopped() throws {
        // -- Arrange --
        let mockTracker = MockHangTracker()
        let queue = TestSentryDispatchQueueWrapper()
        let (sut, _, _, fileManager, appStateManager) = try createSut(mockTracker: mockTracker, queue: queue)
        _ = appStateManager // Keep alive so hangStarted/hangStopped can update app state
        sut.start()
        waitForInvocations()

        let lateHandler = try XCTUnwrap(mockTracker.addLateRunLoopObserverInvocations.last)
        let finishedHandler = try XCTUnwrap(mockTracker.addFinishedRunLoopObserverInvocations.last)
        let hangId = UUID()

        // -- Act --
        lateHandler(hangId, 2.0)
        let appStateAfterHang = fileManager.readAppState()
        finishedHandler(RunLoopIteration(startTime: 0, endTime: 2.0))
        let appStateAfterFinished = fileManager.readAppState()

        // -- Assert --
        XCTAssertTrue(try XCTUnwrap(appStateAfterHang).isANROngoing)
        XCTAssertFalse(try XCTUnwrap(appStateAfterFinished).isANROngoing)
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
