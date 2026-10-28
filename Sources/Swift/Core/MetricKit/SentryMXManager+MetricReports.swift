// MetricManager only exists in the SDKs of Xcode 27 and later, and doesn't report metrics on
// visionOS.
#if (os(iOS) || os(macOS)) && compiler(>=6.4)
internal import _SentryPrivate
import Foundation
import MetricKit

/// Delivers the metric reports of `MetricManager`, so tests can provide their own reports.
@available(iOS 27.0, macOS 27.0, *)
protocol SentryMetricReportSource: Sendable {
    func makeMetricReports() -> any AsyncSequence<MetricKit.MetricReport, Never>
}

@available(iOS 27.0, macOS 27.0, *)
extension MetricManager: SentryMetricReportSource {
    func makeMetricReports() -> any AsyncSequence<MetricKit.MetricReport, Never> {
        metricReports
    }
}

/// Sends the values of `MetricManager` metric reports as Sentry metrics, with the same names, types
/// and units as the values of legacy metric payloads.
@available(iOS 27.0, macOS 27.0, *)
extension SentryMXManager {
    func receiveMetricReports(from source: SentryMetricReportSource) {
        let task = Task { [weak self] in
            for await report in source.makeMetricReports() {
                guard let self, !Task.isCancelled else {
                    return
                }
                self.process(metricReport: report)
            }
        }
        replaceMetricReportsTask(with: task)
    }

    func pauseMetricReports() {
        replaceMetricReportsTask(with: nil)
    }

    func process(metricReport report: MetricKit.MetricReport) {
        SentrySDKLog.debug("Processing MetricKit metric report from \(report.timeRange.start) to \(report.timeRange.end)")
        // The full day entry has the values of the whole report. The other entries split them by
        // the states of the enabled state reporting domains, which the SDK doesn't enable.
        // `fullDayEntry` traps when there are no entries.
        guard !report.intervalEntries.isEmpty else {
            SentrySDKLog.debug("MetricKit metric report has no interval entries, skipping it")
            return
        }
        let context = metricContext(of: report)
        for result in report.intervalEntries.fullDayEntry.values {
            record(result, context)
        }
    }

    private func metricContext(of report: MetricKit.MetricReport) -> MetricContext {
        let environment = report.environment
        let osVersion = environment?.osVersion.number
        return metricContext(
            begin: report.timeRange.start,
            end: report.timeRange.end,
            appVersion: environment?.latestApplicationVersion ?? "",
            appBuild: environment?.applicationBuildVersion ?? "",
            includesMultipleApplicationVersions: environment?.includesMultipleApplicationVersions ?? false,
            osVersion: osVersion?.isEmpty == false ? osVersion : nil
        )
    }

    // MARK: - Recording

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func record(_ result: MetricResult, _ context: MetricContext) {
        switch result {
        case .cpuTime(let cpuTime):
            recordDistribution(.cpuCumulativeTime, cpuTime.value.converted(to: .seconds).value, unit: .second, context)
        case .cpuInstructionsCount(let instructions):
            recordDistribution(.cpuCumulativeInstructions, Double(instructions.value), unit: nil, context)
        case .gpuTime(let gpuTime):
            recordDistribution(.gpuCumulativeTime, gpuTime.value.converted(to: .seconds).value, unit: .second, context)
        case .totalWiFiUpload(let upload):
            recordDistribution(.networkWifiUpload, upload.value.converted(to: .bytes).value, unit: .byte, context)
        case .totalWiFiDownload(let download):
            recordDistribution(.networkWifiDownload, download.value.converted(to: .bytes).value, unit: .byte, context)
        case .logicalDiskWrites(let writes):
            recordDistribution(.diskIOLogicalWrites, writes.value.converted(to: .bytes).value, unit: .byte, context)
        case .hitchTime(let hitchTime):
            recordGauge(.animationHitchTimeRatio, Self.ratio(fromHitchTimeRatio: Measurement(value: hitchTime.ratio.value, unit: hitchTime.ratio.unit as Unit)), unit: .ratio, context)
            recordDistribution(.animationTotalHitchTime, hitchTime.totalHitchTime.converted(to: .seconds).value, unit: .second, context)
            recordDistribution(.animationTotalAnimationTime, hitchTime.totalAnimationTime.converted(to: .seconds).value, unit: .second, context)
        case .metalFrameRate(let frameRate):
            let layerContext = context.adding(attributes: ["metal.layer_name": frameRate.layerName])
            recordGauge(.metalFramesPerSecond, frameRate.framesPerSecond.converted(to: .hertz).value, unit: .generic("fps"), layerContext)
            recordCount(.metalFrameCount, frameRate.frameCount, layerContext)
            recordDistribution(.metalActiveDrawingDuration, frameRate.activeDrawingDuration.converted(to: .seconds).value, unit: .second, layerContext)
        case .foregroundTermination(let terminations):
            recordForegroundTerminations(terminations, context)
        case .backgroundTermination(let terminations):
            recordBackgroundTerminations(terminations, context)
        #if !os(macOS) && !targetEnvironment(macCatalyst)
        case .totalForegroundTime(let time):
            recordDistribution(.appTimeForeground, time.value.converted(to: .seconds).value, unit: .second, context)
        case .totalBackgroundTime(let time):
            recordDistribution(.appTimeBackground, time.value.converted(to: .seconds).value, unit: .second, context)
        case .totalBackgroundAudioTime(let time):
            recordDistribution(.appTimeBackgroundAudio, time.value.converted(to: .seconds).value, unit: .second, context)
        case .totalBackgroundLocationTime(let time):
            recordDistribution(.appTimeBackgroundLocation, time.value.converted(to: .seconds).value, unit: .second, context)
        case .totalCellularUpload(let upload):
            recordDistribution(.networkCellularUpload, upload.value.converted(to: .bytes).value, unit: .byte, context)
        case .totalCellularDownload(let download):
            recordDistribution(.networkCellularDownload, download.value.converted(to: .bytes).value, unit: .byte, context)
        case .locationActivityTime(let location):
            recordLocationActivity(location, context)
        case .peakMemory(let memory):
            recordGauge(.memoryPeakUsage, memory.value.converted(to: .bytes).value, unit: .byte, context)
        case .suspendedMemory(let memory):
            recordGauge(.memoryAverageSuspended, memory.value.average.converted(to: .bytes).value, unit: .byte, context)
        case .pixelLuminance(let luminance):
            recordGauge(.displayAveragePixelLuminance, luminance.value.average.converted(to: .baseUnit()).value, unit: .generic("apl"), context)
        case .totalFileCount(let fileCount):
            recordGauge(.diskSpaceBinaryFileCount, Double(fileCount.binaryFileCount), unit: nil, context)
            recordGauge(.diskSpaceDataFileCount, Double(fileCount.dataFileCount), unit: nil, context)
        case .totalFileSize(let fileSize):
            recordGauge(.diskSpaceBinaryFileSize, fileSize.binaryFileSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceDataFileSize, fileSize.dataFileSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceCacheFolderSize, fileSize.cacheFolderSize.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceCloneSize, fileSize.cloneSize.converted(to: .bytes).value, unit: .byte, context)
        case .totalDiskSpaceCapacity(let diskSpace):
            recordGauge(.diskSpaceTotalUsed, diskSpace.spaceUsed.converted(to: .bytes).value, unit: .byte, context)
            recordGauge(.diskSpaceTotalCapacity, diskSpace.capacity.converted(to: .bytes).value, unit: .byte, context)
        case .cellularConditionTime:
            // A histogram, which legacy payloads don't send either.
            break
        #endif // !os(macOS) && !targetEnvironment(macCatalyst)
        case .hangTime, .timeToFirstDraw, .applicationResumeTime, .optimizedTimeToFirstDraw, .extendedLaunch:
            // Histograms, which legacy payloads don't send either.
            break
        case .signpostInterval:
            // Signpost metrics describe the app's own intervals, which the SDK doesn't send.
            break
        @unknown default:
            SentrySDKLog.debug("Unsupported MetricKit metric result, skipping it")
        }
    }

    #if !os(macOS) && !targetEnvironment(macCatalyst)
    private func recordLocationActivity(_ location: LocationActivityTimeMetric, _ context: MetricContext) {
        recordDistribution(.locationBestAccuracyTime, location.bestAccuracy.converted(to: .seconds).value, unit: .second, context)
        recordDistribution(.locationBestAccuracyForNavigationTime, location.bestAccuracyForNavigation.converted(to: .seconds).value, unit: .second, context)
        recordDistribution(.locationNearestTenMetersTime, location.tenMeters.converted(to: .seconds).value, unit: .second, context)
        recordDistribution(.locationHundredMetersTime, location.oneHundredMeter.converted(to: .seconds).value, unit: .second, context)
        recordDistribution(.locationKilometerTime, location.oneKilometer.converted(to: .seconds).value, unit: .second, context)
        recordDistribution(.locationThreeKilometersTime, location.threeKilometers.converted(to: .seconds).value, unit: .second, context)
    }
    #endif // !os(macOS) && !targetEnvironment(macCatalyst)

    private func recordForegroundTerminations(_ terminations: ForegroundTerminationMetric, _ context: MetricContext) {
        recordCount(.exitForegroundNormal, terminations.normalTerminationCount, context)
        recordCount(.exitForegroundMemoryResourceLimit, terminations.memoryLimitTerminationCount, context)
        recordCount(.exitForegroundBadAccess, terminations.badAccessTerminationCount, context)
        recordCount(.exitForegroundAbnormal, terminations.abnormalTerminationCount, context)
        recordCount(.exitForegroundIllegalInstruction, terminations.illegalInstructionTerminationCount, context)
        recordCount(.exitForegroundWatchdog, terminations.watchdogTerminationCount, context)
    }

    private func recordBackgroundTerminations(_ terminations: BackgroundTerminationMetric, _ context: MetricContext) {
        recordCount(.exitBackgroundNormal, terminations.normalTerminationCount, context)
        recordCount(.exitBackgroundMemoryResourceLimit, terminations.memoryLimitTerminationCount, context)
        recordCount(.exitBackgroundCPUResourceLimit, terminations.highCPUTerminationCount, context)
        recordCount(.exitBackgroundMemoryPressure, terminations.systemPressureTerminationCount, context)
        recordCount(.exitBackgroundBadAccess, terminations.badAccessTerminationCount, context)
        recordCount(.exitBackgroundAbnormal, terminations.abnormalTerminationCount, context)
        recordCount(.exitBackgroundIllegalInstruction, terminations.illegalInstructionTerminationCount, context)
        recordCount(.exitBackgroundWatchdog, terminations.watchdogTerminationCount, context)
        recordCount(.exitBackgroundSuspendedWithLockedFile, terminations.fileLockTerminationCount, context)
        recordCount(.exitBackgroundTaskTimeout, terminations.taskTimeoutTerminationCount, context)
    }
}

#endif // (os(iOS) || os(macOS)) && compiler(>=6.4)
