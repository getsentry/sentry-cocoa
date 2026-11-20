import Foundation

/// A run that ended fatally and the source that reported it.
///
/// The coordinator records every fatal report it lets through, so a report of another source
/// about the same run, which MetricKit can deliver a launch or two later, is recognized as a
/// report of a run the SDK already sent an event for.
struct SentryFatalRunRecord: SentryRunRecord {
    let runId: SentryCurrentRun.ID
    /// The source whose fatal report the SDK sent for the run.
    let reportedBy: SentryEventSource
    let date: Date
}

/// Persists the runs that ended fatally.
typealias SentryFatalRunRecordStore = SentryRunRecordStore<SentryFatalRunRecord>

extension SentryRunRecordStore where Record == SentryFatalRunRecord {
    static var fileName: String { "fatal-runs.json" }

    convenience init(fileManager: SentryFileManager, dateProvider: SentryCurrentDateProvider) {
        self.init(fileName: Self.fileName, fileManager: fileManager, dateProvider: dateProvider)
    }
}

extension SentryEventSource: Codable {}
