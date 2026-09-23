@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

class TestSentryReachabilityObserver: NSObject, SentryReachabilityObserver {
    var connectivityChangedInvocations: UInt = 0
    var onReachabilityChanged: ((Bool, String) -> Void)?
    
    override init() {
        super.init()
        connectivityChangedInvocations = 0
    }
    
    func connectivityChanged(_ connected: Bool, typeDescription: String) {
        print("Received connectivity notification: \(connected); type: \(typeDescription)")
        connectivityChangedInvocations += 1
        onReachabilityChanged?(connected, typeDescription)
    }
}

class TestSentryCellularNetworkTechnologyProvider: SentryCellularNetworkTechnologyProviding {
    var currentTechnology: SentryCellularNetworkTechnology?
    var onStartMonitoring: (() -> Void)?
    var onStopMonitoring: (() -> Void)?

    /// Records starts and stops in one list, so tests can assert their order and not only their count.
    let monitoringInvocations = Invocations<String>()

    var startMonitoringCount: Int {
        monitoringInvocations.invocations.filter { $0 == "start" }.count
    }

    var stopMonitoringCount: Int {
        monitoringInvocations.invocations.filter { $0 == "stop" }.count
    }

    func startMonitoring() {
        monitoringInvocations.record("start")
        onStartMonitoring?()
    }

    func stopMonitoring() {
        monitoringInvocations.record("stop")
        onStopMonitoring?()
    }
}

final class SentryReachabilitySwiftTests: XCTestCase {
    
    private var reachability: SentryReachability!
    
    override func setUp() {
        super.setUp()
        // Ignore the actual reachability callbacks, cause we call the callbacks manually.
        // Otherwise, the actual reachability callbacks are called during later unrelated tests causing
        // flakes.
        reachability = SentryReachability()
        reachability.skipRegisteringActualCallbacks = true
        reachability.setReachabilityIgnoreActualCallback(true)
    }
    
    override func tearDown() {
        reachability.removeAllObservers()
        reachability.setReachabilityIgnoreActualCallback(false)
        reachability = nil
        super.tearDown()
    }
    
    func testConnectivityRepresentations() {
        XCTAssertEqual("none", SentryReachabilityTestHelper.stringForSentryConnectivity(.none))
        XCTAssertEqual("wifi", SentryReachabilityTestHelper.stringForSentryConnectivity(.wiFi))
        XCTAssertEqual("ethernet", SentryReachabilityTestHelper.stringForSentryConnectivity(.ethernet))
        #if canImport(UIKit)
        XCTAssertEqual("cellular", SentryReachabilityTestHelper.stringForSentryConnectivity(.cellular))
        #endif
    }

    func testConnectivityRepresentations_withCellularTechnology_shouldOnlyRefineCellular() {
        // -- Arrange --
        let technologies: [SentryCellularNetworkTechnology: String] = [
            .secondGeneration: "cellular_2g",
            .thirdGeneration: "cellular_3g",
            .fourthGeneration: "cellular_4g",
            .fifthGeneration: "cellular_5g"
        ]

        for (technology, expected) in technologies {
            // -- Act & Assert --
            XCTAssertEqual(expected, SentryReachabilityTestHelper.stringForSentryConnectivity(.cellular, cellularTechnology: technology))
        }

        // A known technology must not leak into the other connectivity types.
        XCTAssertEqual("wifi", SentryReachabilityTestHelper.stringForSentryConnectivity(.wiFi, cellularTechnology: .fifthGeneration))
        XCTAssertEqual("ethernet", SentryReachabilityTestHelper.stringForSentryConnectivity(.ethernet, cellularTechnology: .fifthGeneration))
        XCTAssertEqual("none", SentryReachabilityTestHelper.stringForSentryConnectivity(.none, cellularTechnology: .fifthGeneration))
        XCTAssertEqual("cellular", SentryReachabilityTestHelper.stringForSentryConnectivity(.cellular, cellularTechnology: nil))
    }

    func testConnectivityChanged_whenCellularTechnologyIsKnown_shouldReportItInTypeDescription() throws {
        // -- Arrange --
        let technologyProvider = TestSentryCellularNetworkTechnologyProvider()
        technologyProvider.currentTechnology = .fifthGeneration
        reachability.setCellularNetworkTechnologyProvider(technologyProvider)

        var typeDescriptions = [String]()
        let observer = TestSentryReachabilityObserver()
        observer.onReachabilityChanged = { _, typeDescription in
            typeDescriptions.append(typeDescription)
        }
        reachability.add(observer)

        // -- Act --
        reachability.triggerConnectivityCallback(.cellular)
        technologyProvider.currentTechnology = nil
        reachability.triggerConnectivityCallback(.wiFi)
        reachability.triggerConnectivityCallback(.cellular)

        // -- Assert --
        XCTAssertEqual(["cellular_5g", "wifi", "cellular"], typeDescriptions)
    }

    func testCurrentConnectionType_whenNotMonitoring_shouldBeNil() {
        // -- Act & Assert --
        XCTAssertNil(reachability.currentConnectionType)
    }

    func testCurrentConnectionType_whenCellularTechnologyIsKnown_shouldIncludeIt() {
        // -- Arrange --
        let technologyProvider = TestSentryCellularNetworkTechnologyProvider()
        technologyProvider.currentTechnology = .fourthGeneration
        reachability.setCellularNetworkTechnologyProvider(technologyProvider)
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)

        // -- Act --
        reachability.triggerConnectivityCallback(.cellular)

        // -- Assert --
        XCTAssertEqual("cellular_4g", reachability.currentConnectionType)
        XCTAssertEqual(1, observer.connectivityChangedInvocations)
    }

    func testCurrentConnectionType_whenAllObserversAreRemoved_shouldBeNil() {
        // -- Arrange --
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)
        reachability.triggerConnectivityCallback(.wiFi)
        let connectionTypeWhileMonitoring = reachability.currentConnectionType

        // -- Act --
        reachability.remove(observer)

        // -- Assert --
        XCTAssertEqual("wifi", connectionTypeWhileMonitoring)
        XCTAssertNil(reachability.currentConnectionType)
    }

    func testAdd_whenFirstObserverIsAdded_shouldMonitorCellularNetworkTechnology() {
        // -- Arrange --
        reachability.skipRegisteringActualCallbacks = false
        let technologyProvider = TestSentryCellularNetworkTechnologyProvider()
        reachability.setCellularNetworkTechnologyProvider(technologyProvider)
        let startedMonitoring = expectation(description: "Started monitoring the cellular network technology")
        technologyProvider.onStartMonitoring = { startedMonitoring.fulfill() }
        let stoppedMonitoring = expectation(description: "Stopped monitoring the cellular network technology")
        stoppedMonitoring.assertForOverFulfill = false
        technologyProvider.onStopMonitoring = { stoppedMonitoring.fulfill() }
        let observer = TestSentryReachabilityObserver()

        // -- Act --
        reachability.add(observer)
        wait(for: [startedMonitoring], timeout: 1.0)
        reachability.remove(observer)
        wait(for: [stoppedMonitoring], timeout: 1.0)

        // -- Assert --
        XCTAssertEqual(["start", "stop"], technologyProvider.monitoringInvocations.invocations)
    }

    /// Starting the monitoring is queued on the reachability queue, so removing the last observer
    /// right after adding it must not leave the monitoring running.
    func testRemove_whenLastObserverIsRemovedBeforeMonitoringStarted_shouldStopMonitoring() {
        // -- Arrange --
        reachability.skipRegisteringActualCallbacks = false
        let technologyProvider = TestSentryCellularNetworkTechnologyProvider()
        reachability.setCellularNetworkTechnologyProvider(technologyProvider)
        let stoppedMonitoring = expectation(description: "Stopped monitoring the cellular network technology")
        stoppedMonitoring.assertForOverFulfill = false
        technologyProvider.onStopMonitoring = { stoppedMonitoring.fulfill() }
        let observer = TestSentryReachabilityObserver()

        // -- Act --
        // Removing without waiting for the queued start to run.
        reachability.add(observer)
        reachability.remove(observer)
        wait(for: [stoppedMonitoring], timeout: 1.0)

        // -- Assert --
        XCTAssertEqual(1, technologyProvider.startMonitoringCount)
        XCTAssertEqual(1, technologyProvider.stopMonitoringCount)
        XCTAssertEqual("stop", technologyProvider.monitoringInvocations.last)
    }
    
    func testMultipleReachabilityObservers() {
        print("[Sentry] [TEST] creating observer A")
        let observerA = TestSentryReachabilityObserver()
        print("[Sentry] [TEST] adding observer A as reachability observer")
        reachability.add(observerA)
        
        print("[Sentry] [TEST] throwaway reachability callback, setting to reachable")
        reachability.triggerConnectivityCallback(.wiFi) // ignored, as it's the first callback
        print("[Sentry] [TEST] reachability callback set to unreachable")
        reachability.triggerConnectivityCallback(.none)
        
        print("[Sentry] [TEST] creating observer B")
        let observerB = TestSentryReachabilityObserver()
        print("[Sentry] [TEST] adding observer B as reachability observer")
        reachability.add(observerB)
        
        print("[Sentry] [TEST] reachability callback set back to reachable")
        reachability.triggerConnectivityCallback(.wiFi)
        print("[Sentry] [TEST] reachability callback set back to unreachable")
        reachability.triggerConnectivityCallback(.none)
        
        print("[Sentry] [TEST] removing observer B as reachability observer")
        reachability.remove(observerB)
        
        print("[Sentry] [TEST] reachability callback set back to reachable")
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(5, observerA.connectivityChangedInvocations)
        XCTAssertEqual(2, observerB.connectivityChangedInvocations)
        
        print("[Sentry] [TEST] removing observer A as reachability observer")
        reachability.remove(observerA)
    }
    
    func testNoObservers() {
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)
        reachability.remove(observer)
        
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(0, observer.connectivityChangedInvocations)
        
        reachability.removeAllObservers()
    }
    
    func testReportSameObserver_OnlyCalledOnce() {
        let observer = TestSentryReachabilityObserver()
        reachability.add(observer)
        reachability.add(observer)
        
        reachability.triggerConnectivityCallback(.wiFi)
        
        XCTAssertEqual(1, observer.connectivityChangedInvocations)
        
        reachability.remove(observer)
    }
    
    /// We only want to make sure running the actual registering and unregistering callbacks doesn't crash.
    func testRegisteringActualCallbacks() {
        reachability.skipRegisteringActualCallbacks = false
        
        let observer = TestSentryReachabilityObserver()
        
        reachability.add(observer)
        reachability.remove(observer)
    }
    
    func testAddRemoveFromMultipleThreads() throws {
        let sut = SentryReachability()
        // With this test, we want to test if the adding and removing
        // observers are adequately synchronized.
        sut.skipRegisteringActualCallbacks = true
        testConcurrentModifications(writeWork: { _ in
            sut.add(TestSentryReachabilityObserver())
        }, readWork: {
            sut.removeAllObservers()
        })
    }

    func testRemove_WhenLastObserverIsRemoved_ShouldInvalidatePathMonitor() throws {
        // -- Arrange --
        reachability.skipRegisteringActualCallbacks = false
        let observer = TestSentryReachabilityObserver()

        // -- Act --
        reachability.add(observer)
        let pathMonitor = try XCTUnwrap(reachability.currentPathMonitor)
        let isCurrentBeforeRemovingObserver = reachability.isCurrentPathMonitor(pathMonitor)
        reachability.remove(observer)

        // -- Assert --
        XCTAssertTrue(isCurrentBeforeRemovingObserver)
        XCTAssertFalse(reachability.isCurrentPathMonitor(pathMonitor))
    }

    func testAddingAndRemovingObserversCleanTheMonitor() {
        reachability.skipRegisteringActualCallbacks = false
        reachability.setReachabilityIgnoreActualCallback(false)
        let observer = TestSentryReachabilityObserver()
        
        // Ensure starting scenario
        XCTAssertTrue(reachability.pathMonitorIsNil)
        
        // Do
        reachability.add(observer)
        
        // Verify
        // Monitor should not be nil when at least one observer is added
        XCTAssertFalse(reachability.pathMonitorIsNil)
        
        // Do again
        sleep(1)
        reachability.remove(observer)
        
        // Verify
        // Ensure when all observers are removed, the monitor is set to nil
        XCTAssertTrue(reachability.pathMonitorIsNil)
    }

    func testConnectivityCallbackAndRemoveAllObservers_NoDeadlock() {
        // This test reproduces the deadlock scenario where:
        // - Thread 1 holds instanceLock and calls removeAllObservers() (which needs observersLock)
        // - Thread 2 is in connectivityCallback() notifying observers
        // - Observer tries to access SentryDependencyContainer which needs instanceLock
        // The fix ensures observers are notified outside the observersLock

        let instanceLock = NSRecursiveLock() // Simulates SentryDependencyContainer.instanceLock

        let observerCallbackExpectation = expectation(description: "Observer callback completes")
        observerCallbackExpectation.expectedFulfillmentCount = 2
        let removeObserversExpectation = expectation(description: "removeAllObservers completes")
        let callbackStartedSemaphore = DispatchSemaphore(value: 0)

        let observer = TestSentryReachabilityObserver()
        observer.onReachabilityChanged = { _, _ in
            callbackStartedSemaphore.signal()

            // Wait a bit to ensure Thread 1 is trying to acquire observersLock
            Thread.sleep(forTimeInterval: 1.00)

            // This mimics SentryBreadcrumbTracker calling SentryDependencyContainer.sharedInstance()
            instanceLock.lock()
            instanceLock.unlock()

            observerCallbackExpectation.fulfill()
        }

        reachability.add(observer)
        reachability.triggerConnectivityCallback(.wiFi) // Initial state

        // Thread 1: Hold instanceLock and call removeAllObservers()
        // This simulates SentryDependencyContainer.reset() which holds instanceLock
        DispatchQueue.global().async {
            instanceLock.lock()

            // Wait for callback to start
            _ = callbackStartedSemaphore.wait(timeout: .now() + 1.0)

            // Give callback time to progress
            Thread.sleep(forTimeInterval: 1.00)

            // Now try to call removeAllObservers() while holding instanceLock
            // This will try to acquire observersLock - DEADLOCK if callback holds it while calling observer
            self.reachability.removeAllObservers()

            instanceLock.unlock()
            removeObserversExpectation.fulfill()
        }

        // Thread 2: Trigger connectivity callback
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.005) {
            self.reachability.triggerConnectivityCallback(.none)
        }

        // If there's a deadlock, this will timeout
        wait(for: [observerCallbackExpectation, removeObserversExpectation], timeout: 10.0)
    }
}
