#if os(iOS) && !targetEnvironment(macCatalyst)

@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import CoreTelephony
import XCTest

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
            let technology = SentryCellularNetworkTechnology(radioAccessTechnology: radioAccessTechnology)

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
            let technology = SentryCellularNetworkTechnology(radioAccessTechnology: radioAccessTechnology)

            // -- Assert --
            XCTAssertEqual(technology, .thirdGeneration, "Unexpected technology for \(radioAccessTechnology)")
        }
    }

    func testTechnologyForRadioAccessTechnology_whenLTE_shouldReturnFourthGeneration() {
        // -- Act --
        let technology = SentryCellularNetworkTechnology(radioAccessTechnology: CTRadioAccessTechnologyLTE)

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
            let technology = SentryCellularNetworkTechnology(radioAccessTechnology: radioAccessTechnology)

            // -- Assert --
            XCTAssertEqual(technology, .fifthGeneration, "Unexpected technology for \(radioAccessTechnology)")
        }
    }

    func testTechnologyForRadioAccessTechnology_whenUnknownTechnology_shouldReturnNil() {
        // -- Act --
        let technology = SentryCellularNetworkTechnology(radioAccessTechnology: "CTRadioAccessTechnology6G")

        // -- Assert --
        XCTAssertNil(technology)
    }

    func testCurrentTechnology_whenNotMonitoring_shouldReturnNil() {
        // -- Arrange --
        let sut = SentryCellularNetworkTechnologyProvider(notificationCenter: NotificationCenter())

        // -- Act & Assert --
        XCTAssertNil(sut.currentTechnology)
    }

    func testRadioAccessTechnologyChanged_shouldBeHandledOffThePostingThread() throws {
        // -- Arrange --
        // The notification arrives on whichever thread posts it, so reading CoreTelephony has to
        // be moved to the provider's own queue instead of running there.
        let notificationCenter = NotificationCenter()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryCellularNetworkTechnologyProvider(
            notificationCenter: notificationCenter,
            dispatchQueue: dispatchQueue
        )
        sut.startMonitoring()
        defer { sut.stopMonitoring() }
        let dispatchesBefore = dispatchQueue.dispatchAsyncInvocations.count

        // -- Act --
        notificationCenter.post(name: .CTServiceRadioAccessTechnologyDidChange, object: nil)

        // -- Assert --
        XCTAssertEqual(dispatchesBefore + 1, dispatchQueue.dispatchAsyncInvocations.count)
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
