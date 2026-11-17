/// The outcome of submitting a ``SentryEventSourceReport`` to a ``SentryEventSourceSink``.
@_spi(Private) @objc public enum SentryEventSourceSubmissionResult: Int {
    /// The sink took the report, including when the SDK then discards its event on purpose. The
    /// source must not submit the report again.
    case accepted
    /// The sink can't take reports right now, for example because the SDK has no client. The
    /// source may submit the report again later.
    case unavailable
    /// The source withdrew the report in `beforeAccepting`.
    case withdrawn
}

/// Takes the reports of the event sources.
///
/// The sources depend on this protocol instead of the hub or the client. That keeps the core SDK
/// unaware of where an event comes from, and it gives the SDK one place to match and merge the
/// reports of different sources before they become events.
protocol SentryEventSourceSink {
    /// Whether the sink can take reports right now. A source checks it before work that only
    /// makes sense when the report can be taken, such as converting a stored crash report.
    var isAvailable: Bool { get }

    /// Hands a report to the sink on the calling thread.
    ///
    /// - Parameter beforeAccepting: Called once the sink can take the report, immediately before it
    ///   does. Returning `false` withdraws the report. A source uses it for bookkeeping that must
    ///   only happen for a report the sink is about to take.
    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult
}

extension SentryEventSourceSink {
    /// Hands a report to the sink on the calling thread.
    @discardableResult
    func submit(_ report: SentryEventSourceReport) -> SentryEventSourceSubmissionResult {
        submit(report, beforeAccepting: { true })
    }
}
