/// What a ``SentryEventSource`` knows about a run of the app, in the form every source reports it.
///
/// The source converts its own format into the event, because only the source knows that format.
/// Everything that happens after that, such as deciding whether the event is sent, is up to the
/// ``SentryEventSourceSink`` that takes the report.
struct SentryEventSourceReport {
    /// How the report relates to the session of the run it describes.
    enum Kind {
        /// The report is the fatal event of a run that ended with it, so it is sent together with
        /// the crashed session of that run.
        ///
        /// - Parameters:
        ///   - attachmentPaths: The files the source stored for the report, such as the screenshot
        ///     taken when the app crashed.
        ///   - isRetainedOnFailure: Whether the source keeps the report and submits it again when
        ///     the sink can't take it. The crashed session is then kept for the next submission.
        case fatal(attachmentPaths: [String], isRetainedOnFailure: Bool)
        /// The report describes something that doesn't end a session, or a run whose session the
        /// SDK can't tell anymore, so it is sent as a regular event.
        case diagnostic(attachments: [Attachment])
    }

    /// The pipeline the report came through. The sink processes the report the way this pipeline
    /// needs.
    let source: SentryEventSource
    let kind: Kind
    /// The ID of the run the report belongs to, or `nil` when the source can't tell.
    ///
    /// The SDK creates one ID per run, see `SentryCurrentRun`, and every source stores it in a
    /// place it can read back when it reports on that run: the crash handler in the user section
    /// of its stored report, the watchdog termination integration in the persisted app state,
    /// MetricKit in a parked thread crumb or the reported states of xOS 27. Reports with the same
    /// run ID describe the same run, whichever pipeline they came through.
    let runId: SentryCurrentRun.ID?
    let event: Event
}
