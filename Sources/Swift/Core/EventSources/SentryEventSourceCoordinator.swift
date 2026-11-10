/// The one place between the event sources and the core SDK.
///
/// Every source submits its reports here, and the coordinator decides what reaches the next sink.
/// It forwards each report unchanged for now. Matching the reports of one run and merging them
/// into one event belongs here, so neither the sources nor the core SDK have to know about it.
/// The coordinator tells the sources apart only by the `source` and the `runId` of their reports.
final class SentryEventSourceCoordinator: SentryEventSourceSink {
    private let downstream: SentryEventSourceSink

    /// - Parameter downstream: The sink that takes the reports the coordinator lets through.
    init(downstream: SentryEventSourceSink) {
        self.downstream = downstream
    }

    var isAvailable: Bool {
        downstream.isAvailable
    }

    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        let result = downstream.submit(report, beforeAccepting: beforeAccepting)
        SentrySDKLog.debug("Report of event source \(report.source.rawValue) for run \(report.runId ?? "unknown") was \(result.logDescription)")
        return result
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
