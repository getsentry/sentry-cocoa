internal import _SentryPrivate
import Foundation

/// Says that two event sources report on the same run at different times, and how their reports
/// become one event.
///
/// The sources don't know about each other, and neither knows that its report is held or merged.
/// An orchestrator is the one place that names both, and the ``SentryEventSourceCoordinator`` applies
/// it: it holds the fatal report of `heldSource` for `holdDuration`, and when `awaitedSource`
/// reports how the same run ended within that time, `merge` makes one event of the two.
///
/// Another pair of sources that describe the same thing, such as the hang tracker and MetricKit
/// for a hang, gets its own orchestrator here instead of code in either integration.
struct SentryEventSourceOrchestrator {
    /// The source that reports early, whose fatal report waits.
    let heldSource: SentryEventSource
    /// The source that reports late, whose report of the run's end completes the held one.
    let awaitedSource: SentryEventSource
    /// How long the held report waits at most.
    let holdDuration: TimeInterval
    /// Makes one event of the held report and the awaited source's report of the same run.
    let merge: (_ held: SentryHeldFatalReport, _ awaited: SentryEventSourceReport, _ runEnd: SentryEventSourceReport.RunEnd) -> Event
}

extension SentryEventSourceOrchestrator {
    /// A watchdog termination event has no stack trace and only infers why the run ended.
    /// MetricKit knows both, but reports after the launch.
    ///
    /// MetricKit doesn't promise when, or whether, it delivers a diagnostic, so the duration only
    /// caps the delay of a watchdog termination event. Dogfooding measures how long MetricKit
    /// takes after a launch, and the value follows that.
    static let watchdogTerminationAwaitingMetricKit = SentryEventSourceOrchestrator(
        heldSource: .watchdogTermination,
        awaitedSource: .metricKit,
        holdDuration: 30,
        merge: SentryHeldFatalReportEnrichment.enrich
    )

    /// The orchestrators whose awaited source reports with these options. Holding a report for a
    /// source that never reports would only delay it.
    ///
    /// Decided from the options and not by the integrations as they install, so it is known
    /// before the first of them reports and doesn't depend on the order they install in.
    static func enabled(for options: Options) -> [SentryEventSourceOrchestrator] {
        #if os(iOS) || os(macOS) || os(visionOS)
        if SentryMetricKitIntegration<SentryDependencyContainer>.reportsRunEnds(with: options) {
            return [.watchdogTerminationAwaitingMetricKit]
        }
        #endif // os(iOS) || os(macOS) || os(visionOS)
        return []
    }
}
