#if canImport(MetricKit) && !os(tvOS)
extension SentryMetricKit {
    /// A value from a MetricKit metric payload the SDK can send as a Sentry metric.
    ///
    /// Used by ``SentryMetricKitOptions/enabledMetricReports`` to choose which values to send. Each
    /// case maps to one metric named `metrickit.<group>.<name>`, recorded at the middle of the
    /// payload's reporting interval.
    public enum MetricReport: Hashable, CaseIterable, Sendable {
        // MARK: CPU

        /// The CPU time the app used, sent as the `metrickit.cpu.cumulative_time` distribution in
        /// seconds.
        case cpuCumulativeTime

        /// The CPU instructions the app retired, sent as the
        /// `metrickit.cpu.cumulative_instructions` distribution.
        case cpuCumulativeInstructions

        // MARK: GPU

        /// The GPU time the app used, sent as the `metrickit.gpu.cumulative_time` distribution in
        /// seconds.
        case gpuCumulativeTime

        // MARK: App Run Time

        /// The time the app ran in the foreground, sent as the `metrickit.app_time.foreground`
        /// distribution in seconds.
        case appTimeForeground

        /// The time the app ran in the background, sent as the `metrickit.app_time.background`
        /// distribution in seconds.
        case appTimeBackground

        /// The time the app played audio in the background, sent as the
        /// `metrickit.app_time.background_audio` distribution in seconds.
        case appTimeBackgroundAudio

        /// The time the app used location in the background, sent as the
        /// `metrickit.app_time.background_location` distribution in seconds.
        case appTimeBackgroundLocation

        // MARK: Network Transfer

        /// The data the app uploaded over Wi-Fi, sent as the `metrickit.network.wifi_upload`
        /// distribution in bytes.
        case networkWifiUpload

        /// The data the app downloaded over Wi-Fi, sent as the `metrickit.network.wifi_download`
        /// distribution in bytes.
        case networkWifiDownload

        /// The data the app uploaded over cellular, sent as the
        /// `metrickit.network.cellular_upload` distribution in bytes.
        case networkCellularUpload

        /// The data the app downloaded over cellular, sent as the
        /// `metrickit.network.cellular_download` distribution in bytes.
        case networkCellularDownload

        // MARK: Disk I/O

        /// The data the app wrote to disk, sent as the `metrickit.disk_io.logical_writes`
        /// distribution in bytes.
        case diskIOLogicalWrites

        // MARK: Location Activity

        /// The time the app used location at the best accuracy, sent as the
        /// `metrickit.location.best_accuracy_time` distribution in seconds.
        case locationBestAccuracyTime

        /// The time the app used location at the best accuracy for navigation, sent as the
        /// `metrickit.location.best_accuracy_for_nav_time` distribution in seconds.
        case locationBestAccuracyForNavigationTime

        /// The time the app used location accurate to ten meters, sent as the
        /// `metrickit.location.nearest_ten_meters_time` distribution in seconds.
        case locationNearestTenMetersTime

        /// The time the app used location accurate to a hundred meters, sent as the
        /// `metrickit.location.hundred_meters_time` distribution in seconds.
        case locationHundredMetersTime

        /// The time the app used location accurate to a kilometer, sent as the
        /// `metrickit.location.kilometer_time` distribution in seconds.
        case locationKilometerTime

        /// The time the app used location accurate to three kilometers, sent as the
        /// `metrickit.location.three_kilometers_time` distribution in seconds.
        case locationThreeKilometersTime

        // MARK: Memory

        /// The app's peak memory usage, sent as the `metrickit.memory.peak_usage` gauge in bytes.
        case memoryPeakUsage

        /// The app's average memory usage while suspended, sent as the
        /// `metrickit.memory.avg_suspended` gauge in bytes.
        case memoryAverageSuspended

        // MARK: Display

        /// The average pixel luminance of the app's content, sent as the
        /// `metrickit.display.avg_pixel_luminance` gauge in APL.
        case displayAveragePixelLuminance

        // MARK: Animation

        /// The share of scrolling time the app spent hitching, sent as the
        /// `metrickit.animation.scroll_hitch_time_ratio` gauge as a ratio.
        case animationScrollHitchTimeRatio

        /// The share of animation time the app spent hitching, sent as the
        /// `metrickit.animation.hitch_time_ratio` gauge as a ratio.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case animationHitchTimeRatio

        // MARK: Disk Space Usage

        /// The size of the app's binaries, sent as the `metrickit.disk_space.binary_file_size`
        /// gauge in bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceBinaryFileSize

        /// The number of the app's binaries, sent as the `metrickit.disk_space.binary_file_count`
        /// gauge.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceBinaryFileCount

        /// The size of the app's data files, sent as the `metrickit.disk_space.data_file_size`
        /// gauge in bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceDataFileSize

        /// The number of the app's data files, sent as the `metrickit.disk_space.data_file_count`
        /// gauge.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceDataFileCount

        /// The size of the app's cache folder, sent as the
        /// `metrickit.disk_space.cache_folder_size` gauge in bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceCacheFolderSize

        /// The size of the app's cloned files, sent as the `metrickit.disk_space.clone_size` gauge
        /// in bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceCloneSize

        /// The disk space the app uses, sent as the `metrickit.disk_space.total_used` gauge in
        /// bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceTotalUsed

        /// The capacity of the device's disk, sent as the `metrickit.disk_space.total_capacity`
        /// gauge in bytes.
        ///
        /// - Note: Requires iOS 26 or macOS 26.
        case diskSpaceTotalCapacity

        // MARK: Foreground Exits

        /// Normal exits of the app in the foreground, sent as the `metrickit.exit.fg.normal` count.
        case exitForegroundNormal

        /// Foreground exits for exceeding the memory limit, sent as the
        /// `metrickit.exit.fg.memory_resource_limit` count.
        case exitForegroundMemoryResourceLimit

        /// Foreground exits for invalid memory access, sent as the `metrickit.exit.fg.bad_access`
        /// count.
        case exitForegroundBadAccess

        /// Abnormal foreground exits, sent as the `metrickit.exit.fg.abnormal` count.
        case exitForegroundAbnormal

        /// Foreground exits for an illegal instruction, sent as the
        /// `metrickit.exit.fg.illegal_instruction` count.
        case exitForegroundIllegalInstruction

        /// Foreground exits by the watchdog, sent as the `metrickit.exit.fg.watchdog` count.
        case exitForegroundWatchdog

        // MARK: Background Exits

        /// Normal exits of the app in the background, sent as the `metrickit.exit.bg.normal` count.
        case exitBackgroundNormal

        /// Background exits for exceeding the memory limit, sent as the
        /// `metrickit.exit.bg.memory_resource_limit` count.
        case exitBackgroundMemoryResourceLimit

        /// Background exits for exceeding the CPU limit, sent as the
        /// `metrickit.exit.bg.cpu_resource_limit` count.
        case exitBackgroundCPUResourceLimit

        /// Background exits under memory pressure, sent as the
        /// `metrickit.exit.bg.memory_pressure` count.
        case exitBackgroundMemoryPressure

        /// Background exits for invalid memory access, sent as the `metrickit.exit.bg.bad_access`
        /// count.
        case exitBackgroundBadAccess

        /// Abnormal background exits, sent as the `metrickit.exit.bg.abnormal` count.
        case exitBackgroundAbnormal

        /// Background exits for an illegal instruction, sent as the
        /// `metrickit.exit.bg.illegal_instruction` count.
        case exitBackgroundIllegalInstruction

        /// Background exits by the watchdog, sent as the `metrickit.exit.bg.watchdog` count.
        case exitBackgroundWatchdog

        /// Background exits for holding a file lock while suspended, sent as the
        /// `metrickit.exit.bg.suspended_with_locked_file` count.
        case exitBackgroundSuspendedWithLockedFile

        /// Background exits for a background task that ran out of time, sent as the
        /// `metrickit.exit.bg.background_task_timeout` count.
        case exitBackgroundTaskTimeout
    }
}

extension Set where Element == SentryMetricKit.MetricReport {
    /// Every MetricKit metric report.
    public static var all: Self {
        Self(Element.allCases)
    }
}

extension SentryMetricKit.MetricReport {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    var name: String {
        switch self {
        case .cpuCumulativeTime: return "metrickit.cpu.cumulative_time"
        case .cpuCumulativeInstructions: return "metrickit.cpu.cumulative_instructions"
        case .gpuCumulativeTime: return "metrickit.gpu.cumulative_time"
        case .appTimeForeground: return "metrickit.app_time.foreground"
        case .appTimeBackground: return "metrickit.app_time.background"
        case .appTimeBackgroundAudio: return "metrickit.app_time.background_audio"
        case .appTimeBackgroundLocation: return "metrickit.app_time.background_location"
        case .networkWifiUpload: return "metrickit.network.wifi_upload"
        case .networkWifiDownload: return "metrickit.network.wifi_download"
        case .networkCellularUpload: return "metrickit.network.cellular_upload"
        case .networkCellularDownload: return "metrickit.network.cellular_download"
        case .diskIOLogicalWrites: return "metrickit.disk_io.logical_writes"
        case .locationBestAccuracyTime: return "metrickit.location.best_accuracy_time"
        case .locationBestAccuracyForNavigationTime: return "metrickit.location.best_accuracy_for_nav_time"
        case .locationNearestTenMetersTime: return "metrickit.location.nearest_ten_meters_time"
        case .locationHundredMetersTime: return "metrickit.location.hundred_meters_time"
        case .locationKilometerTime: return "metrickit.location.kilometer_time"
        case .locationThreeKilometersTime: return "metrickit.location.three_kilometers_time"
        case .memoryPeakUsage: return "metrickit.memory.peak_usage"
        case .memoryAverageSuspended: return "metrickit.memory.avg_suspended"
        case .displayAveragePixelLuminance: return "metrickit.display.avg_pixel_luminance"
        case .animationScrollHitchTimeRatio: return "metrickit.animation.scroll_hitch_time_ratio"
        case .animationHitchTimeRatio: return "metrickit.animation.hitch_time_ratio"
        case .diskSpaceBinaryFileSize: return "metrickit.disk_space.binary_file_size"
        case .diskSpaceBinaryFileCount: return "metrickit.disk_space.binary_file_count"
        case .diskSpaceDataFileSize: return "metrickit.disk_space.data_file_size"
        case .diskSpaceDataFileCount: return "metrickit.disk_space.data_file_count"
        case .diskSpaceCacheFolderSize: return "metrickit.disk_space.cache_folder_size"
        case .diskSpaceCloneSize: return "metrickit.disk_space.clone_size"
        case .diskSpaceTotalUsed: return "metrickit.disk_space.total_used"
        case .diskSpaceTotalCapacity: return "metrickit.disk_space.total_capacity"
        case .exitForegroundNormal: return "metrickit.exit.fg.normal"
        case .exitForegroundMemoryResourceLimit: return "metrickit.exit.fg.memory_resource_limit"
        case .exitForegroundBadAccess: return "metrickit.exit.fg.bad_access"
        case .exitForegroundAbnormal: return "metrickit.exit.fg.abnormal"
        case .exitForegroundIllegalInstruction: return "metrickit.exit.fg.illegal_instruction"
        case .exitForegroundWatchdog: return "metrickit.exit.fg.watchdog"
        case .exitBackgroundNormal: return "metrickit.exit.bg.normal"
        case .exitBackgroundMemoryResourceLimit: return "metrickit.exit.bg.memory_resource_limit"
        case .exitBackgroundCPUResourceLimit: return "metrickit.exit.bg.cpu_resource_limit"
        case .exitBackgroundMemoryPressure: return "metrickit.exit.bg.memory_pressure"
        case .exitBackgroundBadAccess: return "metrickit.exit.bg.bad_access"
        case .exitBackgroundAbnormal: return "metrickit.exit.bg.abnormal"
        case .exitBackgroundIllegalInstruction: return "metrickit.exit.bg.illegal_instruction"
        case .exitBackgroundWatchdog: return "metrickit.exit.bg.watchdog"
        case .exitBackgroundSuspendedWithLockedFile: return "metrickit.exit.bg.suspended_with_locked_file"
        case .exitBackgroundTaskTimeout: return "metrickit.exit.bg.background_task_timeout"
        }
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
