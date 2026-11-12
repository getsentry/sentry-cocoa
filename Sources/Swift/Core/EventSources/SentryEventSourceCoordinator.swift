internal import _SentryPrivate
import Foundation
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

/// Lets a source that reports late, such as MetricKit, ask the coordinator to hold the fatal
/// reports of a source that reports early, such as the watchdog termination integration, so the
/// late report can improve the early one before it is sent.
protocol SentryEventSourceHoldPolicy: AnyObject {
    /// Holds every fatal report of `source` that has a run ID for `duration`, or until the app
    /// moves to the background or is launched again, whichever comes first. A held report is sent
    /// as soon as a diagnostic of the same run arrives, enriched with it.
    func hold(fatalReportsOf source: SentryEventSource, for duration: TimeInterval)
    /// Sends the fatal reports of `source` right away again. A report held at this point stays
    /// held until its deadline.
    func stopHolding(fatalReportsOf source: SentryEventSource)
}

/// The one place between the event sources and the core SDK.
///
/// Every source submits its reports here, and the coordinator decides what reaches the next sink.
/// It tells the sources apart only by the `source` and the `runId` of their reports:
///
/// - A fatal report it lets through is recorded with its run, so a later report about the same
///   run is recognized.
/// - A MetricKit crash diagnostic of a run the crash handler already reported is dropped, because
///   the crash handler's event already describes that crash. Other diagnostics always pass, as
///   the crash handler doesn't report hangs, CPU, disk write, launch or memory diagnostics.
/// - A fatal report of a source that is held, see ``SentryEventSourceHoldPolicy``, is stored to
///   disk instead of being sent, together with the crashed session of its run, which it is sent
///   with later. A diagnostic of the same run that says how the
///   run ended enriches it, see ``SentryHeldFatalReportEnrichment``, and sends it. When the
///   deadline passes, the app moves to the background or the app is launched again first, the
///   report is sent as it is.
///
/// A diagnostic that arrives after the held report was sent is forwarded as its own event, so
/// the reason MetricKit reports is never lost, even if it duplicates the event sent before.
final class SentryEventSourceCoordinator: SentryEventSourceSink, SentryEventSourceHoldPolicy {
    private let downstream: SentryEventSourceSink
    /// Records the runs that ended fatally, or `nil` when the SDK has nowhere to keep them, in
    /// which case every report passes.
    private let fatalRunRecordStore: SentryFatalRunRecordStore?
    /// Keeps the held report, or `nil` when the SDK has nowhere to keep it, in which case no
    /// report is held.
    private let heldFatalReportStore: SentryHeldFatalReportStore?
    private let dateProvider: SentryCurrentDateProvider
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let holdDurations = SentryMutex<[SentryEventSource: TimeInterval]>([:])
    /// Serializes everything that reads, writes or sends the held report, so a diagnostic, the
    /// deadline and the background notification can't send it twice.
    private let heldReportLock = SentryMutex(())
    private let backgroundObserver = SentryMutex<NSObjectProtocol?>(nil)

    /// - Parameter downstream: The sink that takes the reports the coordinator lets through.
    init(
        downstream: SentryEventSourceSink,
        fatalRunRecordStore: SentryFatalRunRecordStore?,
        heldFatalReportStore: SentryHeldFatalReportStore?,
        dateProvider: SentryCurrentDateProvider,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        notificationCenter: SentryNSNotificationCenterWrapper
    ) {
        self.downstream = downstream
        self.fatalRunRecordStore = fatalRunRecordStore
        self.heldFatalReportStore = heldFatalReportStore
        self.dateProvider = dateProvider
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let observer = backgroundObserver.withLock({ $0 }) {
            notificationCenter.removeObserver(observer, name: nil, object: nil)
        }
    }

    var isAvailable: Bool {
        downstream.isAvailable
    }

    func submit(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        if let result = enrichHeldReport(with: report, beforeAccepting: beforeAccepting) {
            return result
        }

        if let reporter = reporterOfRun(describedBy: report) {
            // Accepted rather than withdrawn: the report was handled, and the source must not
            // submit it again.
            SentrySDKLog.debug("Dropped the \(report.source.rawValue) report for run \(report.runId?.rawValue ?? "unknown"), which \(reporter.rawValue) already reported")
            return .accepted
        }

        if let result = hold(report, beforeAccepting: beforeAccepting) {
            return result
        }
        if case .fatal = report.kind {
            // The sources report at launch, so a report still held now was left behind by a
            // previous run that ended before its deadline, and no hold may be registered anymore
            // to send it.
            sendHeldReport(because: "a previous run left it behind")
        }

        let result = downstream.submit(report, beforeAccepting: beforeAccepting)
        SentrySDKLog.debug("Report of event source \(report.source.rawValue) for run \(report.runId?.rawValue ?? "unknown") was \(result.logDescription)")

        if result == .accepted, case .fatal = report.kind, let runId = report.runId {
            recordFatalRun(runId, reportedBy: report.source)
        }
        return result
    }

    // MARK: - Hold policy

    func hold(fatalReportsOf source: SentryEventSource, for duration: TimeInterval) {
        guard heldFatalReportStore != nil else {
            SentrySDKLog.warning("Fatal reports of \(source.rawValue) can't be held without a place to keep them.")
            return
        }
        holdDurations.withLock { $0[source] = duration }
        observeBackground()
        // A report held by a previous run that ended before its deadline is sent now.
        sendHeldReport(because: "a previous run left it behind")
    }

    func stopHolding(fatalReportsOf source: SentryEventSource) {
        holdDurations.withLock { $0[source] = nil }
    }

    /// Sends the held report as it is, when there is one.
    func sendHeldReport(because reason: String) {
        heldReportLock.withLock { _ in
            sendHeldReportLocked(ofRun: nil, because: reason)
        }
    }

    // MARK: - Holding

    /// Holds the report when its source is held, and returns the result for the source.
    private func hold(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult? {
        guard case .fatal = report.kind,
              let runId = report.runId,
              let duration = holdDurations.withLock({ $0[report.source] }),
              let store = heldFatalReportStore else {
            return nil
        }
        guard beforeAccepting() else {
            return .withdrawn
        }
        heldReportLock.withLock { _ in
            // The sources that are held report once per launch, so a report still held here
            // belongs to an earlier run and can't wait for its diagnostic any longer.
            sendHeldReportLocked(ofRun: nil, because: "another report is held")
            store.storeTakingCrashedSession(SentryHeldFatalReport(runId: runId, source: report.source, event: report.event))
        }
        SentrySDKLog.debug("Holding the \(report.source.rawValue) report for run \(runId) for \(duration) seconds")
        dispatchQueueWrapper.dispatch(after: duration) { [weak self] in
            self?.heldReportLock.withLock { _ in
                self?.sendHeldReportLocked(ofRun: runId, because: "its deadline passed")
            }
        }
        return .accepted
    }

    /// Enriches the held report with a diagnostic of the same run and sends it, and returns the
    /// result for the diagnostic's source, or `nil` when the diagnostic doesn't describe the end
    /// of the held run.
    private func enrichHeldReport(with report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult? {
        guard case let .diagnostic(_, runEnd?) = report.kind,
              let runId = report.runId,
              let store = heldFatalReportStore else {
            return nil
        }
        return heldReportLock.withLock { (_) -> SentryEventSourceSubmissionResult? in
            guard let held = store.read(), held.runId == runId else {
                return nil
            }
            guard beforeAccepting() else {
                return .withdrawn
            }
            let event = SentryHeldFatalReportEnrichment.enrich(held, with: report, runEnd: runEnd)
            // The enriched report is stored before it is sent, so it isn't lost when the SDK
            // can't take it right now.
            store.store(SentryHeldFatalReport(runId: held.runId, source: held.source, event: event, session: held.session))
            SentrySDKLog.debug("Enriched the held \(held.source.rawValue) report for run \(runId) with the \(report.source.rawValue) report")
            sendHeldReportLocked(ofRun: runId, because: "\(report.source.rawValue) reported the same run")
            // The diagnostic is part of the held report now, whether or not that was sent.
            return .accepted
        }
    }

    /// Sends the held report when there is one and, with a run ID given, when it belongs to that
    /// run. The report stays held when the downstream sink can't take it.
    private func sendHeldReportLocked(ofRun runId: SentryCurrentRun.ID?, because reason: String) {
        guard let store = heldFatalReportStore, let held = store.read() else {
            return
        }
        if let runId, held.runId != runId {
            return
        }
        let result = downstream.submit(held.report) { true }
        SentrySDKLog.debug("Held \(held.source.rawValue) report for run \(held.runId) was sent because \(reason) and \(result.logDescription)")
        guard result == .accepted else {
            return
        }
        store.delete()
        recordFatalRun(held.runId, reportedBy: held.source)
    }

    private func observeBackground() {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        backgroundObserver.withLock { observer in
            guard observer == nil else {
                return
            }
            observer = notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                // The app can be suspended any time now, so the held report doesn't wait for its
                // deadline.
                self?.sendHeldReport(because: "the app moved to the background")
            }
        }
        #endif
    }

    // MARK: - Fatal runs

    private func recordFatalRun(_ runId: SentryCurrentRun.ID, reportedBy source: SentryEventSource) {
        fatalRunRecordStore?.add(SentryFatalRunRecord(runId: runId, reportedBy: source, date: dateProvider.date()))
    }

    /// The source that already reported the end of the run a diagnostic describes, when the
    /// diagnostic would duplicate that source's fatal event.
    private func reporterOfRun(describedBy report: SentryEventSourceReport) -> SentryEventSource? {
        guard case .diagnostic(_, .crash) = report.kind,
              let runId = report.runId,
              let record = fatalRunRecordStore?.record(forRunId: runId),
              record.reportedBy == .crashHandler else {
            return nil
        }
        return record.reportedBy
    }
}

private extension SentryEventSourceSubmissionResult {
    var logDescription: String {
        switch self {
        case .accepted:
            return "accepted"
        case .unavailable:
            return "not taken, because the SDK can't take reports right now"
        case .withdrawn:
            return "withdrawn by the source"
        }
    }
}
