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
        ///
        /// - Parameters:
        ///   - attachments: The attachments sent with the event.
        ///   - runEnd: How the run ended according to the report, or `nil` when the report doesn't
        ///     describe the end of the run, such as a hang.
        case diagnostic(attachments: [Attachment], runEnd: RunEnd?)
    }

    /// How a diagnostic says the run ended. Another source may have reported the same end as its
    /// fatal event, which the sink tells by the run ID.
    enum RunEnd {
        /// The run ended with a crash, which the crash handler reports as its fatal event when it
        /// recorded it.
        case crash
        /// The OS ended the run for its memory use, which the watchdog termination integration
        /// reports as its fatal event when it detected it.
        case memoryTermination
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
