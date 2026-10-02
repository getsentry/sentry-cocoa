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

    typealias Diagnostic = SentryMetricKit.DiagnosticReport

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
    let releaseName: String?
    let bundleInfo: [String: Any]

    init(
        metricManager: SentryMetricManager = MXMetricManager.shared,
        inAppLogic: SentryInAppLogic,
        attachDiagnosticAsAttachment: Bool,
        enabledDiagnostics: Set<Diagnostic> = Diagnostic.all.subtracting([.crash]),
        releaseName: String? = nil,
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        self.metricManager = metricManager
        self.inAppLogic = inAppLogic
        self.attachDiagnosticAsAttachment = attachDiagnosticAsAttachment
        self.enabledDiagnostics = enabledDiagnostics
        self.releaseName = releaseName
        self.bundleInfo = bundleInfo
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

extension SentryMetricKit.DiagnosticReport {
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

    static var all: Set<Self> {
        .init(allCases)
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

        let exceptionType = diagnostic.exceptionType?.stringValue ?? "nil"
        let code = diagnostic.exceptionCode?.stringValue ?? "nil"
        let signal = diagnostic.signal?.stringValue ?? "nil"

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
        applyMetadata(of: diagnostic, to: event)

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
            let attachmentData: Data
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: diagnosticJSON)
                attachmentData = try JSONSerialization.data(withJSONObject: jsonObject)
            } catch {
                SentrySDKLog.warning("Failed to compact MetricKit diagnostic JSON: \(error)")
                attachmentData = diagnosticJSON
            }
            SentrySDK.capture(event: event) { scope in
                scope.addAttachment(Attachment(data: attachmentData, filename: "MXDiagnosticPayload.json"))
            }
        } else {
            SentrySDK.capture(event: event)
        }
        SentrySDKLog.debug("Captured MetricKit payload as event")
    }

    // MetricKit can deliver a diagnostic after the app or the OS was updated. Without this, the
    // client describes the event with the versions of the running app instead of the versions
    // the diagnostic was recorded on.
    private func applyMetadata(of diagnostic: MXDiagnostic, to event: Event) {
        // MetricKit declares these as nonnull, but they bridge to empty strings when missing.
        let appVersion = diagnostic.applicationVersion
        let appBuild = diagnostic.metaData.applicationBuildVersion

        var context = event.context ?? [:]

        var appContext = context["app"] ?? [:]
        if !appVersion.isEmpty {
            appContext["app_version"] = appVersion
        }
        if !appBuild.isEmpty {
            appContext["app_build"] = appBuild
        }
        if !appContext.isEmpty {
            context["app"] = appContext
        }

        if let osVersion = Self.parseOSVersion(diagnostic.metaData.osVersion) {
            var osContext = context["os"] ?? [:]
            osContext["version"] = osVersion.version
            osContext["build"] = osVersion.build
            context["os"] = osContext
        }

        if !context.isEmpty {
            event.context = context
        }

        applyRelease(appVersion: appVersion, appBuild: appBuild, to: event)
    }

    private func applyRelease(appVersion: String, appBuild: String, to event: Event) {
        guard !appVersion.isEmpty, !appBuild.isEmpty else {
            return
        }

        let currentAppVersion = bundleInfo["CFBundleShortVersionString"] as? String
        let currentAppBuild = bundleInfo["CFBundleVersion"] as? String
        guard appVersion != currentAppVersion || appBuild != currentAppBuild else {
            // The release and dist the client applies already match the diagnostic.
            return
        }

        // MetricKit only knows the app version and build, so a custom release name of a
        // previous app version can't be reconstructed. Release and dist stay untouched then,
        // because a dist only has a meaning within its release.
        guard let appIdentifier = bundleInfo["CFBundleIdentifier"] as? String,
              let releaseName,
              releaseName == SentryReleaseName.defaultName(bundleInfo: bundleInfo) else {
            SentrySDKLog.debug("MetricKit diagnostic is from app version \(appVersion) (\(appBuild)), but the release name is custom, keeping the current release")
            return
        }

        event.releaseName = SentryReleaseName.format(appIdentifier: appIdentifier, appVersion: appVersion, appBuild: appBuild)
        event.dist = appBuild
    }

    /// Extracts version and build from the MetricKit format, for example
    /// `iPhone OS 18.6.2 (22G100)`.
    private static func parseOSVersion(_ osVersion: String) -> (version: String, build: String?)? {
        let version = osVersion.split(separator: " ").first { component in
            component.first?.isNumber == true && component.allSatisfy { $0.isNumber || $0 == "." }
        }
        guard let version else {
            return nil
        }

        var build: String?
        if let open = osVersion.lastIndex(of: "("), let close = osVersion.lastIndex(of: ")"), open < close {
            let value = osVersion[osVersion.index(after: open)..<close]
            build = value.isEmpty ? nil : String(value)
        }
        return (String(version), build)
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
