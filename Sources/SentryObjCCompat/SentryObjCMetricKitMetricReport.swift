#if canImport(MetricKit) && !os(tvOS)
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public typealias SentryObjCMetricKitMetricReport = UInt64

/// Maps the `SentryObjCMetricKitMetricReport` bitmask to the SDK's report set. The bitmask is a
/// plain `UInt64` like the other `NS_OPTIONS` wrappers, so the mapping lives in its own namespace
/// instead of an extension that would collide with theirs.
enum SentryObjCMetricKitMetricReportMapping {
    /// The bit of each report is its index. Keep this in sync with
    /// SentryObjCMetricKitMetricReport.h and only append new reports.
    private static let reportsByBit: [SentryMetricKit.MetricReport] = [
        .cpuCumulativeTime,
        .cpuCumulativeInstructions,
        .gpuCumulativeTime,
        .appTimeForeground,
        .appTimeBackground,
        .appTimeBackgroundAudio,
        .appTimeBackgroundLocation,
        .networkWifiUpload,
        .networkWifiDownload,
        .networkCellularUpload,
        .networkCellularDownload,
        .diskIOLogicalWrites,
        .locationBestAccuracyTime,
        .locationBestAccuracyForNavigationTime,
        .locationNearestTenMetersTime,
        .locationHundredMetersTime,
        .locationKilometerTime,
        .locationThreeKilometersTime,
        .memoryPeakUsage,
        .memoryAverageSuspended,
        .displayAveragePixelLuminance,
        .animationScrollHitchTimeRatio,
        .animationHitchTimeRatio,
        .diskSpaceBinaryFileSize,
        .diskSpaceBinaryFileCount,
        .diskSpaceDataFileSize,
        .diskSpaceDataFileCount,
        .diskSpaceCacheFolderSize,
        .diskSpaceCloneSize,
        .diskSpaceTotalUsed,
        .diskSpaceTotalCapacity,
        .exitForegroundNormal,
        .exitForegroundMemoryResourceLimit,
        .exitForegroundBadAccess,
        .exitForegroundAbnormal,
        .exitForegroundIllegalInstruction,
        .exitForegroundWatchdog,
        .exitBackgroundNormal,
        .exitBackgroundMemoryResourceLimit,
        .exitBackgroundCPUResourceLimit,
        .exitBackgroundMemoryPressure,
        .exitBackgroundBadAccess,
        .exitBackgroundAbnormal,
        .exitBackgroundIllegalInstruction,
        .exitBackgroundWatchdog,
        .exitBackgroundSuspendedWithLockedFile,
        .exitBackgroundTaskTimeout
    ]

    static func bit(for report: SentryMetricKit.MetricReport) -> SentryObjCMetricKitMetricReport? {
        reportsByBit.firstIndex(of: report).map { 1 << SentryObjCMetricKitMetricReport($0) }
    }

    static func bits(for reports: Set<SentryMetricKit.MetricReport>) -> SentryObjCMetricKitMetricReport {
        reports.reduce(0) { bits, report in
            bits | (bit(for: report) ?? 0)
        }
    }

    /// Bits that don't name a report are ignored.
    static func reports(for bits: SentryObjCMetricKitMetricReport) -> Set<SentryMetricKit.MetricReport> {
        Set(reportsByBit.enumerated().filter { index, _ in
            bits & (1 << SentryObjCMetricKitMetricReport(index)) != 0
        }.map(\.element))
    }
}

// swiftlint:enable missing_docs
#endif // canImport(MetricKit) && !os(tvOS)
