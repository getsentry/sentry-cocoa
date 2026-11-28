internal import _SentryPrivate
import Foundation
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

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
/// - A fatal report of a source that a ``SentryEventSourceOrchestrator`` holds is stored to disk
///   instead of being sent, together with the crashed session of its run, which it is sent with
///   later. A diagnostic of the orchestrator's awaited source that says how the same run ended is
///   merged into it by the orchestrator, and the report is sent. When the deadline passes, the app
///   moves to the background or the app is launched again first, the report is sent as it is.
///
/// A diagnostic that arrives after the held report was sent is forwarded as its own event, so
/// the reason MetricKit reports is never lost, even if it duplicates the event sent before.
final class SentryEventSourceCoordinator: SentryEventSourceSink {
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
    private let orchestrators = SentryMutex<[SentryEventSourceOrchestrator]>([])
    /// Serializes everything that reads, writes or sends the held report, so a diagnostic, the
    /// deadline and the background notification can't send it twice.
    private let heldReportLock = SentryLock()
    /// The run whose report was held since this launch, which tells it from a report a previous
    /// launch left behind. Only read and written with `heldReportLock` taken.
    private let runHeldSinceLaunch = SentryMutex<SentryCurrentRun.ID?>(nil)
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
            // No hold may be registered anymore to send a report a previous launch left behind.
            sendHeldReportOfPreviousLaunch()
        }

        return forward(report, beforeAccepting: beforeAccepting)
    }

    /// Hands the report to the downstream sink and records the run when it ended fatally.
    private func forward(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult {
        let result = downstream.submit(report, beforeAccepting: beforeAccepting)
        SentrySDKLog.debug("Report of event source \(report.source.rawValue) for run \(report.runId?.rawValue ?? "unknown") was \(result.logDescription)")

        if result == .accepted, case .fatal = report.kind, let runId = report.runId {
            recordFatalRun(runId, reportedBy: report.source)
        }
        return result
    }

    // MARK: - Orchestrators

    /// Applies the orchestrators from now on, in place of the ones applied before. A report that is
    /// held at this point stays held until its deadline.
    ///
    /// The SDK calls this before it installs the integrations, so the orchestrators are known before
    /// the first source reports.
    func use(_ orchestrators: [SentryEventSourceOrchestrator]) {
        guard heldFatalReportStore != nil || orchestrators.isEmpty else {
            SentrySDKLog.warning("Fatal reports of \(orchestrators.map { $0.heldSource.rawValue }.joined(separator: ", ")) can't be held without a place to keep them.")
            return
        }
        self.orchestrators.withLock { $0 = orchestrators }
        if !orchestrators.isEmpty {
            observeBackground()
        }
    }

    /// Whether a fatal report is held, which this launch sends: either a previous launch left it
    /// behind, or it is waiting for its deadline. Doesn't read the report.
    var hasHeldReport: Bool {
        heldFatalReportStore?.hasReport ?? false
    }

    /// Sends the report a previous launch held and left behind, because it ended before the
    /// deadline. A report held since this launch keeps waiting.
    ///
    /// The SDK calls this at every start, off the thread it starts on, because nothing else sends
    /// the report in a launch that neither holds reports, for example after MetricKit diagnostics
    /// were disabled, nor reports a fatal run.
    func sendHeldReportOfPreviousLaunch() {
        heldReportLock.withLock {
            guard let held = heldFatalReportStore?.read(), held.runId != runHeldSinceLaunch.withLock({ $0 }) else {
                return
            }
            sendHeldReportLocked(ofRun: held.runId, because: "a previous launch left it behind")
        }
    }

    /// Sends the held report as it is, when there is one.
    func sendHeldReport(because reason: String) {
        heldReportLock.withLock {
            _ = sendHeldReportLocked(ofRun: nil, because: reason)
        }
    }

    // MARK: - Holding

    private enum HoldOutcome {
        case held
        case earlierReportStillHeld
        case notStored
    }

    /// Holds the report when an orchestrator holds its source, and returns the result for the source.
    private func hold(_ report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult? {
        guard case .fatal = report.kind,
              let runId = report.runId,
              let duration = orchestrators.withLock({ $0.first { $0.heldSource == report.source }?.holdDuration }),
              let store = heldFatalReportStore else {
            return nil
        }
        guard beforeAccepting() else {
            return .withdrawn
        }
        let outcome: HoldOutcome = heldReportLock.withLock {
            // The sources that are held report once per launch, so a report still held here
            // belongs to an earlier run and can't wait for its diagnostic any longer.
            guard sendHeldReportLocked(ofRun: nil, because: "another report is held") else {
                return .earlierReportStillHeld
            }
            guard store.storeTakingCrashedSession(SentryHeldFatalReport(runId: runId, source: report.source, event: report.event)) else {
                return .notStored
            }
            runHeldSinceLaunch.withLock { $0 = runId }
            return .held
        }
        switch outcome {
        case .held:
            break
        case .earlierReportStillHeld:
            // Only one report is held, and storing this one would delete the earlier one, which
            // the SDK couldn't take. So this one isn't held and goes on like a report of a
            // source that isn't held, and the earlier one stays for the next time it can be sent.
            SentrySDKLog.warning("The \(report.source.rawValue) report for run \(runId) isn't held, because an earlier held report couldn't be sent")
            return forward(report) { true }
        case .notStored:
            // A report that isn't on disk can't be sent at its deadline, so it is sent now, as it
            // is without a hold. The source already agreed to hand it over, and the crashed
            // session is still in its place for it.
            SentrySDKLog.warning("The \(report.source.rawValue) report for run \(runId) couldn't be stored to hold it, sending it right away")
            return forward(report) { true }
        }
        SentrySDKLog.debug("Holding the \(report.source.rawValue) report for run \(runId) for \(duration) seconds")
        dispatchQueueWrapper.dispatch(after: duration) { [weak self] in
            self?.heldReportLock.withLock {
                _ = self?.sendHeldReportLocked(ofRun: runId, because: "its deadline passed")
            }
        }
        return .accepted
    }

    /// Merges a diagnostic of the same run into the held report and sends it, and returns the
    /// result for the diagnostic's source, or `nil` when the diagnostic doesn't describe the end
    /// of the held run or no orchestrator awaits its source for the held report.
    private func enrichHeldReport(with report: SentryEventSourceReport, beforeAccepting: () -> Bool) -> SentryEventSourceSubmissionResult? {
        guard case let .diagnostic(_, runEnd?) = report.kind,
              let runId = report.runId,
              let store = heldFatalReportStore else {
            return nil
        }
        return heldReportLock.withLock { () -> SentryEventSourceSubmissionResult? in
            guard let held = store.read(), held.runId == runId,
                  let orchestrator = orchestrators.withLock({ $0.first { $0.heldSource == held.source && $0.awaitedSource == report.source } }) else {
                return nil
            }
            guard beforeAccepting() else {
                return .withdrawn
            }
            let event = orchestrator.merge(held, report, runEnd)
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
    ///
    /// - Returns: Whether no report is held anymore, so another one can be stored.
    @discardableResult
    private func sendHeldReportLocked(ofRun runId: SentryCurrentRun.ID?, because reason: String) -> Bool {
        guard let store = heldFatalReportStore, let held = store.read() else {
            return true
        }
        if let runId, held.runId != runId {
            return false
        }
        let result = downstream.submit(held.report) { true }
        SentrySDKLog.debug("Held \(held.source.rawValue) report for run \(held.runId) was sent because \(reason) and \(result.logDescription)")
        guard result == .accepted else {
            return false
        }
        store.delete()
        recordFatalRun(held.runId, reportedBy: held.source)
        return true
    }

    private func observeBackground() {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        backgroundObserver.withLock { observer in
            guard observer == nil else {
                return
            }
            observer = notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                // The app can be suspended any time now, so the held report doesn't wait for its
                // deadline. The notification is posted on the main thread, which must not wait
                // for the lock, the file or the capture.
                self?.dispatchQueueWrapper.dispatchAsync { [weak self] in
                    self?.sendHeldReport(because: "the app moved to the background")
                }
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
