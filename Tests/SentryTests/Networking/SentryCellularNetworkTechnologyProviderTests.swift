#if os(iOS) && !targetEnvironment(macCatalyst)

@_spi(Private) @testable import Sentry
import CoreTelephony
import XCTest

/// Records the queue the provider observes on, which decides whether CoreTelephony is read on the
/// main thread.
private final class SpyNotificationCenter: NotificationCenter, @unchecked Sendable {
    var addObserverQueues = [OperationQueue?]()

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> NSObjectProtocol {
        addObserverQueues.append(queue)
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }
}

final class SentryCellularNetworkTechnologyProviderTests: XCTestCase {

    func testTechnologyForRadioAccessTechnology_whenSecondGenerationTechnology_shouldReturnSecondGeneration() {
        // -- Arrange --
        let radioAccessTechnologies = [
            CTRadioAccessTechnologyGPRS,
            CTRadioAccessTechnologyEdge,
            CTRadioAccessTechnologyCDMA1x
        ]

        for radioAccessTechnology in radioAccessTechnologies {
            // -- Act --
            let technology = SentryCellularNetworkTechnologyProvider.technology(forRadioAccessTechnology: radioAccessTechnology)

            // -- Assert --
            XCTAssertEqual(technology, .secondGeneration, "Unexpected technology for \(radioAccessTechnology)")
        }
    }

    func testTechnologyForRadioAccessTechnology_whenThirdGenerationTechnology_shouldReturnThirdGeneration() {
        // -- Arrange --
        let radioAccessTechnologies = [
            CTRadioAccessTechnologyWCDMA,
            CTRadioAccessTechnologyHSDPA,
            CTRadioAccessTechnologyHSUPA,
            CTRadioAccessTechnologyCDMAEVDORev0,
            CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB,
            CTRadioAccessTechnologyeHRPD
        ]

        for radioAccessTechnology in radioAccessTechnologies {
            // -- Act --
            let technology = SentryCellularNetworkTechnologyProvider.technology(forRadioAccessTechnology: radioAccessTechnology)

            // -- Assert --
            XCTAssertEqual(technology, .thirdGeneration, "Unexpected technology for \(radioAccessTechnology)")
        }
    }

    func testTechnologyForRadioAccessTechnology_whenLTE_shouldReturnFourthGeneration() {
        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(forRadioAccessTechnology: CTRadioAccessTechnologyLTE)

        // -- Assert --
        XCTAssertEqual(technology, .fourthGeneration)
    }

    func testTechnologyForRadioAccessTechnology_whenNewRadio_shouldReturnFifthGeneration() {
        // -- Arrange --
        let radioAccessTechnologies = [
            CTRadioAccessTechnologyNR,
            CTRadioAccessTechnologyNRNSA
        ]

        for radioAccessTechnology in radioAccessTechnologies {
            // -- Act --
            let technology = SentryCellularNetworkTechnologyProvider.technology(forRadioAccessTechnology: radioAccessTechnology)

            // -- Assert --
            XCTAssertEqual(technology, .fifthGeneration, "Unexpected technology for \(radioAccessTechnology)")
        }
    }

    func testTechnologyForRadioAccessTechnology_whenUnknownTechnology_shouldReturnNil() {
        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(forRadioAccessTechnology: "CTRadioAccessTechnology6G")

        // -- Assert --
        XCTAssertNil(technology)
    }

    func testCurrentTechnology_whenNotMonitoring_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryCellularNetworkTechnologyProvider(notificationCenter: NotificationCenter())

        // -- Act & Assert --
        XCTAssertNil(sut.currentTechnology)
    }

    func testStartMonitoring_shouldObserveOnANonMainQueue() throws {
        // -- Arrange --
        let notificationCenter = SpyNotificationCenter()
        let sut = SentryCellularNetworkTechnologyProvider(notificationCenter: notificationCenter)

        // -- Act --
        sut.startMonitoring()
        defer { sut.stopMonitoring() }

        // -- Assert --
        // Radio access technology notifications are posted on whichever thread the system picks,
        // so observing without a queue would read CoreTelephony on the main thread.
        XCTAssertEqual(1, notificationCenter.addObserverQueues.count)
        let queue = try XCTUnwrap(notificationCenter.addObserverQueues.first.flatMap { $0 })
        XCTAssertNotEqual(queue, OperationQueue.main)
        XCTAssertEqual(1, queue.maxConcurrentOperationCount)
        let underlyingQueue = try XCTUnwrap(queue.underlyingQueue)
        XCTAssertNotEqual(underlyingQueue.label, DispatchQueue.main.label)
    }

    func testNotificationQueue_shouldDeliverOffTheMainThread() {
        // -- Arrange --
        let notificationCenter = NotificationCenter()
        let sut = SentryCellularNetworkTechnologyProvider(notificationCenter: notificationCenter)
        sut.startMonitoring()
        defer { sut.stopMonitoring() }

        let handled = expectation(description: "Radio access technology change handled")
        var handledOnMainThread = true
        // Asserts the queue itself delivers off the main thread. That the provider actually uses
        // it is covered by testStartMonitoring_shouldObserveOnANonMainQueue.
        let observerToken = notificationCenter.addObserver(
            forName: .CTServiceRadioAccessTechnologyDidChange,
            object: nil,
            queue: sut.notificationQueue
        ) { _ in
            handledOnMainThread = Thread.isMainThread
            handled.fulfill()
        }
        defer { notificationCenter.removeObserver(observerToken) }

        // -- Act --
        notificationCenter.post(name: .CTServiceRadioAccessTechnologyDidChange, object: nil)

        // -- Assert --
        wait(for: [handled], timeout: 5.0)
        XCTAssertFalse(handledOnMainThread)
    }

    /// The simulator and CI machines have no cellular modem, so we can only assert that starting and
    /// stopping the monitoring doesn't crash and keeps the technology unknown.
    func testStartAndStopMonitoring_whenDeviceHasNoCellularService_shouldNotReportTechnology() {
        // -- Arrange --
        let sut = SentryCellularNetworkTechnologyProvider(notificationCenter: NotificationCenter())

        // -- Act --
        sut.startMonitoring()
        // Starting twice must be a no-op instead of registering a second observer.
        sut.startMonitoring()
        let technologyWhileMonitoring = sut.currentTechnology
        sut.stopMonitoring()

        // -- Assert --
        XCTAssertNil(technologyWhileMonitoring)
        XCTAssertNil(sut.currentTechnology)
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
