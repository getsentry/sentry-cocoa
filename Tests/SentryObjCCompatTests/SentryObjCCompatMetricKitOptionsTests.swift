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

    /// The bit index of every report, matching SentryObjCMetricKitMetricReport.h. The bits are
    /// public API, so a report must never move to another bit.
    private let metricReportBitIndexes: [(SentryMetricKit.MetricReport, UInt64)] = [
        (.cpuCumulativeTime, 0),
        (.cpuCumulativeInstructions, 1),
        (.gpuCumulativeTime, 2),
        (.appTimeForeground, 3),
        (.appTimeBackground, 4),
        (.appTimeBackgroundAudio, 5),
        (.appTimeBackgroundLocation, 6),
        (.networkWifiUpload, 7),
        (.networkWifiDownload, 8),
        (.networkCellularUpload, 9),
        (.networkCellularDownload, 10),
        (.diskIOLogicalWrites, 11),
        (.locationBestAccuracyTime, 12),
        (.locationBestAccuracyForNavigationTime, 13),
        (.locationNearestTenMetersTime, 14),
        (.locationHundredMetersTime, 15),
        (.locationKilometerTime, 16),
        (.locationThreeKilometersTime, 17),
        (.memoryPeakUsage, 18),
        (.memoryAverageSuspended, 19),
        (.displayAveragePixelLuminance, 20),
        (.animationScrollHitchTimeRatio, 21),
        (.animationHitchTimeRatio, 22),
        (.diskSpaceBinaryFileSize, 23),
        (.diskSpaceBinaryFileCount, 24),
        (.diskSpaceDataFileSize, 25),
        (.diskSpaceDataFileCount, 26),
        (.diskSpaceCacheFolderSize, 27),
        (.diskSpaceCloneSize, 28),
        (.diskSpaceTotalUsed, 29),
        (.diskSpaceTotalCapacity, 30),
        (.exitForegroundNormal, 31),
        (.exitForegroundMemoryResourceLimit, 32),
        (.exitForegroundBadAccess, 33),
        (.exitForegroundAbnormal, 34),
        (.exitForegroundIllegalInstruction, 35),
        (.exitForegroundWatchdog, 36),
        (.exitBackgroundNormal, 37),
        (.exitBackgroundMemoryResourceLimit, 38),
        (.exitBackgroundCPUResourceLimit, 39),
        (.exitBackgroundMemoryPressure, 40),
        (.exitBackgroundBadAccess, 41),
        (.exitBackgroundAbnormal, 42),
        (.exitBackgroundIllegalInstruction, 43),
        (.exitBackgroundWatchdog, 44),
        (.exitBackgroundSuspendedWithLockedFile, 45),
        (.exitBackgroundTaskTimeout, 46)
    ]

    func testMetricReportBitIndexes_shouldCoverEveryReportOnce() {
        // -- Arrange --
        let reports = metricReportBitIndexes.map(\.0)
        let indexes = metricReportBitIndexes.map(\.1)

        // -- Assert --
        XCTAssertEqual(reports.count, SentryMetricKit.MetricReport.allCases.count)
        XCTAssertEqual(Set(reports), Set(SentryMetricKit.MetricReport.allCases))
        XCTAssertEqual(indexes, Array(0..<UInt64(reports.count)))
    }

    func testMetricReportBits_whenEachReport_shouldMapToItsHeaderBit() {
        for (report, index) in metricReportBitIndexes {
            // -- Act --
            let bits = SentryObjCMetricKitMetricReportMapping.bits(for: [report])

            // -- Assert --
            XCTAssertEqual(bits, 1 << index, "Expected bit \(index) for \(report)")
        }
    }

    func testMetricReportReports_whenEachHeaderBit_shouldMapToItsReport() {
        for (report, index) in metricReportBitIndexes {
            // -- Act --
            let reports = SentryObjCMetricKitMetricReportMapping.reports(for: 1 << index)

            // -- Assert --
            XCTAssertEqual(reports, [report], "Expected \(report) for bit \(index)")
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
