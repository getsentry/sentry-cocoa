/// Selects how MetricKit hang call stack trees are reported.
public enum SentryMetricKitHangReportingMode {
    /// Preserves all sampled frames and their tree metadata.
    case legacy
    /// Selects a representative stack using sample frequency, depth, and in-app frame quality.
    case culprit
}

/// Experimental options for MetricKit diagnostics. Requires `Options.enableMetricKit`.
public final class SentryMetricKitOptions {
    /// How hang diagnostics are reported. Defaults to `.legacy`.
    /// Configure this option before starting the SDK. Other diagnostic types are unaffected.
    public var hangReportingMode: SentryMetricKitHangReportingMode = .legacy
}
