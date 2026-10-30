#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Converts the legacy `MXMetricManager` diagnostics of one MetricKit diagnostic type into
/// `SentryMXDiagnostic`.
///
/// Each diagnostic type has one processor, which also converts the type's `MetricManager`
/// diagnostics on xOS 27 and later. The exception value and the level of a type are defined in one
/// place, so a diagnostic produces the same event regardless of the API that delivered it.
protocol SentryMXDiagnosticProcessor {
    associatedtype LegacyDiagnostic: MXDiagnostic & SentryMetricKit.CallStackTreeProviding

    static var report: SentryMetricKit.DiagnosticReport { get }

    /// Converts a diagnostic of a legacy `MXDiagnosticPayload` whose time range starts at
    /// `timestamp`.
    static func diagnostic(of diagnostic: LegacyDiagnostic, timestamp: Date) -> SentryMXDiagnostic
}

#endif // os(iOS) || os(macOS) || os(visionOS)
