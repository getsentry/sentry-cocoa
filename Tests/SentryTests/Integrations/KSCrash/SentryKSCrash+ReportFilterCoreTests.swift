#if ENABLE_KSCRASH
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

final class SentryKSCrashReportFilterCoreTests: SentrySDKIntegrationTestsBase {
    private final class TestReport {
        let dictionary: [AnyHashable: Any]?

        init(dictionary: [AnyHashable: Any]?) {
            self.dictionary = dictionary
        }
    }

    private var sut: SentryKSCrash.ReportFilterCore!

    override func setUp() {
        super.setUp()
        givenSdkWithHub()
        sut = SentryKSCrash.ReportFilterCore(
            reportProcessor: SentryStoredCrashReportProcessor(
                inAppLogic: SentryInAppLogic(inAppIncludes: [])
            )
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

    private func getTestClient() throws -> TestClient {
        try XCTUnwrap(SentrySDKInternal.currentHub().getClient() as? TestClient)
    }
}
#endif
