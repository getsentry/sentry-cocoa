// StateReporting only exists in the SDKs of Xcode 27 and later, and MetricKit doesn't list the
// reported states in the diagnostics of visionOS.
#if (os(iOS) || os(macOS)) && compiler(>=6.4)
import MetricKit
import StateReporting

/// Reports the run ID as a state, so the MetricKit diagnostics of this run carry it.
///
/// MetricKit lists the states of the domains its `MetricManager` enabled in
/// `DiagnosticReport.Environment.states`, with their stable metadata. The run ID is the stable
/// metadata of a state that lasts for the whole run, so every diagnostic of the run lists it,
/// including the ones that don't hold the call stacks of all threads, which the thread crumb
/// can't reach.
@available(iOS 27.0, macOS 27.0, *)
enum SentryMXRunIdState {
    /// The domain of the SDK's state. `MetricManager` only lists the states of the domains it
    /// was created with.
    static let domain = "io.sentry.run"
    static let label = "run"
    static let runIdKey = "run_id"

    /// The conformance is written by hand, because the `@ReportableMetadata` macro would require
    /// a macro plugin to build the SDK.
    struct Metadata: ReportableMetadata {
        let runId: SentryCurrentRun.ID

        var metadataDictionary: [String: ReportableMetadataValue] {
            [SentryMXRunIdState.runIdKey: .string(runId.rawValue)]
        }
    }

    /// Reports the state of the run.
    ///
    /// An SDK restart reports the same state again, because the run ID lasts for the process.
    /// The SDK assumes the system ignores a transition to the state it is already in, which
    /// can't be verified, as a reported state can't be read back. If the system lists the state
    /// twice instead, both carry the same run ID, which ``runId(of:)`` still returns.
    static func report(runId: SentryCurrentRun.ID) {
        StateReporter
            .reporter(for: domain, stableMetadata: Metadata.self)
            .reportTransition(to: label, stableMetadata: Metadata(runId: runId))
    }

    /// - Returns: The run ID the SDK's states carry, or `nil` when there is none or when they
    ///   carry more than one, because the diagnostic then can't be attributed to a single run.
    static func runId(of states: [MetricManager.ReportedState]) -> SentryCurrentRun.ID? {
        var runIds = Set<String>()
        for state in states where state.domain == domain {
            if case .string(let runId) = state.stableMetadata[runIdKey], !runId.isEmpty {
                runIds.insert(runId)
            }
        }
        guard let runId = runIds.first else {
            return nil
        }
        guard runIds.count == 1 else {
            SentrySDKLog.debug("MetricKit diagnostic lists the states of \(runIds.count) runs, not using them to match its run.")
            return nil
        }
        return SentryCurrentRun.ID(rawValue: runId)
    }
}
#endif // (os(iOS) || os(macOS)) && compiler(>=6.4)
