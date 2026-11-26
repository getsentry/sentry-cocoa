#if canImport(MetricKit) && !os(tvOS)
extension SentryMetricKit.MetricReport {
    /// Creates a report from its name in the options dictionary hybrid SDKs use.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init?(dictionaryValue: String) {
        switch dictionaryValue {
        case "cpuCumulativeTime": self = .cpuCumulativeTime
        case "cpuCumulativeInstructions": self = .cpuCumulativeInstructions
        case "gpuCumulativeTime": self = .gpuCumulativeTime
        case "appTimeForeground": self = .appTimeForeground
        case "appTimeBackground": self = .appTimeBackground
        case "appTimeBackgroundAudio": self = .appTimeBackgroundAudio
        case "appTimeBackgroundLocation": self = .appTimeBackgroundLocation
        case "networkWifiUpload": self = .networkWifiUpload
        case "networkWifiDownload": self = .networkWifiDownload
        case "networkCellularUpload": self = .networkCellularUpload
        case "networkCellularDownload": self = .networkCellularDownload
        case "diskIOLogicalWrites": self = .diskIOLogicalWrites
        case "locationBestAccuracyTime": self = .locationBestAccuracyTime
        case "locationBestAccuracyForNavigationTime": self = .locationBestAccuracyForNavigationTime
        case "locationNearestTenMetersTime": self = .locationNearestTenMetersTime
        case "locationHundredMetersTime": self = .locationHundredMetersTime
        case "locationKilometerTime": self = .locationKilometerTime
        case "locationThreeKilometersTime": self = .locationThreeKilometersTime
        case "memoryPeakUsage": self = .memoryPeakUsage
        case "memoryAverageSuspended": self = .memoryAverageSuspended
        case "displayAveragePixelLuminance": self = .displayAveragePixelLuminance
        case "animationScrollHitchTimeRatio": self = .animationScrollHitchTimeRatio
        case "animationHitchTimeRatio": self = .animationHitchTimeRatio
        case "animationTotalHitchTime": self = .animationTotalHitchTime
        case "animationTotalAnimationTime": self = .animationTotalAnimationTime
        case "metalFramesPerSecond": self = .metalFramesPerSecond
        case "metalFrameCount": self = .metalFrameCount
        case "metalActiveDrawingDuration": self = .metalActiveDrawingDuration
        case "diskSpaceBinaryFileSize": self = .diskSpaceBinaryFileSize
        case "diskSpaceBinaryFileCount": self = .diskSpaceBinaryFileCount
        case "diskSpaceDataFileSize": self = .diskSpaceDataFileSize
        case "diskSpaceDataFileCount": self = .diskSpaceDataFileCount
        case "diskSpaceCacheFolderSize": self = .diskSpaceCacheFolderSize
        case "diskSpaceCloneSize": self = .diskSpaceCloneSize
        case "diskSpaceTotalUsed": self = .diskSpaceTotalUsed
        case "diskSpaceTotalCapacity": self = .diskSpaceTotalCapacity
        case "launchTimeToFirstDraw": self = .launchTimeToFirstDraw
        case "launchResumeTime": self = .launchResumeTime
        case "launchOptimizedTimeToFirstDraw": self = .launchOptimizedTimeToFirstDraw
        case "launchExtended": self = .launchExtended
        case "responsivenessHangTime": self = .responsivenessHangTime
        case "cellularConditionTime": self = .cellularConditionTime
        case "exitForegroundNormal": self = .exitForegroundNormal
        case "exitForegroundMemoryResourceLimit": self = .exitForegroundMemoryResourceLimit
        case "exitForegroundBadAccess": self = .exitForegroundBadAccess
        case "exitForegroundAbnormal": self = .exitForegroundAbnormal
        case "exitForegroundIllegalInstruction": self = .exitForegroundIllegalInstruction
        case "exitForegroundWatchdog": self = .exitForegroundWatchdog
        case "exitBackgroundNormal": self = .exitBackgroundNormal
        case "exitBackgroundMemoryResourceLimit": self = .exitBackgroundMemoryResourceLimit
        case "exitBackgroundCPUResourceLimit": self = .exitBackgroundCPUResourceLimit
        case "exitBackgroundMemoryPressure": self = .exitBackgroundMemoryPressure
        case "exitBackgroundBadAccess": self = .exitBackgroundBadAccess
        case "exitBackgroundAbnormal": self = .exitBackgroundAbnormal
        case "exitBackgroundIllegalInstruction": self = .exitBackgroundIllegalInstruction
        case "exitBackgroundWatchdog": self = .exitBackgroundWatchdog
        case "exitBackgroundSuspendedWithLockedFile": self = .exitBackgroundSuspendedWithLockedFile
        case "exitBackgroundTaskTimeout": self = .exitBackgroundTaskTimeout
        default: return nil
        }
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
