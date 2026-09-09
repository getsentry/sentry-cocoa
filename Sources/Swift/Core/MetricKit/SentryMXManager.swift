import Foundation

#if os(iOS) || os(macOS) || os(visionOS)

import MetricKit

private let crashMechanism = "MXCrashDiagnostic"
private let diskWriteMechanism = "mx_disk_write_exception"
private let cpuExceptionMechanism = "mx_cpu_exception"
private let hangDiagnosticMechanism = "mx_hang_diagnostic"

protocol CallStackTreeProviding {
    var callStackTree: MXCallStackTree { get }
}

extension MXCrashDiagnostic: CallStackTreeProviding { }
extension MXDiskWriteExceptionDiagnostic: CallStackTreeProviding { }
extension MXCPUExceptionDiagnostic: CallStackTreeProviding { }
extension MXHangDiagnostic: CallStackTreeProviding { }

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryMetricManager {
    func add(_ subscriber: MXMetricManagerSubscriber)
    func remove(_ subscriber: MXMetricManagerSubscriber)
}
extension MXMetricManager: SentryMetricManager {}
#else
typealias SentryMetricManager = MXMetricManager
#endif

final class SentryMXManager: NSObject, MXMetricManagerSubscriber {

    // MARK: - Types

    enum DiagnosticMetric: CaseIterable {
        case crashDiagnostics
        case diskWriteException
        case cpuException
        case hang

        static var all: Set<DiagnosticMetric> {
            .init(allCases)
        }
    }

    private enum ExceptionType {
        fileprivate static let crashDiagnostic = "MXCrashDiagnostic"
        fileprivate static let diskWriteException = "MXDiskWriteException"
        fileprivate static let cpuException = "MXCPUException"
        fileprivate static let hangDiagnostic = "MXHangDiagnostic"
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
    let enabledDiagnostics: Set<DiagnosticMetric>

    init(
        metricManager: SentryMetricManager = MXMetricManager.shared,
        inAppLogic: SentryInAppLogic,
        attachDiagnosticAsAttachment: Bool,
        enabledDiagnostics: Set<DiagnosticMetric> = DiagnosticMetric.all.subtracting([.crashDiagnostics])
    ) {
        self.metricManager = metricManager
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        self.enabledDiagnostics = enabledDiagnostics
        super.init()
    }

    func receiveReports() {
        metricManager.add(self)
    }

    func pauseReports() {
        metricManager.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads.forEach { payload in
            payload.crashDiagnostics?.forEach { diagnostic in
                process(crashDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
            }
            payload.diskWriteExceptionDiagnostics?.forEach { diagnostic in
                process(diskWriteExceptionDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
            }
            payload.cpuExceptionDiagnostics?.forEach { diagnostic in
                process(cpuExceptionDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
            }
            payload.hangDiagnostics?.forEach { diagnostic in
                process(hangDiagnostic: diagnostic, timestamp: payload.timeStampBegin)
            }
        }
    }

    private func process(crashDiagnostic diagnostic: MXCrashDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.crashDiagnostics) else {
            SentrySDKLog.debug("Crash diagnostic are not enabled, skipping payload")
            return
        }

        let exceptionType = String(describing: diagnostic.exceptionType)
        let code = String(describing: diagnostic.exceptionCode)
        let signal = String(describing: diagnostic.signal)

        captureEvent(
            handled: false,
            exceptionValue: "MachException Type:\(exceptionType) Code:\(code) Signal:\(signal)",
            exceptionType: ExceptionType.crashDiagnostic,
            exceptionMechanism: crashMechanism,
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(diskWriteExceptionDiagnostic diagnostic: MXDiskWriteExceptionDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.diskWriteException) else {
            SentrySDKLog.debug("Disk write exception diagnostics are not enabled, skipping payload")
            return
        }

        let totalWritesCaused = measurementFormatter.string(from: diagnostic.totalWritesCaused)

        captureEvent(
            handled: true,
            exceptionValue: "MXDiskWriteException totalWritesCaused:\(totalWritesCaused)",
            exceptionType: ExceptionType.diskWriteException,
            exceptionMechanism: diskWriteMechanism,
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(cpuExceptionDiagnostic diagnostic: MXCPUExceptionDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.cpuException) else {
            SentrySDKLog.debug("CPU exception diagnostics are not enabled, skipping payload")
            return
        }

        let totalCPUTime = measurementFormatter.string(from: diagnostic.totalCPUTime)
        let totalSampledTime = measurementFormatter.string(from: diagnostic.totalSampledTime)

        captureEvent(
            handled: true,
            exceptionValue: "MXCPUException totalCPUTime:\(totalCPUTime) totalSampledTime:\(totalSampledTime)",
            exceptionType: ExceptionType.cpuException,
            exceptionMechanism: cpuExceptionMechanism,
            timeStampBegin: timestamp,
            diagnostic: diagnostic
        )
    }

    private func process(hangDiagnostic diagnostic: MXHangDiagnostic, timestamp: Date) {
        guard enabledDiagnostics.contains(.hang) else {
            SentrySDKLog.debug("Hang diagnostics are not enabled, skipping payload")
            return
        }

        let hangDuration = measurementFormatter.string(from: diagnostic.hangDuration)
        let hangDurationMilliseconds = diagnostic.hangDuration.converted(to: .milliseconds).value
        let level: SentryLevel = hangDurationMilliseconds > 500 ? .error : .warning

        captureEvent(
            handled: true,
            exceptionValue: "MXHangDiagnostic hangDuration:\(hangDuration)",
            exceptionType: ExceptionType.hangDiagnostic,
            exceptionMechanism: hangDiagnosticMechanism,
            timeStampBegin: timestamp,
            diagnostic: diagnostic,
            useFullCallStackTree: true,
            level: level
        )
    }

    func captureEvent(handled: Bool, exceptionValue: String, exceptionType: String, exceptionMechanism: String, timeStampBegin: Date, diagnostic: MXDiagnostic & CallStackTreeProviding, useFullCallStackTree: Bool = false, level: SentryLevel? = nil) {
        let callStackTree: SentryMXCallStackTree
        do {
            let data = diagnostic.callStackTree.jsonRepresentation()
            callStackTree = try SentryMXCallStackTree.from(data: data)
        } catch {
            SentrySDKLog.error("Failed to create SentryMXCallStackTree from MXDiagnostic: \(error)")
            return
        }

        let event = Event(level: level ?? (handled ? .warning : .error))
        event.timestamp = timeStampBegin

        let mechanism = Mechanism(type: exceptionMechanism)
        mechanism.handled = NSNumber(value: handled)
        mechanism.synthetic = true

        let exception = Exception(value: exceptionValue, type: exceptionType)
        exception.mechanism = mechanism
        event.exceptions = [exception]

        capture(
            event: event,
            handled: handled,
            callStackTree: callStackTree,
            diagnosticJSON: diagnostic.jsonRepresentation(),
            useFullCallStackTree: useFullCallStackTree
        )
    }

    func capture(event: Event, handled: Bool, callStackTree: SentryMXCallStackTree, diagnosticJSON: Data, useFullCallStackTree: Bool = false) {
        let debugMeta = callStackTree.toDebugMeta()
        let threads: [SentryThread]
        if useFullCallStackTree {
            // For hang diagnostics, use the flattened tree to preserve all samples
            threads = callStackTree.flattenedBacktrace(inAppLogic: inAppLogic, handled: handled)
        } else {
            threads = callStackTree.sentryMXBacktrace(inAppLogic: inAppLogic, handled: handled)
        }
        // First look for the crashing thread, but for events that were not a crash (like a hang) take the first thread
        // since those events only report one thread
        let exceptionThread = threads.first { $0.crashed?.boolValue == true } ?? threads.first
        event.debugMeta = debugMeta
        event.threads = threads

        if let exceptionThread, let exception = event.exceptions?[0] {
            exception.stacktrace = exceptionThread.stacktrace
            exception.threadId = exceptionThread.threadId
        }
        // The crash event can be way from the past. We don't want to impact the current session.
        // Therefore we don't call captureFatalEvent.
        capture(event: event, diagnosticJSON: diagnosticJSON)
    }

    func capture(event: Event, diagnosticJSON: Data) {
        if attachDiagnosticAsAttachment {
            SentrySDK.capture(event: event) { scope in
                scope.addAttachment(Attachment(data: diagnosticJSON, filename: "MXDiagnosticPayload.json"))
            }
        } else {
            SentrySDK.capture(event: event)
        }
    }
}

extension Event {
    // swiftlint:disable:next missing_docs
    @objc @_spi(Private) public func isMetricKitEvent() -> Bool {
        guard let mechanism = exceptions?.first?.mechanism, exceptions?.count == 1 else {
            return false
        }

        return [crashMechanism, diskWriteMechanism, cpuExceptionMechanism, hangDiagnosticMechanism].contains(mechanism.type)
    }
}

#endif
