#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// What a run left behind so that a MetricKit diagnostic about it can be matched to its run ID.
struct SentryMXRunIdRecord: Codable, Equatable {
    let runId: String
    /// The addresses of the frames the thread crumb spelled in that run, outermost first. They
    /// are the addresses of that process, which is what MetricKit reports for it.
    let threadCrumbAddresses: [UInt64]
    /// When the run recorded itself.
    let date: Date
}

/// Persists the records of the runs that MetricKit may still deliver diagnostics for.
///
/// MetricKit delivers diagnostics up to a day after they occur, and the app can stay closed for
/// longer, so the records of the last seven days are kept. The store is one JSON file that each
/// run appends to; it is read when a diagnostic arrives.
final class SentryMXRunIdRecordStore {
    static let retention: TimeInterval = 7 * 24 * 60 * 60
    static let fileName = "metrickit-run-ids.json"

    private let fileManager: SentryFileManager
    private let dateProvider: SentryCurrentDateProvider
    private let lock = NSLock()

    init(fileManager: SentryFileManager, dateProvider: SentryCurrentDateProvider) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    var filePath: String {
        fileManager.getSentryPathAsURL().appendingPathComponent(Self.fileName).path
    }

    /// Appends the record and drops the records older than the retention.
    func add(_ record: SentryMXRunIdRecord) {
        lock.synchronized {
            var records = readRecords().filter { $0.runId != record.runId }
            records.append(record)
            writeRecords(records)
        }
    }

    /// The records within the retention, oldest first.
    func records() -> [SentryMXRunIdRecord] {
        lock.synchronized { readRecords() }
    }

    private func readRecords() -> [SentryMXRunIdRecord] {
        guard let data = try? fileManager.readData(fromPath: filePath) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data) else {
            SentrySDKLog.warning("Could not decode the MetricKit run ID records, starting over.")
            return []
        }
        let oldest = dateProvider.date().addingTimeInterval(-Self.retention)
        return file.records.filter { $0.date >= oldest }
    }

    private func writeRecords(_ records: [SentryMXRunIdRecord]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(File(records: records)) else {
            SentrySDKLog.warning("Could not encode the MetricKit run ID records.")
            return
        }
        fileManager.write(data, toPath: filePath)
    }

    private struct File: Codable {
        let records: [SentryMXRunIdRecord]
    }
}
#endif
