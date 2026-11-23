internal import _SentryPrivate
import Foundation

/// What a store keeps about one run.
protocol SentryRunRecord: Codable, Equatable {
    var runId: SentryCurrentRun.ID { get }
    /// When the record was made. Records older than the store's retention are dropped.
    var date: Date { get }
}

/// Persists one record per run for the runs of the last seven days.
///
/// The sources report on a run at different times, and MetricKit up to a day after it ended, with
/// the app possibly closed for longer in between. A store keeps what a later launch needs to know
/// about a run in one JSON file that each run appends to.
/// Serializes every read and write of the record files.
///
/// The lock belongs to the files and not to a store, because every SDK start creates its own
/// stores for the same files, and a store's own lock wouldn't keep two of them from overwriting
/// each other's records. It is one lock for all files, because a generic type can't hold a
/// static one per file, and the stores are read and written too rarely to contend.
private let runRecordFilesLock = SentryLock()

final class SentryRunRecordStore<Record: SentryRunRecord> {
    static var retention: TimeInterval { 7 * 24 * 60 * 60 }

    let fileName: String
    private let fileManager: SentryFileManager
    private let dateProvider: SentryCurrentDateProvider

    init(fileName: String, fileManager: SentryFileManager, dateProvider: SentryCurrentDateProvider) {
        self.fileName = fileName
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    var filePath: String {
        fileManager.getSentryPathAsURL().appendingPathComponent(fileName).path
    }

    /// Adds the record, replacing the record of the same run, and drops the records older than
    /// the retention.
    func add(_ record: Record) {
        runRecordFilesLock.withLock {
            var records = readRecords().filter { $0.runId != record.runId }
            records.append(record)
            writeRecords(records)
        }
    }

    /// The records within the retention, oldest first.
    func records() -> [Record] {
        runRecordFilesLock.withLock { readRecords() }
    }

    /// The record of the run, or `nil` when the run has none within the retention.
    func record(forRunId runId: SentryCurrentRun.ID) -> Record? {
        runRecordFilesLock.withLock { readRecords().first { $0.runId == runId } }
    }

    private func readRecords() -> [Record] {
        guard let data = try? fileManager.readData(fromPath: filePath) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data) else {
            SentrySDKLog.warning("Could not decode the run records in \(fileName), starting over.")
            return []
        }
        let oldest = dateProvider.date().addingTimeInterval(-Self.retention)
        return file.records.filter { $0.date >= oldest }
    }

    private func writeRecords(_ records: [Record]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(File(records: records)) else {
            SentrySDKLog.warning("Could not encode the run records for \(fileName).")
            return
        }
        fileManager.write(data, toPath: filePath)
    }

    private struct File: Codable {
        let records: [Record]
    }
}
