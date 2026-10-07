#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@testable import SentryObjCCompat
import XCTest

#if canImport(MetricKit) && !os(tvOS)
final class SentryObjCCompatMetricKitOptionsTests: XCTestCase {

    func testDiagnosticReportInit_whenEachReport_shouldMapToItsBit() {
        // -- Arrange --
        let cases: [(SentryMetricKit.DiagnosticReport, UInt)] = [
            (.crash, 1 << 0),
            (.hang, 1 << 1),
            (.cpuException, 1 << 2),
            (.diskWriteException, 1 << 3)
        ]

        for (report, expectedBit) in cases {
            // -- Act --
            let bits = SentryObjCMetricKitDiagnosticReportMapping.bits(for: [report])

            // -- Assert --
            XCTAssertEqual(bits, expectedBit, "Expected bit \(expectedBit) for \(report)")
        }
    }

    func testDiagnosticReportUnderlying_whenEveryReport_shouldRoundTrip() {
        // -- Arrange --
        let reports = SentryMetricKit.DiagnosticReport.all

        // -- Act --
        let roundTripped = SentryObjCMetricKitDiagnosticReportMapping.reports(for: SentryObjCMetricKitDiagnosticReportMapping.bits(for: reports))

        // -- Assert --
        XCTAssertEqual(roundTripped, reports)
    }

    func testDiagnosticReportUnderlying_whenUnknownBits_shouldIgnoreThem() {
        // -- Arrange --
        let bits: SentryObjCMetricKitDiagnosticReport = SentryObjCMetricKitDiagnosticReportMapping.hang | (1 << 10)

        // -- Act --
        let reports = SentryObjCMetricKitDiagnosticReportMapping.reports(for: bits)

        // -- Assert --
        XCTAssertEqual(reports, [.hang])
    }

    func testEnabledDiagnosticReports_whenSetThroughExperimentalOptions_shouldWriteThrough() {
        // -- Arrange --
        let options = Options()
        let sut = SentryObjCOptions(options)

        // -- Act --
        sut.experimental.metricKit.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportMapping.crash

        // -- Assert --
        XCTAssertEqual(options.experimental.metricKit.enabledDiagnosticReports, [.crash])
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
