#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import Foundation
import XCTest

final class SentryKSCrashReportFilterCoreTests: SentrySDKIntegrationTestsBase {
    private final class TestReport {
        let dictionary: [AnyHashable: Any]?

        init(dictionary: [AnyHashable: Any]?) {
            self.dictionary = dictionary
        }
    }

    private var sut: SentryKSCrash.ReportFilterCore!
    private var dispatchQueue: TestSentryDispatchQueueWrapper!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        dispatchQueue = TestSentryDispatchQueueWrapper()
        sut = SentryKSCrash.ReportFilterCore(
            reportProcessor: SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                currentHubProvider: { SentrySDKInternal.currentHub() },
                preserveCrashedSessionOnCaptureFailure: true
            ),
            dispatchQueue: dispatchQueue
        )
    }

    func testFilterReports_whenReportTypeIsUnsupported_shouldConsumeWithoutCapturing() throws {
        let unsupportedReport = TestReport(dictionary: nil)

        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [unsupportedReport],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 0)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 0)
    }

    func testFilterReports_whenConversionFails_shouldConsumeWithoutCapturing() throws {
        let invalidReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/Crash-faulty-report")
        )

        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [invalidReport],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 0)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 0)
    }

    func testFilterReports_whenMultipleReportsProvided_shouldFailBeforeProcessing() throws {
        let firstReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )
        let secondReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )

        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [firstReport, secondReport],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNotNil(processingError)
        XCTAssertEqual(processedReports?.count, 0)
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 0)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 0)
    }

    func testFilterReports_whenClientIsClearedBeforeAsyncProcessing_shouldReturnRetryableError() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let report = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )
        let client = try getTestClient()
        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))

        // -- Act --
        dispatchQueue.invokeLastDispatchAsync()

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
        XCTAssertEqual(processedReports?.count, 0)
        let error = try XCTUnwrap(processingError as NSError?)
        XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
        XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
    }

    func testFilterReports_whenCrashOccursInSameTimestampSecond_shouldFlushBeforeCompleting() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        var dictionary = try getCrashReport(resource: "Resources/crash-report-1")
        let timestamp = "2026-07-23T16:00:00Z"
        var reportContext = try XCTUnwrap(dictionary["report"] as? [String: Any])
        reportContext["timestamp"] = timestamp
        dictionary["report"] = reportContext
        var systemContext = try XCTUnwrap(dictionary["system"] as? [String: Any])
        systemContext["app_start_time"] = timestamp
        dictionary["system"] = systemContext
        let report = TestReport(dictionary: dictionary)
        let client = try getTestClient()
        var completionCalled = false

        // -- Act --
        sut.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { _, _ in
            completionCalled = true
        }

        // -- Assert --
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 0)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(client.flushInvocations.count, 1)
        XCTAssertTrue(completionCalled)
        XCTAssertTrue(SentrySDK.detectedStartUpCrash)
    }

    func testFilterReports_whenStartupCrash_shouldFlushBeforeCompleting() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let report = TestReport(dictionary: try makeCrashReport(durationSinceInitialization: 2))
        let client = try getTestClient()
        var flushInvocationCountAtCompletion: Int?
        var processedReports: [TestReport]?

        // -- Act --
        sut.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { reports, _ in
            flushInvocationCountAtCompletion = client.flushInvocations.count
            processedReports = reports
        }

        // -- Assert --
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 0)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(client.flushInvocations.count, 1)
        XCTAssertEqual(try XCTUnwrap(client.flushInvocations.first), 5, accuracy: 0.001)
        XCTAssertEqual(flushInvocationCountAtCompletion, 1)
        XCTAssertIdentical(processedReports?.first, report)
        XCTAssertTrue(SentrySDK.detectedStartUpCrash)
    }

    func testFilterReports_whenNotStartupCrash_shouldProcessAsynchronouslyWithoutFlushing() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let report = TestReport(dictionary: try makeCrashReport(durationSinceInitialization: 2.001))
        let client = try getTestClient()
        var completionCalled = false

        // -- Act --
        sut.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { _, _ in
            completionCalled = true
        }

        // -- Assert --
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 1)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
        XCTAssertEqual(client.flushInvocations.count, 0)
        XCTAssertFalse(completionCalled)
        XCTAssertFalse(SentrySDK.detectedStartUpCrash)

        // -- Act --
        dispatchQueue.invokeLastDispatchAsync()

        // -- Assert --
        XCTAssertEqual(client.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(client.flushInvocations.count, 0)
        XCTAssertTrue(completionCalled)
    }

    private func makeCrashReport(durationSinceInitialization: TimeInterval) throws -> [String: Any] {
        var report = try getCrashReport(resource: "Resources/crash-report-1")
        let initializationDate = Date(timeIntervalSince1970: 10_000)

        var reportContext = try XCTUnwrap(report["report"] as? [String: Any])
        reportContext["timestamp"] = sentry_toIso8601String(
            initializationDate.addingTimeInterval(durationSinceInitialization)
        )
        report["report"] = reportContext

        var systemContext = try XCTUnwrap(report["system"] as? [String: Any])
        systemContext["app_start_time"] = sentry_toIso8601String(initializationDate)
        report["system"] = systemContext

        return report
    }

    private func getTestClient() throws -> TestClient {
        try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
    }
}
#endif
