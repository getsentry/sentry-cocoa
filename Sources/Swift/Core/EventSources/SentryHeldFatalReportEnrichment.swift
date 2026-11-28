internal import _SentryPrivate
import Foundation

/// Merges a MetricKit diagnostic into the held watchdog termination event of the same run.
///
/// The held event keeps everything the watchdog termination integration knew: the previous run's
/// breadcrumbs, user, tags, extras, contexts, fingerprint and timestamp. The diagnostic adds what
/// only MetricKit knows: the threads, the debug images and why the OS ended the run.
enum SentryHeldFatalReportEnrichment {
    /// The key in the mechanism data that holds why the OS ended the run, as MetricKit words it.
    static let terminationReasonKey = "termination_reason"

    /// Enriches the held event in place and returns it.
    ///
    /// - Parameters:
    ///   - diagnostic: The diagnostic's report, whose event carries the threads, debug images and
    ///     exception MetricKit reported. Its attachments aren't kept, because a fatal event only
    ///     sends the files the SDK stored for it.
    ///   - runEnd: How the diagnostic says the run ended.
    static func enrich(_ held: SentryHeldFatalReport, with diagnostic: SentryEventSourceReport, runEnd: SentryEventSourceReport.RunEnd) -> Event {
        let event = held.event
        let diagnosticEvent = diagnostic.event
        event.threads = diagnosticEvent.threads
        event.debugMeta = diagnosticEvent.debugMeta

        guard runEnd.isWatchdogTermination else {
            // The OS ended the run for a crash the crash handler didn't record. The diagnostic's
            // exception replaces the watchdog termination, and the event is sent as a MetricKit
            // crash with the previous run's data.
            event.exceptions = diagnosticEvent.exceptions
            return event
        }

        // The diagnostic confirms the watchdog termination, which keeps its type and mechanism
        // and gets the stack trace and the reason.
        guard let exception = event.exceptions?.first, let diagnosticException = diagnosticEvent.exceptions?.first else {
            return event
        }
        exception.stacktrace = diagnosticException.stacktrace
        exception.threadId = diagnosticException.threadId
        let terminationReason: String?
        switch runEnd {
        case let .crash(reason):
            terminationReason = reason
        case .memoryTermination:
            terminationReason = diagnosticException.value
        }
        if let terminationReason {
            var data = exception.mechanism?.data ?? [:]
            data[terminationReasonKey] = terminationReason
            exception.mechanism?.data = data
        }
        return event
    }
}
