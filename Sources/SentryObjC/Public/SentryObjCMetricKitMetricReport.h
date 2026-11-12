#import <Foundation/Foundation.h>

#if __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV

/// The values of MetricKit metric payloads the SDK can send as Sentry metrics.
///
/// Each report maps to one metric named @c metrickit.<group>.<name>, recorded at the middle of the
/// payload's reporting interval.
typedef NS_OPTIONS(uint64_t, SentryObjCMetricKitMetricReport) {
    /// No metric report.
    SentryObjCMetricKitMetricReportNone = 0,
    /// The CPU time the app used, sent as the @c metrickit.cpu.cumulative_time distribution in
    /// seconds.
    SentryObjCMetricKitMetricReportCPUCumulativeTime = 1ULL << 0,
    /// The CPU instructions the app retired, sent as the @c metrickit.cpu.cumulative_instructions
    /// distribution.
    SentryObjCMetricKitMetricReportCPUCumulativeInstructions = 1ULL << 1,
    /// The GPU time the app used, sent as the @c metrickit.gpu.cumulative_time distribution in
    /// seconds.
    SentryObjCMetricKitMetricReportGPUCumulativeTime = 1ULL << 2,
    /// The time the app ran in the foreground, sent as the @c metrickit.app_time.foreground
    /// distribution in seconds.
    SentryObjCMetricKitMetricReportAppTimeForeground = 1ULL << 3,
    /// The time the app ran in the background, sent as the @c metrickit.app_time.background
    /// distribution in seconds.
    SentryObjCMetricKitMetricReportAppTimeBackground = 1ULL << 4,
    /// The time the app played audio in the background, sent as the
    /// @c metrickit.app_time.background_audio distribution in seconds.
    SentryObjCMetricKitMetricReportAppTimeBackgroundAudio = 1ULL << 5,
    /// The time the app used location in the background, sent as the
    /// @c metrickit.app_time.background_location distribution in seconds.
    SentryObjCMetricKitMetricReportAppTimeBackgroundLocation = 1ULL << 6,
    /// The data the app uploaded over Wi-Fi, sent as the @c metrickit.network.wifi_upload
    /// distribution in bytes.
    SentryObjCMetricKitMetricReportNetworkWifiUpload = 1ULL << 7,
    /// The data the app downloaded over Wi-Fi, sent as the @c metrickit.network.wifi_download
    /// distribution in bytes.
    SentryObjCMetricKitMetricReportNetworkWifiDownload = 1ULL << 8,
    /// The data the app uploaded over cellular, sent as the @c metrickit.network.cellular_upload
    /// distribution in bytes.
    SentryObjCMetricKitMetricReportNetworkCellularUpload = 1ULL << 9,
    /// The data the app downloaded over cellular, sent as the
    /// @c metrickit.network.cellular_download distribution in bytes.
    SentryObjCMetricKitMetricReportNetworkCellularDownload = 1ULL << 10,
    /// The data the app wrote to disk, sent as the @c metrickit.disk_io.logical_writes distribution
    /// in bytes.
    SentryObjCMetricKitMetricReportDiskIOLogicalWrites = 1ULL << 11,
    /// The time the app used location at the best accuracy, sent as the
    /// @c metrickit.location.best_accuracy_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationBestAccuracyTime = 1ULL << 12,
    /// The time the app used location at the best accuracy for navigation, sent as the
    /// @c metrickit.location.best_accuracy_for_nav_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationBestAccuracyForNavigationTime = 1ULL << 13,
    /// The time the app used location accurate to ten meters, sent as the
    /// @c metrickit.location.nearest_ten_meters_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationNearestTenMetersTime = 1ULL << 14,
    /// The time the app used location accurate to a hundred meters, sent as the
    /// @c metrickit.location.hundred_meters_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationHundredMetersTime = 1ULL << 15,
    /// The time the app used location accurate to a kilometer, sent as the
    /// @c metrickit.location.kilometer_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationKilometerTime = 1ULL << 16,
    /// The time the app used location accurate to three kilometers, sent as the
    /// @c metrickit.location.three_kilometers_time distribution in seconds.
    SentryObjCMetricKitMetricReportLocationThreeKilometersTime = 1ULL << 17,
    /// The app's peak memory usage, sent as the @c metrickit.memory.peak_usage gauge in bytes.
    SentryObjCMetricKitMetricReportMemoryPeakUsage = 1ULL << 18,
    /// The app's average memory usage while suspended, sent as the
    /// @c metrickit.memory.avg_suspended gauge in bytes.
    SentryObjCMetricKitMetricReportMemoryAverageSuspended = 1ULL << 19,
    /// The average pixel luminance of the app's content, sent as the
    /// @c metrickit.display.avg_pixel_luminance gauge in APL.
    SentryObjCMetricKitMetricReportDisplayAveragePixelLuminance = 1ULL << 20,
    /// The share of scrolling time the app spent hitching, sent as the
    /// @c metrickit.animation.scroll_hitch_time_ratio gauge as a ratio.
    SentryObjCMetricKitMetricReportAnimationScrollHitchTimeRatio = 1ULL << 21,
    /// The share of animation time the app spent hitching, sent as the
    /// @c metrickit.animation.hitch_time_ratio gauge as a ratio.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportAnimationHitchTimeRatio = 1ULL << 22,
    /// The size of the app's binaries, sent as the @c metrickit.disk_space.binary_file_size gauge
    /// in bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceBinaryFileSize = 1ULL << 23,
    /// The number of the app's binaries, sent as the @c metrickit.disk_space.binary_file_count
    /// gauge.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceBinaryFileCount = 1ULL << 24,
    /// The size of the app's data files, sent as the @c metrickit.disk_space.data_file_size gauge
    /// in bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceDataFileSize = 1ULL << 25,
    /// The number of the app's data files, sent as the @c metrickit.disk_space.data_file_count
    /// gauge.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceDataFileCount = 1ULL << 26,
    /// The size of the app's cache folder, sent as the @c metrickit.disk_space.cache_folder_size
    /// gauge in bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceCacheFolderSize = 1ULL << 27,
    /// The size of the app's cloned files, sent as the @c metrickit.disk_space.clone_size gauge in
    /// bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceCloneSize = 1ULL << 28,
    /// The disk space the app uses, sent as the @c metrickit.disk_space.total_used gauge in bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceTotalUsed = 1ULL << 29,
    /// The capacity of the device's disk, sent as the @c metrickit.disk_space.total_capacity gauge
    /// in bytes.
    /// @note Requires iOS 26 or macOS 26.
    SentryObjCMetricKitMetricReportDiskSpaceTotalCapacity = 1ULL << 30,
    /// Normal exits of the app in the foreground, sent as the @c metrickit.exit.fg.normal count.
    SentryObjCMetricKitMetricReportExitForegroundNormal = 1ULL << 31,
    /// Foreground exits for exceeding the memory limit, sent as the
    /// @c metrickit.exit.fg.memory_resource_limit count.
    SentryObjCMetricKitMetricReportExitForegroundMemoryResourceLimit = 1ULL << 32,
    /// Foreground exits for invalid memory access, sent as the @c metrickit.exit.fg.bad_access
    /// count.
    SentryObjCMetricKitMetricReportExitForegroundBadAccess = 1ULL << 33,
    /// Abnormal foreground exits, sent as the @c metrickit.exit.fg.abnormal count.
    SentryObjCMetricKitMetricReportExitForegroundAbnormal = 1ULL << 34,
    /// Foreground exits for an illegal instruction, sent as the
    /// @c metrickit.exit.fg.illegal_instruction count.
    SentryObjCMetricKitMetricReportExitForegroundIllegalInstruction = 1ULL << 35,
    /// Foreground exits by the watchdog, sent as the @c metrickit.exit.fg.watchdog count.
    SentryObjCMetricKitMetricReportExitForegroundWatchdog = 1ULL << 36,
    /// Normal exits of the app in the background, sent as the @c metrickit.exit.bg.normal count.
    SentryObjCMetricKitMetricReportExitBackgroundNormal = 1ULL << 37,
    /// Background exits for exceeding the memory limit, sent as the
    /// @c metrickit.exit.bg.memory_resource_limit count.
    SentryObjCMetricKitMetricReportExitBackgroundMemoryResourceLimit = 1ULL << 38,
    /// Background exits for exceeding the CPU limit, sent as the
    /// @c metrickit.exit.bg.cpu_resource_limit count.
    SentryObjCMetricKitMetricReportExitBackgroundCPUResourceLimit = 1ULL << 39,
    /// Background exits under memory pressure, sent as the @c metrickit.exit.bg.memory_pressure
    /// count.
    SentryObjCMetricKitMetricReportExitBackgroundMemoryPressure = 1ULL << 40,
    /// Background exits for invalid memory access, sent as the @c metrickit.exit.bg.bad_access
    /// count.
    SentryObjCMetricKitMetricReportExitBackgroundBadAccess = 1ULL << 41,
    /// Abnormal background exits, sent as the @c metrickit.exit.bg.abnormal count.
    SentryObjCMetricKitMetricReportExitBackgroundAbnormal = 1ULL << 42,
    /// Background exits for an illegal instruction, sent as the
    /// @c metrickit.exit.bg.illegal_instruction count.
    SentryObjCMetricKitMetricReportExitBackgroundIllegalInstruction = 1ULL << 43,
    /// Background exits by the watchdog, sent as the @c metrickit.exit.bg.watchdog count.
    SentryObjCMetricKitMetricReportExitBackgroundWatchdog = 1ULL << 44,
    /// Background exits for holding a file lock while suspended, sent as the
    /// @c metrickit.exit.bg.suspended_with_locked_file count.
    SentryObjCMetricKitMetricReportExitBackgroundSuspendedWithLockedFile = 1ULL << 45,
    /// Background exits for a background task that ran out of time, sent as the
    /// @c metrickit.exit.bg.background_task_timeout count.
    SentryObjCMetricKitMetricReportExitBackgroundTaskTimeout = 1ULL << 46,
    /// The time the app spent hitching during animations, sent as the
    /// @c metrickit.animation.total_hitch_time distribution in seconds.
    /// @note Requires iOS 27 or macOS 27.
    SentryObjCMetricKitMetricReportAnimationTotalHitchTime = 1ULL << 47,
    /// The time the app spent animating, sent as the
    /// @c metrickit.animation.total_animation_time distribution in seconds.
    /// @note Requires iOS 27 or macOS 27.
    SentryObjCMetricKitMetricReportAnimationTotalAnimationTime = 1ULL << 48,
    /// The frame rate of a Metal layer, sent as the @c metrickit.metal.frames_per_second gauge in
    /// frames per second with the layer's name as the @c metal.layer_name attribute.
    /// @note Requires iOS 27 or macOS 27.
    SentryObjCMetricKitMetricReportMetalFramesPerSecond = 1ULL << 49,
    /// The frames a Metal layer drew, sent as the @c metrickit.metal.frame_count count with the
    /// layer's name as the @c metal.layer_name attribute.
    /// @note Requires iOS 27 or macOS 27.
    SentryObjCMetricKitMetricReportMetalFrameCount = 1ULL << 50,
    /// The time a Metal layer was drawing, sent as the @c metrickit.metal.active_drawing_duration
    /// distribution in seconds with the layer's name as the @c metal.layer_name attribute.
    /// @note Requires iOS 27 or macOS 27.
    SentryObjCMetricKitMetricReportMetalActiveDrawingDuration = 1ULL << 51,
    /// Every metric report above.
    SentryObjCMetricKitMetricReportAll = (1ULL << 52) - 1,
};

#endif // __has_include(<MetricKit/MetricKit.h>) && !TARGET_OS_TV
