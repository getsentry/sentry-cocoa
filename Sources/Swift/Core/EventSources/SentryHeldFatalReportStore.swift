internal import _SentryPrivate
import Foundation

/// A fatal report the coordinator holds back, waiting for another source to report on the same
/// run.
struct SentryHeldFatalReport {
    let runId: SentryCurrentRun.ID
    let source: SentryEventSource
    let event: Event
    /// The crashed session of the run the report describes, or `nil` when that run had none.
    ///
    /// The SDK keeps one crashed session for the first fatal event of a launch. When the app
    /// crashes while a report is held, the next launch replaces that session with the one of the
    /// crashed run, so the held report keeps the session of its own run and is sent with it.
    var session: SentrySession?

    /// The report as the source submitted it. Attachments aren't kept, because the only source
    /// that is held, the watchdog termination integration, has none.
    var report: SentryEventSourceReport {
        SentryEventSourceReport(
            source: source,
            kind: .fatal(attachmentPaths: [], isRetainedOnFailure: false),
            runId: runId,
            event: event,
            crashedSession: .carried(session)
        )
    }
}

/// Persists the one fatal report the coordinator holds, so a relaunch or a kill while it waits
/// doesn't lose it.
///
/// Only one report is held at a time: a run ends at most once, and the sources that report at
/// launch describe the run directly before the current one.
final class SentryHeldFatalReportStore {
    static let fileName = "held-fatal-report.json"

    private enum Key {
        static let runId = "run_id"
        static let source = "source"
        static let event = "event"
        static let session = "session"
    }

    private let fileManager: SentryFileManager
    private let lock = SentryMutex(())

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
    func storeTakingCrashedSession(_ report: SentryHeldFatalReport) {
        var report = report
        report.session = fileManager.readCrashedSession()
        guard store(report), report.session != nil else {
            return
        }
        fileManager.deleteCrashedSession()
    }

    /// - Returns: Whether the report was stored.
    @discardableResult
    func store(_ report: SentryHeldFatalReport) -> Bool {
        var json: [String: Any] = [
            Key.runId: report.runId.rawValue,
            Key.source: report.source.rawValue,
            Key.event: report.event.serialize()
        ]
        if let session = report.session {
            json[Key.session] = session.serializeForPersistence()
        }
        guard let data = SentrySerializationSwift.data(withJSONObject: json) else {
            SentrySDKLog.error("Failed to serialize the held \(report.source.rawValue) report for run \(report.runId)")
            return false
        }
        return lock.withLock { _ in
            fileManager.write(data, toPath: filePath)
        }
    }

    /// The held report, or `nil` when there is none or it can't be read anymore.
    func read() -> SentryHeldFatalReport? {
        guard let data = lock.withLock({ _ in try? fileManager.readData(fromPath: filePath) }) else {
            return nil
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let runId = json[Key.runId] as? String,
              let source = (json[Key.source] as? String).flatMap(SentryEventSource.init(rawValue:)),
              let eventJSON = json[Key.event] as? [String: Any],
              let eventData = SentrySerializationSwift.data(withJSONObject: eventJSON),
              let event = SentryEventDecoder.decodeEvent(jsonData: eventData) else {
            SentrySDKLog.error("Failed to read the held fatal report, dropping it")
            delete()
            return nil
        }
        // The event was complete when it was stored, so the scope of the current run must not add
        // its breadcrumbs, which it does for an event without any.
        event.breadcrumbs = event.breadcrumbs ?? []
        let session = (json[Key.session] as? [String: Any])
            .flatMap { SentrySerializationSwift.data(withJSONObject: $0) }
            .flatMap { SentrySerializationSwift.session(with: $0) }
        return SentryHeldFatalReport(runId: SentryCurrentRun.ID(rawValue: runId), source: source, event: event, session: session)
    }

    func delete() {
        lock.withLock { _ in
            fileManager.removeFile(atPath: filePath)
        }
    }
}
