internal import _SentryPrivate
import Foundation

/// Persists the one fatal report the coordinator holds, so a relaunch or a kill while it waits
/// doesn't lose it.
///
/// Only one report is held at a time: a run ends at most once, and the sources that report at
/// launch describe the run directly before the current one.
final class SentryHeldFatalReportStore {
    static let fileName = "held-fatal-report.json"

    private let fileManager: SentryFileManager
    private let lock = SentryLock()

    init(fileManager: SentryFileManager) {
        self.fileManager = fileManager
    }

    var filePath: String {
        fileManager.getSentryPathAsURL().appendingPathComponent(Self.fileName).path
    }

    /// Stores the report together with the crashed session the SDK keeps for the first fatal
    /// event, and takes that session out of its place, so no other fatal event is sent with it.
    ///
    /// The session is only removed once the report is stored with it, so it isn't lost when the
    /// process dies in between.
    ///
    /// - Returns: Whether the report was stored. When it wasn't, the session stays in its place.
    @discardableResult
    func storeTakingCrashedSession(_ report: SentryHeldFatalReport) -> Bool {
        var report = report
        report.session = fileManager.readCrashedSession()
        guard store(report) else {
            return false
        }
        if report.session != nil {
            fileManager.deleteCrashedSession()
            SentrySDKLog.debug("Moved the crashed session into the held \(report.source.rawValue) report for run \(report.runId)")
        }
        return true
    }

    /// - Returns: Whether the report was stored.
    @discardableResult
    func store(_ report: SentryHeldFatalReport) -> Bool {
        let data: Data
        do {
            data = try encodeToJSONData(data: report)
        } catch {
            SentrySDKLog.error("Failed to encode the held \(report.source.rawValue) report for run \(report.runId): \(error)")
            return false
        }
        guard lock.withLock({ fileManager.write(data, toPath: filePath) }) else {
            SentrySDKLog.error("Failed to write the held \(report.source.rawValue) report for run \(report.runId) to \(filePath)")
            return false
        }
        SentrySDKLog.debug("Stored the held \(report.source.rawValue) report for run \(report.runId) \(report.session == nil ? "without a" : "with its") crashed session, \(data.count) bytes")
        return true
    }

    /// Whether a report is held, without reading it.
    ///
    /// Cheap enough for the thread that starts the SDK, unlike ``read()``.
    var hasReport: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }

    /// The held report, or `nil` when there is none or it can't be read anymore.
    func read() -> SentryHeldFatalReport? {
        guard hasReport, let data = lock.withLock({ try? fileManager.readData(fromPath: filePath) }) else {
            return nil
        }
        guard let report: SentryHeldFatalReport = decodeFromJSONData(jsonData: data) else {
            SentrySDKLog.error("Failed to read the held fatal report of \(data.count) bytes, dropping it")
            delete()
            return nil
        }
        SentrySDKLog.debug("Read the held \(report.source.rawValue) report for run \(report.runId) \(report.session == nil ? "without a" : "with its") crashed session")
        return report
    }

    func delete() {
        lock.withLock {
            fileManager.removeFile(atPath: filePath)
        }
        SentrySDKLog.debug("Deleted the held fatal report")
    }
}
