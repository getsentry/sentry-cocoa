#if os(iOS) || os(macOS) || os(visionOS)
import Foundation

/// What a run left behind so that a MetricKit diagnostic about it can be matched to its run ID.
struct SentryMXRunIdRecord: SentryRunRecord {
    let runId: SentryCurrentRun.ID
    /// The addresses of the frames the thread crumb spelled in that run, outermost first. They
    /// are the addresses of that process, which is what MetricKit reports for it.
    let threadCrumbAddresses: [UInt64]
    let date: Date
}

/// Persists the records of the runs that MetricKit may still deliver diagnostics for.
typealias SentryMXRunIdRecordStore = SentryRunRecordStore<SentryMXRunIdRecord>

extension SentryRunRecordStore where Record == SentryMXRunIdRecord {
    static var fileName: String { "metrickit-run-ids.json" }

    convenience init(fileManager: SentryFileManager, dateProvider: SentryCurrentDateProvider) {
        self.init(fileName: Self.fileName, fileManager: fileManager, dateProvider: dateProvider)
    }
}
#endif
