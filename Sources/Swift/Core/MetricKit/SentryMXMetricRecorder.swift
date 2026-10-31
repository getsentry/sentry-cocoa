#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// Sends the values of MetricKit metrics as Sentry metrics.
///
/// Both MetricKit APIs map their values to `SentryMetricKit.MetricReport` and record them with the
/// same recorder, so a value gets the same name, type and unit regardless of the API that delivered
/// it.
final class SentryMXMetricRecorder {
    typealias MetricReport = SentryMetricKit.MetricReport

    /// The timestamp, trace ID and attributes every metric of a payload or report shares.
    struct Context {
        let timestamp: Date
        let traceId: SentryId
        let attributes: [String: SentryAttributeValue]

        /// The context with attributes that only describe some of the metrics, such as the Metal
        /// layer a frame rate was measured for.
        func adding(attributes additionalAttributes: [String: SentryAttributeValue]) -> Context {
            Context(
                timestamp: timestamp,
                traceId: traceId,
                attributes: attributes.merging(additionalAttributes) { _, additional in additional }
            )
        }
    }

    let enabledMetricReports: Set<MetricReport>
    let metricsApi: SentryInternalMetricsApi
    let releaseResolver: SentryMXReleaseResolver

    init(
        enabledMetricReports: Set<MetricReport>,
        metricsApi: SentryInternalMetricsApi = SentryMetricsApi(dependencies: SentryDependencyContainer.sharedInstance()),
        releaseName: String? = nil,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        self.enabledMetricReports = enabledMetricReports
        self.metricsApi = metricsApi
        self.releaseResolver = SentryMXReleaseResolver(releaseName: releaseName, bundleInfo: bundleInfo)
    }

    // MARK: - Context

    /// Builds the context of the values MetricKit aggregated from `begin` to `end`.
    ///
    /// - Parameters:
    ///   - appVersion: The latest app version of the interval, or an empty string when unknown.
    ///   - appBuild: The app build of the interval, or an empty string when unknown.
    ///   - osVersion: The OS version the values were recorded on, or `nil` when unknown.
    func context(
        begin: Date,
        end: Date,
        appVersion: String,
        appBuild: String,
        includesMultipleApplicationVersions: Bool,
        osVersion: String?
    ) -> Context {
        // MetricKit aggregates its values over the reporting interval without saying when they
        // happened, so each value is placed in the middle of the interval. This is what spreading
        // a single sample across the interval yields for histograms as well.
        let timestamp = begin.addingTimeInterval(end.timeIntervalSince(begin) / 2)

        var attributes: [String: SentryAttributeValue] = [:]

        // When the interval spans an app update, MetricKit only reports the latest version, which
        // doesn't describe all values. The metrics keep the running release then.
        if includesMultipleApplicationVersions {
            SentrySDKLog.debug("MetricKit metrics span multiple app versions, keeping the current release")
        } else {
            if !appVersion.isEmpty {
                attributes["app.version"] = appVersion
            }
            if !appBuild.isEmpty {
                attributes["app.build"] = appBuild
            }
            // Nil when the running release already describes the values or is a custom name.
            if let releaseName = releaseResolver.releaseName(appVersion: appVersion, appBuild: appBuild) {
                attributes["sentry.release"] = releaseName
            }
        }

        // The running OS version can be newer than the one the values were recorded on, so scope
        // enrichment leaves it out.
        if let osVersion {
            attributes["os.version"] = osVersion
        }

        // The values don't belong to the running trace. A trace of their own keeps the metrics of
        // one payload or report together.
        return Context(timestamp: timestamp, traceId: SentryId(), attributes: attributes)
    }

    // MARK: - Recording

    func recordDistribution(_ report: MetricReport, _ value: @autoclosure () -> Double?, unit: SentryUnit?, _ context: Context) {
        guard enabledMetricReports.contains(report), let value = value() else {
            return
        }
        metricsApi.distribution(
            key: report.name,
            value: value,
            unit: unit,
            timestamp: context.timestamp,
            traceId: context.traceId,
            attributes: context.attributes
        )
    }

    func recordGauge(_ report: MetricReport, _ value: @autoclosure () -> Double?, unit: SentryUnit?, _ context: Context) {
        guard enabledMetricReports.contains(report), let value = value() else {
            return
        }
        metricsApi.gauge(
            key: report.name,
            value: value,
            unit: unit,
            timestamp: context.timestamp,
            traceId: context.traceId,
            attributes: context.attributes
        )
    }

    func recordCount(_ report: MetricReport, _ value: Int, _ context: Context) {
        // A count of zero doesn't change the sum, so it is left out to save volume.
        guard enabledMetricReports.contains(report), value > 0 else {
            return
        }
        metricsApi.count(
            key: report.name,
            value: UInt(value),
            timestamp: context.timestamp,
            traceId: context.traceId,
            attributes: context.attributes
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

#endif // os(iOS) || os(macOS) || os(visionOS)
