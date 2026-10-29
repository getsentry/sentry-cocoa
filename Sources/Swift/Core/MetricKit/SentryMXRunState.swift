#if compiler(>=6.4) && (os(iOS) || os(macOS))
// StateReporting only exists on xOS 27 and later, so it must not be a hard dependency on the
// earlier versions the SDK supports.
@_weakLinked import StateReporting
import Foundation
import MetricKit

/// Reports the SDK's run ID as MetricKit state, so diagnostics recorded during the run carry it.
///
/// State reporting is unavailable on visionOS. See decision 41 in `develop-docs/DECISIONS.md`.
@available(iOS 27.0, macOS 27.0, *)
enum SentryMXRunState {
    /// The state reporting domain, which `MetricManager` must list in its
    /// `enabledStateReportingDomains` to attach the state to diagnostics.
    static let domain: StateReportingDomain = "io.sentry.run"
    static let label = "running"
    static let runIdKey = "run_id"

    struct Metadata: ReportableMetadata {
        let runId: UUID

        var metadataDictionary: [String: ReportableMetadataValue] {
            [SentryMXRunState.runIdKey: ReportableMetadataValue(runId.uuidString)]
        }
    }

    /// Reports the state for the running process. The state lasts until the process ends.
    static func report(runId: UUID) -> StateReporter<Metadata, Never> {
        let reporter = StateReporter.reporter(for: domain.rawValue, stableMetadata: Metadata.self)
        reporter.reportTransition(to: label, stableMetadata: Metadata(runId: runId))
        return reporter
    }

    /// The run IDs the SDK reported in the states of a diagnostic, ignoring the app's own domains.
    static func runIds(in states: [MetricManager.ReportedState]) -> [UUID] {
        states.compactMap { runId(domain: $0.domain, stableMetadata: $0.stableMetadata) }
    }

    /// The run ID of one reported state, or `nil` when the state isn't the SDK's.
    static func runId(domain stateDomain: String, stableMetadata: [String: ReportableMetadataValue]) -> UUID? {
        guard stateDomain == domain.rawValue, case .string(let value)? = stableMetadata[runIdKey] else {
            return nil
        }
        return UUID(uuidString: value)
    }
}

#endif // compiler(>=6.4) && (os(iOS) || os(macOS))
