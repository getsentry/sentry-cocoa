#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

/// Records the reports the event sources submit, without capturing them.
final class TestEventSourceSink: SentryEventSourceSink {
    var isAvailable = true
    var submittedReports: [SentryEventSourceReport] = []

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

/// Builds the event source objects the SDK uses, which end at the SDK's current hub, so a test
/// doesn't take them from the shared dependency container.
enum TestEventSources {
    /// The coordinator in front of the sink that captures on the SDK's current hub.
    static func hubSink() -> SentryEventSourceCoordinator {
        // The same parts the dependency container gives its coordinator, so a run a test reports
        // through this coordinator is known to the container's coordinator too.
        let dependencies = SentryDependencyContainer.sharedInstance()
        return SentryEventSourceCoordinator(
            downstream: SentryHubEventSourceSink(dependencies: SentrySDKCurrentHubProvider()),
            fatalRunRecordStore: dependencies.fileManager.map {
                SentryFatalRunRecordStore(fileManager: $0, dateProvider: dependencies.dateProvider)
            },
            heldFatalReportStore: dependencies.fileManager.map { SentryHeldFatalReportStore(fileManager: $0) },
            dateProvider: dependencies.dateProvider,
            dispatchQueueWrapper: dependencies.dispatchQueueWrapper,
            notificationCenter: dependencies.notificationCenterWrapper
        )
    }

    /// The crash handler's event source, submitting to ``hubSink()``.
    static func crashHandlerEventSource() -> SentryCrashHandlerEventSource {
        SentryCrashHandlerEventSource(sink: hubSink())
    }
}
