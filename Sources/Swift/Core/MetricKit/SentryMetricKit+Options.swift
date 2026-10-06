#if canImport(MetricKit) && !os(tvOS)
extension SentryMetricKit {
    /// Configuration of the MetricKit integration.
    public struct Options: Equatable {
        #if SDK_V10
        /// The MetricKit diagnostic reports the SDK captures as events.
        ///
        /// An empty set disables the MetricKit integration.
        ///
        /// - Note: Defaults to ``SentryMetricKit/DiagnosticReport/cpuException``,
        ///   ``SentryMetricKit/DiagnosticReport/diskWriteException`` and
        ///   ``SentryMetricKit/DiagnosticReport/hang``.
        public var enabledDiagnosticReports: Set<SentryMetricKit.DiagnosticReport> = [.cpuException, .diskWriteException, .hang]
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
    }
}
#endif // canImport(MetricKit) && !os(tvOS)
