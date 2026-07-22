@_spi(Private) import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

final class SentryCrashReportProcessorTests: SentrySDKIntegrationTestsBase {
    private var sut: SentryCrashReportProcessor!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        sut = SentryCrashReportProcessor(inAppLogic: SentryInAppLogic(inAppIncludes: []))
    }

    func testProcessReport_whenReportIsValid_shouldCaptureFatalEvent() throws {
        let report = try getCrashReport(resource: "Resources/crash-report-1")

        try sut.process(report: report)

        assertFatalEventWithScope { event, _ in
            XCTAssertNotNil(event)
        }
    }

    func testProcessReport_whenClientIsMissing_shouldThrow() {
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: nil, andScope: nil))

        XCTAssertThrowsError(try sut.process(report: [:])) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryCrashReportProcessorError.missingClient.rawValue)
        }
    }

    func testProcessReport_whenConversionFails_shouldThrow() throws {
        let report = try getCrashReport(resource: "Resources/Crash-faulty-report")

        XCTAssertThrowsError(try sut.process(report: report)) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, SentryCrashReportProcessorErrorDomain)
            XCTAssertEqual(error.code, SentryCrashReportProcessorError.conversionFailed.rawValue)
        }
    }
}
