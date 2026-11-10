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

extension SentryFatalRunRecord {
    private enum CodingKeys: String, CodingKey {
        case runId
        case reportedBy
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runId: SentryCurrentRun.ID(rawValue: try container.decode(String.self, forKey: .runId)),
            reportedBy: try container.decode(SentryEventSource.self, forKey: .reportedBy),
            date: try container.decode(Date.self, forKey: .date)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runId.rawValue, forKey: .runId)
        try container.encode(reportedBy, forKey: .reportedBy)
        try container.encode(date, forKey: .date)
    }
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
