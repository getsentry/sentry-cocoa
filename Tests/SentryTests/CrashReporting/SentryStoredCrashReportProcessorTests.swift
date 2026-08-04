@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import Foundation
import XCTest

final class SentryStoredCrashReportProcessorTests: SentrySDKIntegrationTestsBase {
    private final class ClientClearedDuringCapture: TestClient {
        var captureFatalEventInvocationCount = 0

        public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
            clearClientWithoutCapturing()
        }

        public override func captureFatalEvent(
            _ event: Event,
            with session: SentrySession,
            with scope: Scope
        ) -> SentryId {
            clearClientWithoutCapturing()
        }

        private func clearClientWithoutCapturing() -> SentryId {
            captureFatalEventInvocationCount += 1
            SentrySDKInternal.currentHub().bindClient(nil)
            return SentryId.empty
        }
    }

    private final class ClientClosedDuringCapture: TestClient {
        public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
            closeWithoutCapturing()
        }

        public override func captureFatalEvent(
            _ event: Event,
            with session: SentrySession,
            with scope: Scope
        ) -> SentryId {
            closeWithoutCapturing()
        }

        private func closeWithoutCapturing() -> SentryId {
            close()
            return SentryId.empty
        }
    }

    private final class EmptyCaptureClient: TestClient {
        public override func captureFatalEvent(_ event: Event, with scope: Scope) -> SentryId {
            SentryId.empty
        }

        public override func captureFatalEvent(
            _ event: Event,
            with session: SentrySession,
            with scope: Scope
        ) -> SentryId {
            SentryId.empty
        }
    }

    private var sut: SentryStoredCrashReportProcessor!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        sut = SentryStoredCrashReportProcessor(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            currentHubProvider: { SentrySDKInternal.currentHub() },
            preserveCrashedSessionOnCaptureFailure: true
        )
    }

    func testProcessReport_whenReportIsValid_shouldCaptureFatalEvent() throws {
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        try sut.process(report: report)

        assertFatalEventWithScope { event, _ in
            XCTAssertNotNil(event)
        }
    }

    func testProcessReport_whenCrashedSessionExists_shouldCaptureFatalEventWithSession() throws {
        let client = try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        crashedSession.endCrashed(withTimestamp: Date())
        client.fileManager.storeCrashedSession(crashedSession)
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        try sut.process(report: report)

        XCTAssertEqual(client.captureFatalEventWithSessionInvocations.count, 1)
        let capturedSession = try XCTUnwrap(client.captureFatalEventWithSessionInvocations.first?.session)
        XCTAssertEqual(capturedSession.sessionId, crashedSession.sessionId)
        XCTAssertEqual(capturedSession.status, .crashed)
        XCTAssertNil(client.fileManager.readCrashedSession())
    }

    func testProcessReport_whenClientIsMissing_shouldThrow() {
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))

        XCTAssertThrowsError(try sut.process(report: [:])) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
    }

    func testProcessReport_whenClientIsClearedDuringCaptureWithoutCrashedSession_shouldThrow() throws {
        let client = try XCTUnwrap(ClientClearedDuringCapture(options: makeEnabledOptions()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
        XCTAssertEqual(client.captureFatalEventInvocationCount, 1)
        XCTAssertNil(SentrySDKInternal.currentHub().getClient())
    }

    func testProcessReport_whenClientIsClearedDuringCaptureWithCrashedSession_shouldThrowAndRetainSession() throws {
        let client = try XCTUnwrap(ClientClearedDuringCapture(options: makeEnabledOptions()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        crashedSession.endCrashed(withTimestamp: Date())
        client.fileManager.storeCrashedSession(crashedSession)
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
        XCTAssertEqual(client.captureFatalEventInvocationCount, 1)
        XCTAssertNil(SentrySDKInternal.currentHub().getClient())
        XCTAssertEqual(client.fileManager.readCrashedSession()?.sessionId, crashedSession.sessionId)
    }

    func testProcessReport_whenClientClosesDuringCapture_shouldThrow() throws {
        let client = try XCTUnwrap(ClientClosedDuringCapture(options: makeEnabledOptions()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
        XCTAssertFalse(client.isEnabled)
        XCTAssertIdentical(SentrySDKInternal.currentHub().getClient(), client)
    }

    func testProcessReport_whenSessionPreservationIsDisabled_shouldDeleteSessionAfterFailedCapture() throws {
        let disabledOptions = makeEnabledOptions()
        disabledOptions.enabled = false
        let client = try XCTUnwrap(EmptyCaptureClient(options: disabledOptions))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        crashedSession.endCrashed(withTimestamp: Date())
        client.fileManager.storeCrashedSession(crashedSession)
        let report = try getCrashReport(resource: "Resources/crash-report-1")
        let processor = SentryStoredCrashReportProcessor(
            inAppLogic: SentryInAppLogic(inAppIncludes: []),
            currentHubProvider: { SentrySDKInternal.currentHub() },
            preserveCrashedSessionOnCaptureFailure: false
        )

        XCTAssertThrowsError(try processor.process(report: report))
        XCTAssertNil(client.fileManager.readCrashedSession())
    }

    func testProcessReport_whenClientIsDisabledByOptions_shouldThrowAndRetainSession() throws {
        let disabledOptions = makeEnabledOptions()
        disabledOptions.enabled = false
        let client = try XCTUnwrap(EmptyCaptureClient(options: disabledOptions))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let crashedSession = SentrySession(releaseName: "1.0.0", distinctId: "test-installation")
        crashedSession.endCrashed(withTimestamp: Date())
        client.fileManager.storeCrashedSession(crashedSession)
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
        XCTAssertTrue(client.isDisabled)
        XCTAssertEqual(client.fileManager.readCrashedSession()?.sessionId, crashedSession.sessionId)
    }

    func testProcessReport_whenClientHasNoDsn_shouldThrow() throws {
        let client = try XCTUnwrap(EmptyCaptureClient(options: Options()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.missingClient.rawValue)
        }
        XCTAssertTrue(client.isDisabled)
    }

    func testProcessReport_whenClientIntentionallyDiscardsEvent_shouldSucceed() throws {
        let client = try XCTUnwrap(EmptyCaptureClient(options: makeEnabledOptions()))
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: client, andScope: nil))
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        XCTAssertNoThrow(try sut.process(report: report))
        XCTAssertFalse(client.isDisabled)
    }

    func testProcessReport_whenConversionFails_shouldThrow() throws {
        let report = try getCrashReport(resource: "Resources/Crash-faulty-report")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.conversionFailed.rawValue)
        }
    }

    func testProcessReport_whenConverterRaisesException_shouldTranslateExceptionAndRemainOperational() throws {
        var malformedReport = try getCrashReport(resource: "Resources/crash-report-1")
        malformedReport["user"] = "not a dictionary"

        XCTAssertThrowsError(try sut.process(report: malformedReport)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.conversionFailed.rawValue)
        }

        let validReport = try getCrashReport(resource: "Resources/crash-report-1")
        XCTAssertNoThrow(try sut.process(report: validReport))
    }

    private func makeEnabledOptions() -> Options {
        let options = Options()
        options.dsn = "https://public@example.com/1"
        return options
    }
}
