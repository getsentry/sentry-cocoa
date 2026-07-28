@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import Foundation
import XCTest

final class SentryStoredCrashReportProcessorTests: SentrySDKIntegrationTestsBase {
    private var sut: SentryStoredCrashReportProcessor!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        sut = SentryStoredCrashReportProcessor(inAppLogic: SentryInAppLogic(inAppIncludes: []))
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

    func testProcessReport_whenConversionFails_shouldThrow() throws {
        let report = try getCrashReport(resource: "Resources/Crash-faulty-report")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryStoredCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryStoredCrashReportProcessorError.conversionFailed.rawValue)
        }
    }
}
