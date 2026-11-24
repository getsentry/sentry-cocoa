/// The one place between the event sources and the core SDK.
///
/// Every source submits its reports here, and the coordinator decides what reaches the next sink.
/// It tells the sources apart only by the `source` and the `runId` of their reports:
///
/// - A fatal report it lets through is recorded with its run, so a later report about the same
///   run is recognized.
/// - A MetricKit crash diagnostic of a run the crash handler already reported is dropped, because
///   the crash handler's event already describes that crash. Other diagnostics always pass, as
///   the crash handler doesn't report hangs, CPU, disk write, launch or memory diagnostics.
///
/// Holding a watchdog termination report for a matching diagnostic and merging the two belongs
/// here as well and follows separately.
final class SentryEventSourceCoordinator: SentryEventSourceSink {
    private let downstream: SentryEventSourceSink
    /// Records the runs that ended fatally, or `nil` when the SDK has nowhere to keep them, in
    /// which case every report passes.
    private let fatalRunRecordStore: SentryFatalRunRecordStore?
    private let dateProvider: SentryCurrentDateProvider

    /// - Parameter downstream: The sink that takes the reports the coordinator lets through.
    init(downstream: SentryEventSourceSink, fatalRunRecordStore: SentryFatalRunRecordStore?, dateProvider: SentryCurrentDateProvider) {
        self.downstream = downstream
        self.fatalRunRecordStore = fatalRunRecordStore
        self.dateProvider = dateProvider
    }

    var isAvailable: Bool {
        downstream.isAvailable
    }

    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        if let reporter = reporterOfRun(describedBy: report) {
            // Accepted rather than withdrawn: the report was handled, and the source must not
            // submit it again.
            SentrySDKLog.debug("Dropped the \(report.source.rawValue) report for run \(report.runId?.rawValue ?? "unknown"), which \(reporter.rawValue) already reported")
            return .accepted
        }

        let result = downstream.submit(report, beforeAccepting: beforeAccepting)
        SentrySDKLog.debug("Report of event source \(report.source.rawValue) for run \(report.runId?.rawValue ?? "unknown") was \(result.logDescription)")

        if result == .accepted, case .fatal = report.kind, let runId = report.runId {
            fatalRunRecordStore?.add(SentryFatalRunRecord(runId: runId, reportedBy: report.source, date: dateProvider.date()))
        }
        return result
    }

    /// The source that already reported the end of the run a diagnostic describes, when the
    /// diagnostic would duplicate that source's fatal event.
    private func reporterOfRun(describedBy report: SentryEventSourceReport) -> SentryEventSource? {
        guard case .diagnostic(_, .crash) = report.kind,
              let runId = report.runId,
              let record = fatalRunRecordStore?.record(forRunId: runId),
              record.reportedBy == .crashHandler else {
            return nil
        }
        return record.reportedBy
    }
}

private extension SentryEventSourceSubmissionResult {
    var logDescription: String {
        switch self {
        case .accepted:
            return "accepted"
        case .unavailable:
            return "not taken, because the SDK can't take reports right now"
        case .withdrawn:
            return "withdrawn by the source"
        }
    }
}
