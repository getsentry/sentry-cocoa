#if os(iOS) && compiler(>=6.4) && canImport(StateReporting)
internal import _SentryPrivate
import Foundation
import MetricKit

@available(iOS 27.0, *)
extension SentryMXManager {
    func receiveModernReports() {
        modernReportTask.withLock { task in
            guard task == nil else { return }
            // The task owns its manager, but only retains the SDK manager while processing a report.
            task = Task.detached(priority: .utility) { [weak self] in
                let manager = MetricManager()
                for await report in manager.diagnosticReports {
                    guard !Task.isCancelled else { break }
                    self?.process(modernReport: report)
                }
            }
        }
    }

    func process(modernReport report: DiagnosticReport) {
        let kind: Diagnostic
        let tree: CallStackTree
        let handled: Bool
        let level: SentryLevel
        let value: String
        let exceptionType: String
        switch report.result {
        case .hang(let diagnostic):
            kind = .hang
            tree = diagnostic.callStackTree
            handled = true
            level = diagnostic.hangDuration.converted(to: .milliseconds).value > 500 ? .error : .warning
            value = "HangDiagnostic hangDuration:\(diagnostic.hangDuration)"
            exceptionType = "HangDiagnostic"
        case .crash(let diagnostic):
            let isWatchdog = diagnostic.terminationCategory == .watchdog
            kind = isWatchdog && enabledDiagnostics.contains(.hang) ? .hang : .crash
            tree = diagnostic.callStackTree
            handled = false
            level = kind == .hang ? .fatal : .error
            if kind == .hang {
                value = "App terminated while the main thread was unresponsive."
            } else {
                value = diagnostic.terminationReason?.rawValue ?? "MachException Type:\(String(describing: diagnostic.exceptionType)) Code:\(String(describing: diagnostic.exceptionCode)) Signal:\(String(describing: diagnostic.signal))"
            }
            exceptionType = kind == .hang ? "FatalAppHang" : "CrashDiagnostic"
        case .cpuException(let diagnostic):
            kind = .cpuException
            tree = diagnostic.callStackTree
            handled = true
            level = .warning
            value = "CPUExceptionDiagnostic totalCPUTime:\(diagnostic.totalCPUTime) totalSampledTime:\(diagnostic.totalSampledTime)"
            exceptionType = "CPUExceptionDiagnostic"
        case .diskWriteException(let diagnostic):
            kind = .diskWriteException
            tree = diagnostic.callStackTree
            handled = true
            level = .warning
            value = "DiskWriteExceptionDiagnostic totalBytesWritten:\(diagnostic.totalBytesWritten)"
            exceptionType = "DiskWriteExceptionDiagnostic"
        default:
            return
        }
        guard enabledDiagnostics.contains(kind) else { return }

        var event = Event(level: level)
        event.timestamp = report.timeRange.start
        event.tags = ["metrickit.api": "swift"]
        applyMetadata(of: report, to: event)
        let mechanism = makeMechanism(for: report, kind: kind, handled: handled)
        let exception = Exception(value: value, type: exceptionType)
        exception.mechanism = mechanism
        event.exceptions = [exception]

        capture(report: report, event: &event, kind: kind, tree: tree, handled: handled)
    }

    private func capture(report: DiagnosticReport, event: inout Event, kind: Diagnostic, tree: CallStackTree, handled: Bool) {
        let hint = Hint()
        let convertedTree = Self.convert(callStackTree: tree)
        if let attachment = apply(callStackTree: convertedTree, toEvent: &event, useFullCallStackTree: kind == .hang, isHandled: handled) {
            hint.attachments.append(attachment)
        }
        if attachDiagnosticAsAttachment {
            do {
                hint.attachments.append(Attachment(data: try JSONEncoder().encode(report), filename: "DiagnosticReport.json"))
            } catch {
                SentrySDKLog.error("Failed to encode MetricKit 27 diagnostic report: \(error)")
            }
        }

        // A delayed watchdog report must not end the running app's session.
        SentrySDKInternal.capture(event: event, scope: SentrySDKInternal.currentHub().scope, hint: hint)
        SentrySDKLog.debug("Captured MetricKit Swift diagnostic: \(kind)")
    }

    private func applyMetadata(of report: DiagnosticReport, to event: Event) {
        let environment = report.environment
        if let pid = environment.pid, pid != 0 {
            event.isFromPreviousProcess = pid != processIdentifier
        } else {
            event.isFromPreviousProcess = report.timeRange.start < processStartDate
        }
        // Diagnostic-time values take precedence even when the report is from this process.
        applyRelease(appVersion: environment.applicationVersion, appBuild: environment.applicationBuildVersion, to: event)
        var context: [String: [String: Any]] = [
            "app": [
                "app_identifier": environment.bundleIdentifier,
                "app_version": environment.applicationVersion,
                "app_build": environment.applicationBuildVersion
            ],
            "os": [
                "name": environment.osVersion.platform,
                "version": environment.osVersion.number,
                "build": environment.osVersion.buildNumber
            ],
            "device": [
                "model": environment.deviceType,
                "arch": environment.platformArchitecture,
                "low_power_mode": environment.lowPowerModeEnabled
            ]
        ]
        do {
            // Preserve Apple's state metadata representation alongside the rest of its environment
            // so delayed reports don't depend on the current process's scope or StateReporter state.
            let data = try JSONEncoder().encode(environment)
            context["metrickit"] = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            SentrySDKLog.error("Failed to encode MetricKit 27 diagnostic environment: \(error)")
        }
        event.context = context
    }

    private func makeMechanism(for report: DiagnosticReport, kind: Diagnostic, handled: Bool) -> Mechanism {
        let mechanism = Mechanism(type: kind.mechanism)
        mechanism.handled = NSNumber(value: handled)
        mechanism.synthetic = true
        if case .crash(let diagnostic) = report.result {
            var data: [String: Any] = [:]
            if let category = diagnostic.terminationCategory {
                data["termination_category"] = category.rawValue
            }
            if let reason = diagnostic.terminationReason {
                data["termination_reason"] = reason.rawValue
            }
            mechanism.data = data
        }
        return mechanism
    }

    static func convert(callStackTree tree: CallStackTree) -> SentryMXCallStackTree {
        SentryMXCallStackTree(
            callStacks: tree.callStackThreads.map { thread in
                SentryMXCallStack(threadAttributed: thread.threadAttributed, callStackRootFrames: thread.rootFrames.flatMap { convert(frame: $0, in: tree) })
            },
            callStackPerThread: tree.callStackPerThread
        )
    }

    private static func convert(frame: CallStackFrame, in tree: CallStackTree) -> [SentryMXFrame] {
        let children = frame.subFrames.flatMap { convert(frame: $0, in: tree) }
        // A node without an address can't become a Sentry frame. Retain its addressable descendants.
        guard let address = frame.address else { return children }
        return [SentryMXFrame(
            binaryUUID: frame.binaryUUID,
            offsetIntoBinaryTextSegment: frame.offsetIntoBinaryTextSegment.flatMap { Int(exactly: $0) } ?? -1,
            binaryName: frame.binaryName(from: tree),
            address: address,
            subFrames: children,
            sampleCount: frame.sampleCount
        )]
    }
}
#endif
