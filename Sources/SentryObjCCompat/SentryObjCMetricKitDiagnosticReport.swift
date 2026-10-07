#if canImport(MetricKit) && !os(tvOS)
// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public typealias SentryObjCMetricKitDiagnosticReport = UInt

/// Maps the `SentryObjCMetricKitDiagnosticReport` bitmask to the SDK's report set. The bitmask is
/// a plain `UInt` like the other `NS_OPTIONS` wrappers, so the mapping lives in its own namespace
/// instead of an extension that would collide with theirs.
enum SentryObjCMetricKitDiagnosticReportMapping {
    // Keep these in sync with SentryObjCMetricKitDiagnosticReport.h.
    static let crash: SentryObjCMetricKitDiagnosticReport = 1 << 0
    static let hang: SentryObjCMetricKitDiagnosticReport = 1 << 1
    static let cpuException: SentryObjCMetricKitDiagnosticReport = 1 << 2
    static let diskWriteException: SentryObjCMetricKitDiagnosticReport = 1 << 3

    private static let bitsByReport: [(bit: SentryObjCMetricKitDiagnosticReport, report: SentryMetricKit.DiagnosticReport)] = [
        (crash, .crash),
        (hang, .hang),
        (cpuException, .cpuException),
        (diskWriteException, .diskWriteException)
    ]

    static func bits(for reports: Set<SentryMetricKit.DiagnosticReport>) -> SentryObjCMetricKitDiagnosticReport {
        bitsByReport.reduce(0) { bits, entry in
            reports.contains(entry.report) ? bits | entry.bit : bits
        }
    }

    /// Bits that don't name a report are ignored.
    static func reports(for bits: SentryObjCMetricKitDiagnosticReport) -> Set<SentryMetricKit.DiagnosticReport> {
        Set(bitsByReport.filter { bits & $0.bit != 0 }.map(\.report))
    }
}

// swiftlint:enable missing_docs
#endif // canImport(MetricKit) && !os(tvOS)
