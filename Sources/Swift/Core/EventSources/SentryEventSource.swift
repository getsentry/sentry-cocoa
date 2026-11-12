/// Identifies the pipeline a ``SentryEventSourceReport`` came through.
///
/// An event source is a part of the SDK that learns how a run of the app went or ended. It
/// doesn't capture events itself: it converts what it knows into a report and hands it to a
/// ``SentryEventSourceSink``, so the reports of all sources pass through one place before any of
/// them reaches the hub and the client. The sink uses this identifier to process a report the way
/// its pipeline needs, and the run ID of the report to find the reports of other pipelines that
/// describe the same run.
enum SentryEventSource: String {
    /// The crash handler, which is SentryCrash before V10 and KSCrash from V10 on. It reports the
    /// crashes it recorded in a previous run.
    case crashHandler
    /// The watchdog termination integration, which reports a previous run that ended without any
    /// other explanation. (This will be killed when metrickit watchdog events are fully implemented)
    case watchdogTermination
    /// MetricKit, which reports the diagnostics the OS recorded, such as crashes, hangs and
    /// memory exceptions.
    case metricKit
}
