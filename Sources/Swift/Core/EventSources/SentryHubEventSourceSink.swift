internal import _SentryPrivate

/// The sink at the end of the chain, which captures a report on the current hub.
///
/// This is the only place where a report of an event source reaches the core SDK.
struct SentryHubEventSourceSink: SentryEventSourceSink {
    typealias Dependencies = CurrentHubProvider

    /// Resolves the current hub for every report, so the sink doesn't retain a hub across SDK
    /// restarts.
    let dependencies: Dependencies

    var isAvailable: Bool {
        dependencies.currentHub.getClient() != nil
    }

    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        // The hub and its client are read once and used for the whole submission, because a source
        // can submit from a background queue while the SDK closes or restarts. `beforeAccepting`
        // runs after that, so a hub that is replaced in the meantime doesn't receive a report it
        // wasn't prepared for.
        let hub = dependencies.currentHub
        guard let client = hub.getClient() else {
            return .unavailable
        }

        switch report.kind {
        case let .fatal(attachmentPaths, isRetainedOnFailure):
            let scope = Scope(scope: hub.scope)
            for attachmentPath in attachmentPaths {
                scope.addCrashReportAttachment(inPath: attachmentPath)
            }
            guard beforeAccepting() else {
                return .withdrawn
            }
            let eventId = hub.captureFatalEvent(report.event, scope: scope, preserveCrashedSessionOnFailure: isRetainedOnFailure)
            // An empty event ID is still final when the client dropped the event on purpose. It
            // only means the report wasn't taken when the client went away during the capture.
            return hub.isFatalEventCaptureResultTerminal(eventId, client: client) ? .accepted : .unavailable
        case let .diagnostic(attachments):
            guard beforeAccepting() else {
                return .withdrawn
            }
            // The attachments travel in the hint rather than on the scope, because the client
            // doesn't send the scope's attachments with events from a previous process.
            let hint = Hint()
            hint.attachments = attachments
            hub.capture(event: report.event, scope: hub.scope, hint: hint)
            return .accepted
        }
    }
}
