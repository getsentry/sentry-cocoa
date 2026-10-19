#if os(iOS) && !targetEnvironment(macCatalyst)

@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
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

    func testTechnologyFromTechnologies_whenDataServiceIsKnown_shouldReportItsTechnology() {
        // -- Arrange --
        let technologies = [
            "sim1": CTRadioAccessTechnologyEdge,
            "sim2": CTRadioAccessTechnologyNR
        ]

        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(
            fromTechnologies: technologies,
            dataServiceIdentifier: "sim2"
        )

        // -- Assert --
        XCTAssertEqual(technology, .fifthGeneration)
    }

    func testTechnologyFromTechnologies_whenDataServiceTechnologyIsUnknown_shouldReturnNil() {
        // -- Arrange --
        // The data service decides on its own. Another SIM can carry a known technology, but it
        // carries no data, so its generation would describe the wrong connection.
        let technologies = [
            "sim1": CTRadioAccessTechnologyLTE,
            "sim2": "SomeTechnologyThisSDKDoesNotKnow"
        ]

        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(
            fromTechnologies: technologies,
            dataServiceIdentifier: "sim2"
        )

        // -- Assert --
        XCTAssertNil(technology)
    }

    func testTechnologyFromTechnologies_whenDataServiceIsUnknown_shouldReportTheFirstKnownTechnology() {
        // -- Arrange --
        let technologies = [
            "sim2": CTRadioAccessTechnologyNR,
            "sim1": CTRadioAccessTechnologyLTE
        ]

        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(
            fromTechnologies: technologies,
            dataServiceIdentifier: nil
        )

        // -- Assert --
        // The identifiers are sorted, so the value is the same on every call.
        XCTAssertEqual(technology, .fourthGeneration)
    }

    func testTechnologyFromTechnologies_whenDataServiceHasNoEntry_shouldReportAnotherService() {
        // -- Arrange --
        let technologies = ["sim1": CTRadioAccessTechnologyLTE]

        // -- Act --
        let technology = SentryCellularNetworkTechnologyProvider.technology(
            fromTechnologies: technologies,
            dataServiceIdentifier: "sim2"
        )

        // -- Assert --
        XCTAssertEqual(technology, .fourthGeneration)
    }

    func testCopyTechnologies_whenTheLockIsHeld_shouldWaitAndCopyTheChangedValue() {
        // -- Arrange --
        let dictionary = NSMutableDictionary(dictionary: ["sim1": CTRadioAccessTechnologyLTE])
        let copyStarted = DispatchSemaphore(value: 0)
        let copied = expectation(description: "Copied the technologies")
        var copy: [String: String]?
        // Stands in for CoreTelephony, which changes the dictionary on its own queue while it
        // holds `@synchronized` on the dictionary.
        objc_sync_enter(dictionary)

        // -- Act --
        DispatchQueue.global().async {
            copyStarted.signal()
            copy = SentryCellularNetworkTechnologyProvider.copyTechnologies(lockingOn: dictionary)
            copied.fulfill()
        }
        copyStarted.wait()
        dictionary["sim1"] = CTRadioAccessTechnologyNR
        objc_sync_exit(dictionary)
        wait(for: [copied], timeout: 5)

        // -- Assert --
        XCTAssertEqual(copy, ["sim1": CTRadioAccessTechnologyNR])
    }

    /// `copyTechnologies(lockingOn:)` is only protected while CoreTelephony returns its internal
    /// dictionary and locks on it. This test fails when a CoreTelephony version stops doing that.
    /// It runs against the CoreTelephony of the simulator, not of a device.
    func testServiceCurrentRadioAccessTechnology_whenTheDictionaryIsLocked_shouldWaitForTheLock() throws {
        // -- Arrange --
        let networkInfo = CTTelephonyNetworkInfo()
        let getter = #selector(getter: CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology)
        let dictionary = try XCTUnwrap(networkInfo.perform(getter)?.takeUnretainedValue() as? NSDictionary)
        let read = DispatchSemaphore(value: 0)

        // -- Act --
        objc_sync_enter(dictionary)
        DispatchQueue.global().async {
            _ = networkInfo.perform(getter)
            read.signal()
        }
        let resultWhileLocked = read.wait(timeout: .now() + 0.5)
        objc_sync_exit(dictionary)
        let resultAfterUnlock = read.wait(timeout: .now() + 5)

        // -- Assert --
        XCTAssertEqual(resultWhileLocked, .timedOut, "CoreTelephony no longer locks on the dictionary it returns.")
        XCTAssertEqual(resultAfterUnlock, .success)
        XCTAssertTrue(
            networkInfo.perform(getter)?.takeUnretainedValue() === dictionary,
            "CoreTelephony no longer returns its internal dictionary."
        )
    }

    func testCopyTechnologies_whenTheDictionaryChangesLater_shouldKeepTheCopiedValue() {
        // -- Arrange --
        let dictionary = NSMutableDictionary(dictionary: ["sim1": CTRadioAccessTechnologyLTE])

        // -- Act --
        let copy = SentryCellularNetworkTechnologyProvider.copyTechnologies(lockingOn: dictionary)
        dictionary["sim1"] = CTRadioAccessTechnologyNR

        // -- Assert --
        XCTAssertEqual(copy, ["sim1": CTRadioAccessTechnologyLTE])
    }

    func testCopyTechnologies_whenValuesAreNotStrings_shouldReturnNil() {
        // -- Arrange --
        let dictionary = NSMutableDictionary(dictionary: ["sim1": NSNumber(value: 4)])

        // -- Act & Assert --
        XCTAssertNil(SentryCellularNetworkTechnologyProvider.copyTechnologies(lockingOn: dictionary))
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
