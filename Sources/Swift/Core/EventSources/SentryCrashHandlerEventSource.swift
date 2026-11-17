internal import _SentryPrivate

/// The crash handler's side of the event source protocol.
///
/// The crash handler converts its stored reports into events in Objective-C, which can't create a
/// `SentryEventSourceReport`. This class creates the report for it, so the crash handler submits
/// its events through the same ``SentryEventSourceSink`` as every other source and the sink
/// doesn't know the crash handler from the others.
@_spi(Private) @objc public final class SentryCrashHandlerEventSource: NSObject {
    private let sink: SentryEventSourceSink

    /// - Parameter sink: The sink that takes the reports of the crash handler.
    init(sink: SentryEventSourceSink) {
        self.sink = sink
    }

    /// Whether the sink can take reports right now. The crash handler checks it before converting
    /// a stored report, because the conversion only makes sense when the event can be taken.
    @objc public var isAvailable: Bool {
        sink.isAvailable
    }

    /// Submits the fatal event converted from a stored crash report.
    ///
    /// The run ID and the attachments are read from the stored crash report, where the SDK and the
    /// crash handler wrote them when the app crashed.
    ///
    /// - Parameters:
    ///   - event: The event converted from the stored crash report.
    ///   - crashReport: The stored crash report the event was converted from.
    ///   - isRetainedOnFailure: Whether the crash handler keeps the stored report and submits it
    ///     again when the sink can't take it.
    ///   - beforeAccepting: Called immediately before the report is taken. Returning `false`
    ///     withdraws it.
    @objc(submitEvent:crashReport:isRetainedOnFailure:beforeAccepting:)
    public func submit(
        _ event: Event,
        crashReport: [AnyHashable: Any],
        isRetainedOnFailure: Bool,
        beforeAccepting: () -> Bool
    ) -> SentryEventSourceSubmissionResult {
        let report = SentryEventSourceReport(
            source: .crashHandler,
            kind: .fatal(
                attachmentPaths: Self.attachmentPaths(ofCrashReport: crashReport),
                isRetainedOnFailure: isRetainedOnFailure
            ),
            runId: SentryCurrentRun.runId(ofCrashReport: crashReport),
            event: event
        )
        return sink.submit(report, beforeAccepting: beforeAccepting)
    }

    /// The crash handler stores the paths of the screenshot and the view hierarchy it took when
    /// the app crashed under the attachments key. The report is read from disk, so anything that
    /// isn't a path is skipped.
    private static func attachmentPaths(ofCrashReport crashReport: [AnyHashable: Any]) -> [String] {
        guard let attachments = crashReport[SentryNativeReportAttachmentsKey] as? [Any] else {
            return []
        }
        return attachments.compactMap { $0 as? String }
    }
}
