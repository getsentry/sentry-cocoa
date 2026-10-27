/// Selects how MetricKit hang call stack trees are reported.
public enum SentryMetricKitHangReportingMode {
    /// Preserves all sampled frames and their tree metadata.
    case legacy
    /// Attaches aggregated call trees as a flame graph for server-side processing.
    case flamegraphAttachment

    /// Resolves the mode from its case name, as passed by hybrid SDKs through `Options(dictionary:)`.
    static func fromName(_ name: String?) -> SentryMetricKitHangReportingMode? {
        switch name {
        case "legacy":
            return .legacy
        case "flamegraphAttachment":
            return .flamegraphAttachment
        default:
            return nil
        }
    }
}

/// Experimental options for the MetricKit integration.
public final class SentryMetricKitOptions {
    #if canImport(MetricKit) && !os(tvOS)
    #if SDK_V10
    /// The MetricKit diagnostic reports the SDK captures as events.
    ///
    /// An empty set disables the MetricKit integration.
    ///
    /// - Note: Defaults to ``SentryMetricKit/DiagnosticReport/cpuException``,
    ///   ``SentryMetricKit/DiagnosticReport/diskWriteException``,
    ///   ``SentryMetricKit/DiagnosticReport/hang`` and
    ///   ``SentryMetricKit/DiagnosticReport/appLaunch``.
    public var enabledDiagnosticReports: Set<SentryMetricKit.DiagnosticReport> = [.cpuException, .diskWriteException, .hang, .appLaunch]
    #else
    /// The MetricKit diagnostic reports the SDK captures as events.
    ///
    /// A non-empty set enables the MetricKit integration and captures exactly these reports,
    /// regardless of ``SentrySDKOptions/enableMetricKit``. When the set is empty,
    /// ``SentrySDKOptions/enableMetricKit`` decides whether the integration is enabled.
    ///
    /// - Note: Defaults to an empty set.
    public var enabledDiagnosticReports: Set<SentryMetricKit.DiagnosticReport> = []
    #endif // SDK_V10

    /// The MetricKit metric reports the SDK sends as Sentry metrics.
    ///
    /// A non-empty set enables the MetricKit integration, even when no diagnostic reports are
    /// enabled. Use `.all` to send every metric report.
    ///
    /// MetricKit delivers metric payloads about once a day, and each enabled report adds up to one
    /// metric per payload, which counts towards your metrics quota.
    ///
    /// MetricKit only delivers metric payloads on iOS and visionOS, so this has no effect on macOS.
    ///
    /// - Note: Defaults to an empty set.
    public var enabledMetricReports: Set<SentryMetricKit.MetricReport> = []
    #endif // canImport(MetricKit) && !os(tvOS)

    /// How hang diagnostics are reported. Defaults to `.legacy`.
    /// Configure this option before starting the SDK. Other diagnostic types are unaffected.
    public var hangReportingMode: SentryMetricKitHangReportingMode = .legacy

    #if canImport(MetricKit) && !os(tvOS)
    /// Applies MetricKit options from the options dictionary, primarily for hybrid SDK configuration.
    ///
    /// Reads `metricKitHangReportingMode` and the nested `metrickit` dictionary. Report names in
    /// `enabledDiagnosticReports` that the SDK doesn't know are ignored.
    func apply(optionsDictionary: [String: Any]) {
        if let hangReportingMode = SentryMetricKitHangReportingMode.fromName(optionsDictionary["metricKitHangReportingMode"] as? String) {
            self.hangReportingMode = hangReportingMode
        }

        guard let dictionary = optionsDictionary["metrickit"] as? [String: Any] else {
            return
        }
        if let reports = SentryDictionaryDecoder.strings(dictionary, "enabledDiagnosticReports") {
            enabledDiagnosticReports = Set(reports.compactMap(SentryMetricKit.DiagnosticReport.init(dictionaryValue:)))
        }
    }
    #endif // canImport(MetricKit) && !os(tvOS)
}
