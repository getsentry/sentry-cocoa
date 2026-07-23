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
                inAppLogic: SentryInAppLogic(inAppIncludes: [])
            ),
            dispatchQueue: dispatchQueue
        )
    }

    func testFilterReports_whenUnsupportedReportPrecedesValidReport_shouldContinueProcessing() throws {
        let unsupportedReport = TestReport(dictionary: nil)
        let validReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )

        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [unsupportedReport, validReport],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 1)
        XCTAssertIdentical(processedReports?.first, validReport)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 1)
    }

    func testFilterReports_whenReportProcessingFails_shouldContinueProcessingLaterReports() throws {
        let firstValidReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )
        let invalidReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/Crash-faulty-report")
        )
        let secondValidReport = TestReport(
            dictionary: try getCrashReport(resource: "Resources/crash-report-1")
        )

        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [firstValidReport, invalidReport, secondValidReport],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 2)
        XCTAssertIdentical(processedReports?.first, firstValidReport)
        XCTAssertIdentical(processedReports?.last, secondValidReport)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 2)
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
