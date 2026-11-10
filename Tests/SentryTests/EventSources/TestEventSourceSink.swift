#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

/// Records the reports the event sources submit, without capturing them.
final class TestEventSourceSink: SentryEventSourceSink {
    var isAvailable = true
    private(set) var submittedReports: [SentryEventSourceReport] = []

    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        guard isAvailable else {
            return .unavailable
        }
        guard beforeAccepting() else {
            return .withdrawn
        }
        submittedReports.append(report)
        return .accepted
    }
}
