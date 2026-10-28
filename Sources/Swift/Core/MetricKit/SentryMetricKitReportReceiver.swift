#if os(iOS) || os(macOS) || os(visionOS)

/// Receives the reports of one MetricKit API until paused.
///
/// `SentryMetricManager` only exists on xOS 27 and later, and stored properties can't be limited
/// to an OS version, so the integration stores it through this protocol.
protocol SentryMetricKitReportReceiver: AnyObject {
    func receiveReports()
    func pauseReports()
}

#endif // os(iOS) || os(macOS) || os(visionOS)
