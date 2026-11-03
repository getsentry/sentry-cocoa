#if os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))
import Foundation
import MetricKit

/// Sends the values of legacy MetricKit metric payloads as Sentry metrics.
extension SentryMXMetricRecorder {
    func record(metricPayload payload: MXMetricPayload) {
        SentrySDKLog.debug("Processing MetricKit metric payload from \(payload.timeStampBegin) to \(payload.timeStampEnd)")
        let context = metricPayloadContext(for: payload)
        recordUsageMetrics(of: payload, context)
        recordResourceMetrics(of: payload, context)
        recordExitMetrics(of: payload, context)
    }

    // MARK: - Metric Groups

    /// Records how long the app used the CPU, the GPU, the foreground and background, and location.
    private func recordUsageMetrics(of payload: MXMetricPayload, _ context: Context) {
        if let cpu = payload.cpuMetrics {
            recordDistribution(.cpuCumulativeTime, cpu.cumulativeCPUTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.cpuCumulativeInstructions, Self.instructionCount(cpu.cumulativeCPUInstructions), unit: nil, context)
        }
        if let gpu = payload.gpuMetrics {
            recordDistribution(.gpuCumulativeTime, gpu.cumulativeGPUTime.converted(to: .seconds).value, unit: .second, context)
        }
        if let appTime = payload.applicationTimeMetrics {
            recordDistribution(.appTimeForeground, appTime.cumulativeForegroundTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.appTimeBackground, appTime.cumulativeBackgroundTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.appTimeBackgroundAudio, appTime.cumulativeBackgroundAudioTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.appTimeBackgroundLocation, appTime.cumulativeBackgroundLocationTime.converted(to: .seconds).value, unit: .second, context)
        }
        if let location = payload.locationActivityMetrics {
            recordDistribution(.locationBestAccuracyTime, location.cumulativeBestAccuracyTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.locationBestAccuracyForNavigationTime, location.cumulativeBestAccuracyForNavigationTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.locationNearestTenMetersTime, location.cumulativeNearestTenMetersAccuracyTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.locationHundredMetersTime, location.cumulativeHundredMetersAccuracyTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.locationKilometerTime, location.cumulativeKilometerAccuracyTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.locationThreeKilometersTime, location.cumulativeThreeKilometersAccuracyTime.converted(to: .seconds).value, unit: .second, context)
        }
    }

    /// Records the network, disk, memory and display resources the app used.
    private func recordResourceMetrics(of payload: MXMetricPayload, _ context: Context) {
        if let network = payload.networkTransferMetrics {
            recordDistribution(.networkWifiUpload, network.cumulativeWifiUpload.converted(to: .bytes).value, unit: .byte, context)
            recordDistribution(.networkWifiDownload, network.cumulativeWifiDownload.converted(to: .bytes).value, unit: .byte, context)
            recordDistribution(.networkCellularUpload, network.cumulativeCellularUpload.converted(to: .bytes).value, unit: .byte, context)
            recordDistribution(.networkCellularDownload, network.cumulativeCellularDownload.converted(to: .bytes).value, unit: .byte, context)
        }
        if let diskIO = payload.diskIOMetrics {
            recordDistribution(.diskIOLogicalWrites, diskIO.cumulativeLogicalWrites.converted(to: .bytes).value, unit: .byte, context)
        }
        if let memory = payload.memoryMetrics {
            recordGauge(.memoryPeakUsage, memory.peakMemoryUsage.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.memoryAverageSuspended, memory.averageSuspendedMemory.averageMeasurement.converted(to: .bytes).value, unit: .byte, context)
        }
        if let display = payload.displayMetrics, let luminance = display.averagePixelLuminance {
            recordGauge(.displayAveragePixelLuminance, luminance.averageMeasurement.converted(to: .apl).value, unit: .generic("apl"), context)
        }
        if let animation = payload.animationMetrics {
            recordGauge(.animationScrollHitchTimeRatio, Self.ratio(fromHitchTimeRatio: animation.scrollHitchTimeRatio), unit: .ratio, context)
            // The iOS 26 metrics are only in the SDKs of Xcode 26, the first to ship Swift 6.2.
            #if compiler(>=6.2)
            if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                recordGauge(.animationHitchTimeRatio, Self.ratio(fromHitchTimeRatio: animation.hitchTimeRatio), unit: .ratio, context)
            }
            #endif // compiler(>=6.2)
        }
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), let diskSpace = payload.diskSpaceUsageMetrics {
            recordGauge(.diskSpaceBinaryFileSize, diskSpace.totalBinaryFileSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceBinaryFileCount, Double(diskSpace.totalBinaryFileCount), unit: nil, context)
            recordGauge(.diskSpaceDataFileSize, diskSpace.totalDataFileSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceDataFileCount, Double(diskSpace.totalDataFileCount), unit: nil, context)
            recordGauge(.diskSpaceCacheFolderSize, diskSpace.totalCacheFolderSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceCloneSize, diskSpace.totalCloneSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceTotalUsed, diskSpace.totalDiskSpaceUsedSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceTotalCapacity, diskSpace.totalDiskSpaceCapacity.converted(to: .bytes).value, unit: .byte, context)
        }
        #endif // compiler(>=6.2)
    }

    /// Records how often the app exited in the foreground and background, by reason.
    private func recordExitMetrics(of payload: MXMetricPayload, _ context: Context) {
        if let exits = payload.applicationExitMetrics {
            let foreground = exits.foregroundExitData
            recordCount(.exitForegroundNormal, foreground.cumulativeNormalAppExitCount, context)
            recordCount(.exitForegroundMemoryResourceLimit, foreground.cumulativeMemoryResourceLimitExitCount, context)
            recordCount(.exitForegroundBadAccess, foreground.cumulativeBadAccessExitCount, context)
            recordCount(.exitForegroundAbnormal, foreground.cumulativeAbnormalExitCount, context)
            recordCount(.exitForegroundIllegalInstruction, foreground.cumulativeIllegalInstructionExitCount, context)
            recordCount(.exitForegroundWatchdog, foreground.cumulativeAppWatchdogExitCount, context)

            let background = exits.backgroundExitData
            recordCount(.exitBackgroundNormal, background.cumulativeNormalAppExitCount, context)
            recordCount(.exitBackgroundMemoryResourceLimit, background.cumulativeMemoryResourceLimitExitCount, context)
            recordCount(.exitBackgroundCPUResourceLimit, background.cumulativeCPUResourceLimitExitCount, context)
            recordCount(.exitBackgroundMemoryPressure, background.cumulativeMemoryPressureExitCount, context)
            recordCount(.exitBackgroundBadAccess, background.cumulativeBadAccessExitCount, context)
            recordCount(.exitBackgroundAbnormal, background.cumulativeAbnormalExitCount, context)
            recordCount(.exitBackgroundIllegalInstruction, background.cumulativeIllegalInstructionExitCount, context)
            recordCount(.exitBackgroundWatchdog, background.cumulativeAppWatchdogExitCount, context)
            recordCount(.exitBackgroundSuspendedWithLockedFile, background.cumulativeSuspendedWithLockedFileExitCount, context)
            recordCount(.exitBackgroundTaskTimeout, background.cumulativeBackgroundTaskAssertionTimeoutExitCount, context)
        }
    }

    private func metricPayloadContext(for payload: MXMetricPayload) -> Context {
        // MetricKit declares these as nonnull, but they bridge to empty strings when missing.
        context(
            begin: payload.timeStampBegin,
            end: payload.timeStampEnd,
            appVersion: payload.latestApplicationVersion,
            appBuild: payload.metaData?.applicationBuildVersion ?? "",
            includesMultipleApplicationVersions: payload.includesMultipleApplicationVersions,
            osVersion: payload.metaData.flatMap { SentryMXDiagnostic.Metadata.parseOSVersion($0.osVersion)?.version }
        )
    }
}

#endif // os(iOS) || os(visionOS) || (os(macOS) && compiler(>=6.2))
