#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import KSCrashInstallations
import XCTest

final class SentryKSCrashReportFilterTests: SentrySDKIntegrationTestsBase {
    private var sut: SentryKSCrash.ReportFilter!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        sut = SentryKSCrash.ReportFilter(
            reportProcessor: SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: [])
            )
        )
    }

    func testFilterReports_whenUnsupportedReportPrecedesValidReport_shouldContinueProcessing() throws {
        let unsupportedReport = CrashReportString.report(withValue: "unsupported")
        let validReport = CrashReportDictionary.report(
            withValue: try getCrashReport(resource: "Resources/crash-report-1")
        )

        var processedReports: [any CrashReport]?
        var processingError: Error?
        sut.filterReports([unsupportedReport, validReport]) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 1)
        XCTAssertIdentical(processedReports?.first as AnyObject?, validReport)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 1)
    }

    func testFilterReports_whenReportProcessingFails_shouldContinueProcessingLaterReports() throws {
        let firstValidReport = CrashReportDictionary.report(
            withValue: try getCrashReport(resource: "Resources/crash-report-1")
        )
        let invalidReport = CrashReportDictionary.report(
            withValue: try getCrashReport(resource: "Resources/Crash-faulty-report")
        )
        let secondValidReport = CrashReportDictionary.report(
            withValue: try getCrashReport(resource: "Resources/crash-report-1")
        )

        var processedReports: [any CrashReport]?
        var processingError: Error?
        sut.filterReports([firstValidReport, invalidReport, secondValidReport]) { reports, error in
            processedReports = reports
            processingError = error
        }

        XCTAssertNil(processingError)
        XCTAssertEqual(processedReports?.count, 2)
        XCTAssertIdentical(processedReports?.first as AnyObject?, firstValidReport)
        XCTAssertIdentical(processedReports?.last as AnyObject?, secondValidReport)
        XCTAssertEqual(try getTestClient().captureFatalEventInvocations.count, 2)
    }

    private func getTestClient() throws -> TestClient {
        try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
    }
}
#endif
