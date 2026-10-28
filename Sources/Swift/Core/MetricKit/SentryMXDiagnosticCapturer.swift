#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// Captures MetricKit diagnostics as events.
///
/// Both MetricKit APIs convert their diagnostics into `SentryMXDiagnostic` and hand them to the
/// same capturer, so a diagnostic produces the same event regardless of the API that delivered it.
final class SentryMXDiagnosticCapturer {
    typealias Diagnostic = SentryMetricKit.DiagnosticReport

    let inAppLogic: SentryInAppLogic
    let attachDiagnosticAsAttachment: Bool
    let enabledDiagnostics: Set<Diagnostic>
    let releaseResolver: SentryMXReleaseResolver
    let hangReportingMode: SentryMetricKitHangReportingMode
    let processIdentifier: pid_t
    let processStartDate: Date

    init(
        inAppLogic: SentryInAppLogic,
        attachDiagnosticAsAttachment: Bool,
        enabledDiagnostics: Set<Diagnostic> = Diagnostic.all.subtracting([.crash, .memoryException]),
        releaseName: String? = nil,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:],
        hangReportingMode: SentryMetricKitHangReportingMode = .legacy,
        processIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier,
        processStartDate: Date
    ) {
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        self.enabledDiagnostics = enabledDiagnostics
        self.releaseResolver = SentryMXReleaseResolver(releaseName: releaseName, bundleInfo: bundleInfo)
        self.hangReportingMode = hangReportingMode
        self.processIdentifier = processIdentifier
        self.processStartDate = processStartDate
    }

    func capture(_ diagnostic: SentryMXDiagnostic) {
        let diagnosticReport = diagnostic.report
        guard enabledDiagnostics.contains(diagnosticReport) else {
            SentrySDKLog.debug("MetricKit \(diagnosticReport) diagnostics are not enabled, skipping diagnostic")
            return
        }
        SentrySDKLog.debug("Processing MetricKit \(diagnosticReport) diagnostic at timestamp: \(diagnostic.timestamp)")

        let handled = diagnosticReport.isHandled
        var event = Event(level: diagnostic.level ?? (handled ? .warning : .error))
        event.timestamp = diagnostic.timestamp

        if isFromPreviousProcess(diagnostic: diagnostic) {
            // The client doesn't apply the current scope to events from a previous process, so the
            // event itself has to carry the release and the contexts known for the diagnostic.
            event.isFromPreviousProcess = true
            applyMetadata(of: diagnostic.metadata, to: event, runningScope: SentrySDKInternal.currentHub().scope)
        }

        let mechanism = Mechanism(type: diagnosticReport.mechanism)
        mechanism.handled = NSNumber(value: handled)
        mechanism.synthetic = true

        let exception = Exception(value: diagnostic.exceptionValue(), type: diagnosticReport.exceptionType)
        exception.mechanism = mechanism
        event.exceptions = [exception]

        var flamegraphAttachment: Attachment?
        do {
            let callStackTree = try diagnostic.callStackTree()
            flamegraphAttachment = apply(
                callStackTree: callStackTree,
                toEvent: &event,
                useFullCallStackTree: diagnosticReport == .hang,
                isHandled: handled
            )
        } catch {
            SentrySDKLog.error("Failed to decode call stack tree from MetricKit payload: \(error)")

            // Without a decoded stack trace, retain the event only when its raw diagnostic can
            // be attached so the decoding failure can be investigated.
            guard attachDiagnosticAsAttachment else {
                SentrySDKLog.debug("Raw MetricKit diagnostic attachments are disabled, ignoring payload")
                return
            }
        }

        // The crash event can be way from the past. We don't want to impact the current session.
        // Therefore we don't call captureFatalEvent.
        SentrySDKLog.debug("Capturing MetricKit payload event for diagnostic: \(diagnosticReport)")

        // Diagnostic attachments travel in the hint rather than on the scope, because the client
        // doesn't send the scope's attachments with events from a previous process.
        let hint = Hint()
        if let flamegraphAttachment {
            hint.attachments = [flamegraphAttachment]
        }
        if attachDiagnosticAsAttachment, let rawJSON = diagnostic.rawJSON() {
            hint.attachments.append(Attachment(data: rawJSON, filename: diagnostic.rawFilename))
        }

        SentrySDKInternal.capture(event: event, scope: SentrySDKInternal.currentHub().scope, hint: hint)
        SentrySDKLog.debug("Captured MetricKit payload as event")
    }

    private func apply(callStackTree decodedCallStackTree: SentryMXCallStackTree, toEvent event: inout Event, useFullCallStackTree: Bool, isHandled: Bool) -> Attachment? {
        SentrySDKLog.debug("Applying MetricKit call stack tree to event with id: \(event.eventId)")
        guard let exception = event.exceptions?.first else {
            SentrySDKLog.warning("MetricKit event does not have an exception set, skipping call stack tree decoding")
            return nil
        }

        if useFullCallStackTree && hangReportingMode == .flamegraphAttachment,
           let attachment = decodedCallStackTree.flamegraphAttachment(inAppLogic: inAppLogic) {
            return attachment
        }

        let debugMeta = decodedCallStackTree.toDebugMeta()
        let threads: [SentryThread]
        if useFullCallStackTree {
            // Legacy hang reporting preserves every sampled frame and its tree metadata.
            threads = decodedCallStackTree.flattenedBacktrace(inAppLogic: inAppLogic, handled: isHandled)
        } else {
            threads = decodedCallStackTree.sentryMXBacktrace(inAppLogic: inAppLogic, handled: isHandled)
        }

        // First look for the crashing thread, but for events that were not a crash (like a hang) take the first thread
        // since those events only report one thread
        let exceptionThread = threads.first { $0.crashed?.boolValue == true } ?? threads.first
        event.debugMeta = debugMeta
        event.threads = threads

        guard let exceptionThread else {
            SentrySDKLog.warning("MetricKit call stack threads are empty")
            return nil
        }
        exception.stacktrace = exceptionThread.stacktrace
        exception.threadId = exceptionThread.threadId
        return nil
    }
}

#endif
