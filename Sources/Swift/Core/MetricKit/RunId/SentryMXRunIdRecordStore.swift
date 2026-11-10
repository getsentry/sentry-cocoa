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

/// The store is where the run ID is kept as a string, so the record turns it into one when it is
/// written and back into an ID when it is read.
extension SentryMXRunIdRecord {
    private enum CodingKeys: String, CodingKey {
        case runId
        case threadCrumbAddresses
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runId: SentryCurrentRun.ID(rawValue: try container.decode(String.self, forKey: .runId)),
            threadCrumbAddresses: try container.decode([UInt64].self, forKey: .threadCrumbAddresses),
            date: try container.decode(Date.self, forKey: .date)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runId.rawValue, forKey: .runId)
        try container.encode(threadCrumbAddresses, forKey: .threadCrumbAddresses)
        try container.encode(date, forKey: .date)
    }
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
