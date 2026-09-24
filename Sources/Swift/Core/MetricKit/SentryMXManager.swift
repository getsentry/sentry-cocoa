#if os(iOS) || os(macOS) || os(visionOS)
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

    enum Diagnostic: CaseIterable {
        case crash
        case diskWriteException
        case cpuException
        case hang

        var exceptionType: String {
            switch self {
            case .crash:
                return "MXCrashDiagnostic"
            case .diskWriteException:
                return "MXDiskWriteException"
            case .cpuException:
                return "MXCPUException"
            case .hang:
                return "MXHangDiagnostic"
            }
        }

        var mechanism: String {
            switch self {
            case .crash:
                return "MXCrashDiagnostic"
            case .diskWriteException:
                return "mx_disk_write_exception"
            case .cpuException:
                return "mx_cpu_exception"
            case .hang:
                return "mx_hang_diagnostic"
            }
        }

        static var all: Set<Diagnostic> {
            .init(allCases)
        }
    }

    // MARK: - Properties

    private let metricManager: SentryMetricManager
    private let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitOptions = .providedUnit
        return formatter
    }()

    let inAppLogic: SentryInAppLogic
    let attachDiagnosticAsAttachment: Bool
    let enabledDiagnostics: Set<Diagnostic>

    init(
        metricManager: SentryMetricManager = MXMetricManager.shared,
        inAppLogic: SentryInAppLogic,
        attachDiagnosticAsAttachment: Bool,
        enabledDiagnostics: Set<Diagnostic> = Diagnostic.all.subtracting([.crash])
    ) {
        self.metricManager = metricManager
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        self.enabledDiagnostics = enabledDiagnostics
        super.init()
    }

    func receiveReports() {
        SentrySDKLog.info("Started receiving reports from MetricKit")
        metricManager.add(self)
    }

    func pauseReports() {
        SentrySDKLog.info("Paused receiving reports from MetricKit")
        metricManager.remove(self)
    }
}

extension SentryMXManager: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
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
        }
    }

    private func process(crashDiagnostic diagnostic: MXCrashDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.crash) else {
            SentrySDKLog.debug("Crash diagnostic are not enabled, skipping payload")
            return
        }
        SentrySDKLog.debug("Processing crash diagnostic at timestamp: \(timestamp)")

        let exceptionType = String(describing: diagnostic.exceptionType)
        let code = String(describing: diagnostic.exceptionCode)
        let signal = String(describing: diagnostic.signal)

        captureEvent(
            handled: false,
            diagnosticReport: .crash,
            exceptionValue: "MachException Type:\(exceptionType) Code:\(code) Signal:\(signal)",
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(diskWriteExceptionDiagnostic diagnostic: MXDiskWriteExceptionDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.diskWriteException) else {
            SentrySDKLog.debug("Disk write exception diagnostics are not enabled, skipping payload")
            return
        }
        SentrySDKLog.debug("Processing disk write exception diagnostic at timestamp: \(timestamp)")

        let totalWritesCaused = measurementFormatter.string(from: diagnostic.totalWritesCaused)

        captureEvent(
            handled: true,
            diagnosticReport: .diskWriteException,
            exceptionValue: "MXDiskWriteException totalWritesCaused:\(totalWritesCaused)",
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(cpuExceptionDiagnostic diagnostic: MXCPUExceptionDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.cpuException) else {
            SentrySDKLog.debug("CPU exception diagnostics are not enabled, skipping payload")
            return
        }
        SentrySDKLog.debug("Processing CPU exception diagnostic at timestamp: \(timestamp)")

        let totalCPUTime = measurementFormatter.string(from: diagnostic.totalCPUTime)
        let totalSampledTime = measurementFormatter.string(from: diagnostic.totalSampledTime)

        captureEvent(
            handled: true,
            diagnosticReport: .cpuException,
            exceptionValue: "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)",
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(hangDiagnostic diagnostic: MXHangDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.hang) else {
            SentrySDKLog.debug("Hang diagnostics are not enabled, skipping payload")
            return
        }
        SentrySDKLog.debug("Processing hang diagnostic at timestamp: \(timestamp)")

        let hangDuration = measurementFormatter.string(from: diagnostic.hangDuration)
        let hangDurationMilliseconds = diagnostic.hangDuration.converted(to: .milliseconds).value
        let level: SentryLevel = hangDurationMilliseconds > 500 ? .error : .warning

        captureEvent(
            handled: true,
            diagnosticReport: .hang,
            exceptionValue: "MXHangDiagnostic hangDuration:\(hangDuration)",
            timeStampBegin: timestamp,
            diagnostic: diagnostic,
            useFullCallStackTree: true,
            level: level
        )
    }

    private func captureEvent(
        handled: Bool,
        diagnosticReport: Diagnostic,
        exceptionValue: String,
        timeStampBegin: Date,
        diagnostic: MXDiagnostic & SentryMetricKit.CallStackTreeProviding,
        useFullCallStackTree: Bool = false,
        level: SentryLevel? = nil
    ) {
        var event = Event(level: level ?? (handled ? .warning : .error))
        event.timestamp = timeStampBegin

        let mechanism = Mechanism(type: diagnosticReport.mechanism)
        mechanism.handled = NSNumber(value: handled)
        mechanism.synthetic = true

        let exception = Exception(value: exceptionValue, type: diagnosticReport.exceptionType)
        exception.mechanism = mechanism
        event.exceptions = [exception]

        do {
            try apply(
                callStackTree: diagnostic.callStackTree,
                toEvent: &event,
                useFullCallStackTree: useFullCallStackTree,
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
        if attachDiagnosticAsAttachment {
            let diagnosticJSON = diagnostic.jsonRepresentation()
            SentrySDK.capture(event: event) { scope in
                scope.addAttachment(Attachment(data: diagnosticJSON, filename: "MXDiagnosticPayload.json"))
            }
        } else {
            SentrySDK.capture(event: event)
        }
        SentrySDKLog.debug("Captured MetricKit payload as event")
    }

    private func apply(callStackTree: MXCallStackTree, toEvent event: inout Event, useFullCallStackTree: Bool, isHandled: Bool) throws {
        SentrySDKLog.debug("Applying MetricKit call stack tree to event with id: \(event.eventId)")
        guard let exception = event.exceptions?.first else {
            SentrySDKLog.warning("MetricKit event does not have an exception set, skipping call stack tree decoding")
            return
        }

        let encodedCallStackTree = callStackTree.jsonRepresentation()
        let decodedCallStackTree = try SentryMXCallStackTree.from(data: encodedCallStackTree)

        let debugMeta = decodedCallStackTree.toDebugMeta()
        let threads: [SentryThread]
        if useFullCallStackTree {
            // For hang diagnostics, use the flattened tree to preserve all samples
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
            return
        }
        exception.stacktrace = exceptionThread.stacktrace
        exception.threadId = exceptionThread.threadId
    }
}

#endif
