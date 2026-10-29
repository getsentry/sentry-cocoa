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
            (.diskWriteException, 1 << 3),
            (.appLaunch, 1 << 4)
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
        sut.experimental.metrickit.enabledDiagnosticReports = SentryObjCMetricKitDiagnosticReportMapping.crash

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledDiagnosticReports, [.crash])
    }

    func testMetricReportBits_whenReport_shouldMapToItsHeaderBit() {
        // -- Arrange --
        // Spot checks against SentryObjCMetricKitMetricReport.h.
        let cases: [(SentryMetricKit.MetricReport, UInt64)] = [
            (.cpuCumulativeTime, 1 << 0),
            (.diskIOLogicalWrites, 1 << 11),
            (.animationHitchTimeRatio, 1 << 22),
            (.diskSpaceTotalCapacity, 1 << 30),
            (.exitForegroundNormal, 1 << 31),
            (.exitBackgroundTaskTimeout, 1 << 46)
        ]

        for (report, expectedBit) in cases {
            // -- Act --
            let bits = SentryObjCMetricKitMetricReportMapping.bits(for: [report])

            // -- Assert --
            XCTAssertEqual(bits, expectedBit, "Expected bit \(expectedBit) for \(report)")
        }
    }

    func testMetricReportBits_whenEveryReport_shouldSetOneDistinctBitEach() {
        // -- Arrange --
        let reports = SentryMetricKit.MetricReport.allCases

        // -- Act --
        let bits = SentryObjCMetricKitMetricReportMapping.bits(for: Set(reports))

        // -- Assert --
        // Matches SentryObjCMetricKitMetricReportAll in SentryObjCMetricKitMetricReport.h.
        XCTAssertEqual(bits, (1 << UInt64(reports.count)) - 1)
    }

    func testMetricReportReports_whenEveryReport_shouldRoundTrip() {
        // -- Arrange --
        let reports = Set<SentryMetricKit.MetricReport>.all

        // -- Act --
        let roundTripped = SentryObjCMetricKitMetricReportMapping.reports(for: SentryObjCMetricKitMetricReportMapping.bits(for: reports))

        // -- Assert --
        XCTAssertEqual(roundTripped, reports)
    }

    func testMetricReportReports_whenUnknownBits_shouldIgnoreThem() {
        // -- Arrange --
        let bits: SentryObjCMetricKitMetricReport = (1 << 2) | (1 << 63)

        // -- Act --
        let reports = SentryObjCMetricKitMetricReportMapping.reports(for: bits)

        // -- Assert --
        XCTAssertEqual(reports, [.gpuCumulativeTime])
    }

    func testEnabledMetricReports_whenSetThroughExperimentalOptions_shouldWriteThrough() {
        // -- Arrange --
        let options = Options()
        let sut = SentryObjCOptions(options)

        // -- Act --
        sut.experimental.metrickit.enabledMetricReports = 1 << 18

        // -- Assert --
        XCTAssertEqual(options.experimental.metrickit.enabledMetricReports, [.memoryPeakUsage])
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
