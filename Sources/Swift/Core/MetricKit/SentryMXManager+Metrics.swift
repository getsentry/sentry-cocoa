#if os(iOS) || os(visionOS)
import Foundation
import MetricKit

/// Sends the values of MetricKit metric payloads as Sentry metrics.
extension SentryMXManager {
    /// The timestamp and attributes every metric of a payload shares.
    private struct MetricPayloadContext {
        let timestamp: Date
        let attributes: [String: SentryAttributeValue]
        let overridingAttributes: [String: SentryAttributeValue]
    }

    func process(metricPayload payload: MXMetricPayload) {
        SentrySDKLog.debug("Processing MetricKit metric payload from \(payload.timeStampBegin) to \(payload.timeStampEnd)")
        let context = metricPayloadContext(for: payload)
        recordUsageMetrics(of: payload, context)
        recordResourceMetrics(of: payload, context)
        recordExitMetrics(of: payload, context)
    }

    // MARK: - Metric Groups

    /// Records how long the app used the CPU, the GPU, the foreground and background, and location.
    private func recordUsageMetrics(of payload: MXMetricPayload, _ context: MetricPayloadContext) {
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
    private func recordResourceMetrics(of payload: MXMetricPayload, _ context: MetricPayloadContext) {
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
    private func recordExitMetrics(of payload: MXMetricPayload, _ context: MetricPayloadContext) {
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

    private func metricPayloadContext(for payload: MXMetricPayload) -> MetricPayloadContext {
        // A payload aggregates its values over the reporting interval without saying when they
        // happened, so each value is placed in the middle of the interval. This is what spreading
        // a single sample across the interval yields for histograms as well.
        let interval = payload.timeStampEnd.timeIntervalSince(payload.timeStampBegin)
        let timestamp = payload.timeStampBegin.addingTimeInterval(interval / 2)

        var attributes: [String: SentryAttributeValue] = [:]
        var overridingAttributes: [String: SentryAttributeValue] = [:]

        // When the interval spans an app update, MetricKit only reports the latest version, which
        // doesn't describe all values. The metrics keep the running release then.
        if payload.includesMultipleApplicationVersions {
            SentrySDKLog.debug("MetricKit metric payload spans multiple app versions, keeping the current release")
        } else {
            // MetricKit declares these as nonnull, but they bridge to empty strings when missing.
            let appVersion = payload.latestApplicationVersion
            let appBuild = payload.metaData?.applicationBuildVersion ?? ""
            if !appVersion.isEmpty {
                attributes["app.version"] = appVersion
            }
            if !appBuild.isEmpty {
                attributes["app.build"] = appBuild
            }
            // Scope enrichment sets the running release, so a previous one has to override it.
            if let releaseName = releaseName(appVersion: appVersion, appBuild: appBuild) {
                overridingAttributes["sentry.release"] = releaseName
            }
        }

        // Scope enrichment sets the running OS version, which can be newer than the one the
        // values were recorded on.
        if let metaData = payload.metaData, let osVersion = Self.parseOSVersion(metaData.osVersion) {
            overridingAttributes["os.version"] = osVersion.version
        }

        return MetricPayloadContext(timestamp: timestamp, attributes: attributes, overridingAttributes: overridingAttributes)
    }

    // MARK: - Recording

    private func recordDistribution(_ report: MetricReport, _ value: @autoclosure () -> Double?, unit: SentryUnit?, _ context: MetricPayloadContext) {
        guard enabledMetricReports.contains(report), let value = value() else {
            return
        }
        metricsApi.distribution(
            key: report.name,
            value: value,
            unit: unit,
            timestamp: context.timestamp,
            attributes: context.attributes,
            overridingAttributes: context.overridingAttributes
        )
    }

    private func recordGauge(_ report: MetricReport, _ value: @autoclosure () -> Double?, unit: SentryUnit?, _ context: MetricPayloadContext) {
        guard enabledMetricReports.contains(report), let value = value() else {
            return
        }
        metricsApi.gauge(
            key: report.name,
            value: value,
            unit: unit,
            timestamp: context.timestamp,
            attributes: context.attributes,
            overridingAttributes: context.overridingAttributes
        )
    }

    private func recordCount(_ report: MetricReport, _ value: Int, _ context: MetricPayloadContext) {
        // A count of zero doesn't change the sum, so it is left out to save volume.
        guard enabledMetricReports.contains(report), value > 0 else {
            return
        }
        metricsApi.count(
            key: report.name,
            value: UInt(value),
            timestamp: context.timestamp,
            attributes: context.attributes,
            overridingAttributes: context.overridingAttributes
        )
    }

    // MARK: - Units

    /// Converts MetricKit's dimensionless instruction measurement to a number of instructions.
    static func instructionCount(_ measurement: Measurement<Unit>) -> Double? {
        switch measurement.unit.symbol {
        case "instructions":
            return measurement.value
        case "kiloinstructions":
            return measurement.value * 1_000
        default:
            SentrySDKLog.warning("Unexpected MetricKit CPU instructions unit '\(measurement.unit.symbol)', skipping metric")
            return nil
        }
    }

    /// Converts MetricKit's hitch time ratio, reported in milliseconds of hitches per second, to a
    /// plain ratio.
    static func ratio(fromHitchTimeRatio measurement: Measurement<Unit>) -> Double? {
        switch measurement.unit.symbol {
        case "ms per s":
            return measurement.value / 1_000
        default:
            SentrySDKLog.warning("Unexpected MetricKit hitch time ratio unit '\(measurement.unit.symbol)', skipping metric")
            return nil
        }
    }
}

#endif // os(iOS) || os(visionOS)
