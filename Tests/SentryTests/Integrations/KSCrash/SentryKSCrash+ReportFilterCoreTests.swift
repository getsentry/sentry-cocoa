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

    private final class TestReportProcessor: SentryKSCrash.StoredCrashReportProcessing {
        var onBeforeCaptureGate: (() -> Void)?
        var onCaptureCommitted: (() -> Void)?
        var capturedReportCount = 0

        func process(
            report: [AnyHashable: Any],
            beforeCapture: @escaping () -> (any Error)?
        ) throws {
            onBeforeCaptureGate?()
            if let error = beforeCapture() {
                throw error
            }
            onCaptureCommitted?()
            capturedReportCount += 1
        }
    }

    private var sut: SentryKSCrash.ReportFilterCore!
    private var dispatchQueue: TestSentryDispatchQueueWrapper!
    private var processingSession: SentryKSCrash.ReportProcessingSession!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        dispatchQueue = TestSentryDispatchQueueWrapper()
        processingSession = SentryKSCrash.ReportProcessingSession()
        sut = SentryKSCrash.ReportFilterCore(
            reportProcessor: SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                preserveCrashedSessionOnCaptureFailure: true
            ),
            dispatchQueue: dispatchQueue,
            processingSession: processingSession
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

    func testFilterReports_whenCancelledBeforeQueuedBlockBegins_shouldCompleteRetryOnceAndSkipLateWork() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let report = TestReport(dictionary: try makeCrashReport(durationSinceInitialization: 2.001))
        let client = try getTestClient()
        var completionInvocationCount = 0
        var processedReports: [TestReport]?
        var processingError: Error?
        sut.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            completionInvocationCount += 1
            processedReports = reports
            processingError = error
        }

        // -- Act --
        processingSession.cancel()

        // -- Assert --
        XCTAssertEqual(completionInvocationCount, 1)
        XCTAssertEqual(processedReports?.count, 0)
        XCTAssertEqual(processingError as NSError?, SentryKSCrash.ReportProcessingSession.cancellationError)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)

        // -- Act --
        dispatchQueue.invokeLastDispatchAsync()

        // -- Assert --
        XCTAssertEqual(completionInvocationCount, 1)
        XCTAssertEqual(client.captureFatalEventInvocations.count, 0)
    }

    func testFilterReports_whenCancelledAfterProcessingBeginsBeforeCaptureGate_shouldNotCapture() {
        // -- Arrange --
        let processor = TestReportProcessor()
        let core = SentryKSCrash.ReportFilterCore(
            reportProcessor: processor,
            dispatchQueue: dispatchQueue,
            processingSession: processingSession
        )
        processor.onBeforeCaptureGate = { [processingSession] in
            processingSession?.cancel()
        }
        let report = TestReport(dictionary: [:])
        var completionInvocationCount = 0
        var processedReports: [TestReport]?
        var processingError: Error?

        // -- Act --
        core.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            completionInvocationCount += 1
            processedReports = reports
            processingError = error
        }

        // -- Assert --
        XCTAssertEqual(completionInvocationCount, 1)
        XCTAssertEqual(processedReports?.count, 0)
        XCTAssertEqual(processingError as NSError?, SentryKSCrash.ReportProcessingSession.cancellationError)
        XCTAssertEqual(processor.capturedReportCount, 0)
    }

    func testFilterReports_whenCancelledAfterCaptureCommit_shouldCompleteWithCaptureResult() {
        // -- Arrange --
        let processor = TestReportProcessor()
        let core = SentryKSCrash.ReportFilterCore(
            reportProcessor: processor,
            dispatchQueue: dispatchQueue,
            processingSession: processingSession
        )
        processor.onCaptureCommitted = { [processingSession] in
            processingSession?.cancel()
        }
        let report = TestReport(dictionary: [:])
        var completionInvocationCount = 0
        var processedReports: [TestReport]?
        var processingError: Error?

        // -- Act --
        core.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { reports, error in
            completionInvocationCount += 1
            processedReports = reports
            processingError = error
        }

        // -- Assert --
        XCTAssertEqual(completionInvocationCount, 1)
        XCTAssertIdentical(processedReports?.first, report)
        XCTAssertNil(processingError)
        XCTAssertEqual(processor.capturedReportCount, 1)
    }

    func testFilterReports_whenStartupProcessingIsCancelledAtCaptureGate_shouldFlushAndCompleteRetry() throws {
        // -- Arrange --
        let processor = TestReportProcessor()
        let core = SentryKSCrash.ReportFilterCore(
            reportProcessor: processor,
            dispatchQueue: dispatchQueue,
            processingSession: processingSession
        )
        processor.onBeforeCaptureGate = { [processingSession] in
            processingSession?.cancel()
        }
        let report = TestReport(dictionary: try makeCrashReport(durationSinceInitialization: 1))
        let client = try getTestClient()
        var completionInvocationCount = 0
        var processingError: Error?

        // -- Act --
        core.filterReports(
            [report],
            reportDictionary: { $0.dictionary }
        ) { _, error in
            completionInvocationCount += 1
            processingError = error
        }

        // -- Assert --
        XCTAssertEqual(dispatchQueue.dispatchAsyncCalled, 0)
        XCTAssertEqual(processor.capturedReportCount, 0)
        XCTAssertEqual(client.flushInvocations.count, 1)
        XCTAssertEqual(completionInvocationCount, 1)
        XCTAssertEqual(processingError as NSError?, SentryKSCrash.ReportProcessingSession.cancellationError)
    }

    func testFilterReports_whenOldConversionIsReleasedAfterRestart_shouldNotCaptureThroughNewHub() throws {
        // -- Arrange --
        dispatchQueue.dispatchAsyncExecutesBlock = false
        let oldClient = try getTestClient()
        let oldProcessor = TestReportProcessor()
        let oldCore = SentryKSCrash.ReportFilterCore(
            reportProcessor: oldProcessor,
            dispatchQueue: dispatchQueue,
            processingSession: processingSession
        )
        let conversionStarted = expectation(description: "Old conversion started")
        let releaseConversion = DispatchSemaphore(value: 0)
        let oldWorkerFinished = expectation(description: "Old worker finished")
        oldProcessor.onBeforeCaptureGate = {
            conversionStarted.fulfill()
            releaseConversion.wait()
        }
        let oldReport = TestReport(dictionary: try makeCrashReport(durationSinceInitialization: 2.001))
        var oldCompletionInvocationCount = 0
        var oldProcessingError: Error?
        oldCore.filterReports(
            [oldReport],
            reportDictionary: { $0.dictionary }
        ) { _, error in
            oldCompletionInvocationCount += 1
            oldProcessingError = error
        }
        DispatchQueue.global().async { [dispatchQueue] in
            dispatchQueue?.invokeLastDispatchAsync()
            oldWorkerFinished.fulfill()
        }
        wait(for: [conversionStarted], timeout: 1)

        // -- Act --
        processingSession.cancel()

        let replacementClient = try XCTUnwrap(TestClient(options: makeEnabledOptions()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: replacementClient, andScope: nil))
        let replacementSession = SentryKSCrash.ReportProcessingSession()
        let replacementCore = SentryKSCrash.ReportFilterCore(
            reportProcessor: SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: []),
                preserveCrashedSessionOnCaptureFailure: true
            ),
            dispatchQueue: TestSentryDispatchQueueWrapper(),
            processingSession: replacementSession
        )
        let replacementReport = TestReport(
            dictionary: try makeCrashReport(durationSinceInitialization: 2.001)
        )
        replacementCore.filterReports(
            [replacementReport],
            reportDictionary: { $0.dictionary }
        )
        releaseConversion.signal()
        wait(for: [oldWorkerFinished], timeout: 1)

        // -- Assert --
        XCTAssertEqual(oldCompletionInvocationCount, 1)
        XCTAssertEqual(oldProcessingError as NSError?, SentryKSCrash.ReportProcessingSession.cancellationError)
        XCTAssertEqual(oldProcessor.capturedReportCount, 0)
        XCTAssertEqual(oldClient.captureFatalEventInvocations.count, 0)
        XCTAssertEqual(replacementClient.captureFatalEventInvocations.count, 1)
        XCTAssertFalse(replacementSession.isCancelled)
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

    private func makeEnabledOptions() -> Options {
        let options = Options()
        options.dsn = "https://public@example.com/1"
        return options
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
