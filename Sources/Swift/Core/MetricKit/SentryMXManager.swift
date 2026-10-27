#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation
import MetricKit

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber)
    func remove(_ subscriber: MXMetricManagerSubscriber)
}
extension MXMetricManager: SentryMetricManager {}
#else
typealias SentryMetricManager = MXMetricManager
#endif

final class SentryMXManager: NSObject {
    // MARK: - Types

    typealias Diagnostic = SentryMetricKit.DiagnosticReport

    // MARK: - Properties

    private let metricManager: SentryMetricManager
    /// The `SentryDiagnosticReportSource` that delivers diagnostics on xOS 27 and later, or `nil`
    /// to use `MetricManager`. Stored properties can't be limited to an OS version, so the source
    /// is stored untyped.
    private let diagnosticReportSource: Any?
    private let diagnosticReportsTask = SentryMutex<Task<Void, Never>?>(nil)
    let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitOptions = .providedUnit
        return formatter
    }()

    let inAppLogic: SentryInAppLogic
    let attachDiagnosticAsAttachment: Bool
    let enabledDiagnostics: Set<Diagnostic>
    let releaseName: String?
    let bundleInfo: [String: Any]
    let hangReportingMode: SentryMetricKitHangReportingMode
    let processIdentifier: pid_t
    let processStartDate: Date

    init(
        metricManager: SentryMetricManager = MXMetricManager.shared,
        diagnosticReportSource: Any? = nil,
        inAppLogic: SentryInAppLogic,
        attachDiagnosticAsAttachment: Bool,
        enabledDiagnostics: Set<Diagnostic> = Diagnostic.all.subtracting([.crash, .memoryException]),
        releaseName: String? = nil,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:],
        hangReportingMode: SentryMetricKitHangReportingMode = .legacy,
        processIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier,
        processStartDate: Date
    ) {
        self.metricManager = metricManager
        self.diagnosticReportSource = diagnosticReportSource
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        self.enabledDiagnostics = enabledDiagnostics
        self.releaseName = releaseName
        self.bundleInfo = bundleInfo
        self.hangReportingMode = hangReportingMode
        self.processIdentifier = processIdentifier
        self.processStartDate = processStartDate
        super.init()
    }

    func receiveReports() {
        #if compiler(>=6.4)
        // MetricManager replaces MXMetricManager for diagnostics on xOS 27. The subscriber stays
        // registered for metric payloads but ignores its diagnostic payloads while MetricManager
        // delivers them, so the same diagnostic can't be captured twice.
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *), !enabledDiagnostics.isEmpty {
            SentrySDKLog.info("Started receiving diagnostic reports from MetricManager")
            let source = diagnosticReportSource as? SentryDiagnosticReportSource ?? MetricManager()
            receiveDiagnosticReports(from: source)
        }
        #endif // compiler(>=6.4)
        SentrySDKLog.info("Started receiving reports from MetricKit")
        metricManager.add(self)
    }

    func pauseReports() {
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            pauseDiagnosticReports()
        }
        #endif // compiler(>=6.4)
        SentrySDKLog.info("Paused receiving reports from MetricKit")
        metricManager.remove(self)
    }

    /// Whether `MetricManager` delivers the diagnostics instead of the `MXMetricManager` subscriber.
    var receivesDiagnosticsFromMetricManager: Bool {
        diagnosticReportsTask.withLock { $0 != nil }
    }

    /// Stores the task that iterates the diagnostic reports of `MetricManager` and cancels the
    /// previous one.
    func replaceDiagnosticReportsTask(with task: Task<Void, Never>?) {
        let previousTask = diagnosticReportsTask.withLock { current in
            let previousTask = current
            current = task
            return previousTask
        }
        previousTask?.cancel()
    }
}

extension SentryMXManager: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !receivesDiagnosticsFromMetricManager else {
            SentrySDKLog.debug("Diagnostics are received from MetricManager, ignoring \(payloads.count) MetricKit diagnostic payloads")
            return
        }
        process(diagnosticPayloads: payloads)
    }

    func process(diagnosticPayloads payloads: [MXDiagnosticPayload]) {
        SentrySDKLog.info("Received \(payloads.count) MetricKit diagnostic payloads")
        payloads.forEach { payload in
            if let diagnostics = payload.crashDiagnostics {
                SentrySDKLog.info("Received \(diagnostics.count) MetricKit crash diagnostics")
                diagnostics.forEach { diagnostic in
                    process(crashDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
                }
            }
            if let diagnostics = payload.diskWriteExceptionDiagnostics {
                SentrySDKLog.info("Received \(diagnostics.count) MetricKit disk write exception diagnostics")
                diagnostics.forEach { diagnostic in
                    process(diskWriteExceptionDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
                }
            }
            if let diagnostics = payload.cpuExceptionDiagnostics {
                SentrySDKLog.info("Received \(diagnostics.count) MetricKit CPU exception diagnostics")
                diagnostics.forEach { diagnostic in
                    process(cpuExceptionDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
                }
            }
            if let diagnostics = payload.hangDiagnostics {
                SentrySDKLog.info("Received \(diagnostics.count) MetricKit hang diagnostics")
                diagnostics.forEach { diagnostic in
                    process(hangDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
                }
            }
            #if os(iOS) || os(visionOS)
            if #available(iOS 16.0, *), let diagnostics = payload.appLaunchDiagnostics {
                SentrySDKLog.info("Received \(diagnostics.count) MetricKit app launch diagnostics")
                diagnostics.forEach { diagnostic in
                    process(appLaunchDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
                }
            }
            #endif // os(iOS) || os(visionOS)
        }
    }

    private func process(crashDiagnostic diagnostic: MXCrashDiagnostic, timestamp: Date) {
        let exceptionType = diagnostic.exceptionType?.stringValue ?? "nil"
        let code = diagnostic.exceptionCode?.stringValue ?? "nil"
        let signal = diagnostic.signal?.stringValue ?? "nil"

        capture(SentryMXDiagnostic(
            report: .crash,
            exceptionValue: Self.crashExceptionValue(exceptionType: exceptionType, code: code, signal: signal),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        ))
    }

    private func process(diskWriteExceptionDiagnostic diagnostic: MXDiskWriteExceptionDiagnostic, timestamp: Date) {
        capture(SentryMXDiagnostic(
            report: .diskWriteException,
            exceptionValue: self.diskWriteExceptionValue(totalWritesCaused: diagnostic.totalWritesCaused),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        ))
    }

    private func process(cpuExceptionDiagnostic diagnostic: MXCPUExceptionDiagnostic, timestamp: Date) {
        capture(SentryMXDiagnostic(
            report: .cpuException,
            exceptionValue: self.cpuExceptionValue(totalCPUTime: diagnostic.totalCPUTime, totalSampledTime: diagnostic.totalSampledTime),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        ))
    }

    private func process(hangDiagnostic diagnostic: MXHangDiagnostic, timestamp: Date) {
        capture(SentryMXDiagnostic(
            report: .hang,
            exceptionValue: self.hangExceptionValue(hangDuration: diagnostic.hangDuration),
            level: Self.hangLevel(hangDuration: diagnostic.hangDuration),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        ))
    }

    #if os(iOS) || os(visionOS)
    @available(iOS 16.0, *)
    private func process(appLaunchDiagnostic diagnostic: MXAppLaunchDiagnostic, timestamp: Date) {
        capture(SentryMXDiagnostic(
            report: .appLaunch,
            exceptionValue: self.appLaunchExceptionValue(launchDuration: diagnostic.launchDuration),
            payloadTimeStampBegin: timestamp,
            diagnostic: diagnostic
        ))
    }
    #endif // os(iOS) || os(visionOS)
}

// MARK: - Event

extension SentryMXManager {
    static func crashExceptionValue(exceptionType: String, code: String, signal: String) -> String {
        "MachException Type:\(exceptionType) Code:\(code) Signal:\(signal)"
    }

    func diskWriteExceptionValue(totalWritesCaused: Measurement<UnitInformationStorage>) -> String {
        "MXDiskWriteException totalWritesCaused:\(measurementFormatter.string(from: totalWritesCaused))"
    }

    func cpuExceptionValue(totalCPUTime: Measurement<UnitDuration>, totalSampledTime: Measurement<UnitDuration>) -> String {
        let totalCPUTime = measurementFormatter.string(from: totalCPUTime)
        let totalSampledTime = measurementFormatter.string(from: totalSampledTime)
        return "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)"
    }

    func hangExceptionValue(hangDuration: Measurement<UnitDuration>) -> String {
        "MXHangDiagnostic hangDuration:\(measurementFormatter.string(from: hangDuration))"
    }

    func appLaunchExceptionValue(launchDuration: Measurement<UnitDuration>) -> String {
        "MXAppLaunchDiagnostic launchDuration:\(measurementFormatter.string(from: launchDuration))"
    }

    static func hangLevel(hangDuration: Measurement<UnitDuration>) -> SentryLevel {
        hangDuration.converted(to: .milliseconds).value > 500 ? .error : .warning
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
