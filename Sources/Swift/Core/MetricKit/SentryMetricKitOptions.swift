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

/// Experimental options for MetricKit diagnostics. Requires `Options.enableMetricKit`.
public final class SentryMetricKitOptions {
    /// How hang diagnostics are reported. Defaults to `.legacy`.
    /// Configure this option before starting the SDK. Other diagnostic types are unaffected.
    public var hangReportingMode: SentryMetricKitHangReportingMode = .legacy
}
