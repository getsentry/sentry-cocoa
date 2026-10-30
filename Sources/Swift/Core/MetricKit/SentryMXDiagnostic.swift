#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation
import MetricKit

/// A MetricKit diagnostic in the form the SDK captures it as an event.
///
/// The legacy `MXMetricManager` payloads and the `MetricManager` reports of xOS 27 are both
/// converted to this type, so a diagnostic produces the same event regardless of the API that
/// delivered it.
struct SentryMXDiagnostic {
    /// The process and the app and OS versions the diagnostic was recorded with.
    struct Metadata {
        /// The process that recorded the diagnostic, or `nil` when MetricKit doesn't report it.
        let pid: pid_t?
        /// The SDK's run IDs MetricKit reported as state with the diagnostic. Only reported by
        /// `MetricManager` on iOS and macOS 27 and later.
        var runIds: [UUID] = []
        let appVersion: String
        let appBuild: String
        let osVersion: String?
        let osBuild: String?
    }

    let report: SentryMetricKit.DiagnosticReport
    /// Formats the exception value, which is only needed when the report is enabled.
    let exceptionValue: () -> String
    let level: SentryLevel?
    /// The start of the time range MetricKit reports the diagnostic in.
    let timestamp: Date
    /// The time range MetricKit reports the diagnostic in, which is used to match the diagnostic
    /// to the run that recorded it.
    var timeRange: DateInterval
    /// Why the OS terminated the app, such as `Namespace FRONTBOARD, Code 0x8badf00d`. Only
    /// reported for crashes.
    var terminationReason: String?
    /// Whether the OS watchdog terminated the app, which MetricKit reports as a crash.
    var isWatchdogTermination = false
    let metadata: Metadata
    /// Converts MetricKit's call stack tree, throwing when it has an unexpected format.
    let callStackTree: () throws -> SentryMXCallStackTree
    /// The raw diagnostic as JSON, attached when ``SentrySDKOptions/enableMetricKitRawPayload``
    /// is enabled, or `nil` when it can't be encoded.
    let rawJSON: () -> Data?
    let rawFilename: String

    init(
        report: SentryMetricKit.DiagnosticReport,
        exceptionValue: @escaping () -> String,
        level: SentryLevel? = nil,
        timestamp: Date,
        metadata: Metadata,
        callStackTree: @escaping () throws -> SentryMXCallStackTree,
        rawJSON: @escaping () -> Data?,
        rawFilename: String
    ) {
        self.report = report
        self.exceptionValue = exceptionValue
        self.level = level
        self.timestamp = timestamp
        self.timeRange = DateInterval(start: timestamp, duration: 0)
        self.metadata = metadata
        self.callStackTree = callStackTree
        self.rawJSON = rawJSON
        self.rawFilename = rawFilename
    }
}

extension SentryMXDiagnostic {
    /// What the diagnostic reports about the run that recorded it.
    var run: SentryMXDiagnosticRun {
        SentryMXDiagnosticRun(runIds: metadata.runIds, pid: metadata.pid, timeRange: timeRange)
    }

    /// Whether the diagnostic explains a termination the SDK reports as a watchdog termination: the
    /// OS watchdog or the memory limit terminated the app.
    var confirmsWatchdogTermination: Bool {
        report == .memoryException || isWatchdogTermination
    }

    /// Whether a termination reason is the watchdog's `0x8badf00d` exception code.
    static func isWatchdogTerminationReason(_ reason: String?) -> Bool {
        reason?.lowercased().contains("0x8badf00d") == true
    }

    /// Sets the time range of a legacy payload, whose diagnostics only carry its start.
    func with(payloadTimeStampBegin begin: Date, end: Date) -> SentryMXDiagnostic {
        var diagnostic = self
        diagnostic.timeRange = DateInterval(start: begin, end: max(begin, end))
        return diagnostic
    }
}

extension SentryMXDiagnostic {
    /// Formats the measurements of exception values with US English units, so values don't
    /// depend on the locale of the device.
    static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitOptions = .providedUnit
        return formatter
    }()
}

extension SentryMXDiagnostic {
    /// Converts a diagnostic of a legacy `MXDiagnosticPayload`.
    init(
        report: SentryMetricKit.DiagnosticReport,
        exceptionValue: @autoclosure @escaping () -> String,
        level: SentryLevel? = nil,
        payloadTimeStampBegin: Date,
        diagnostic: MXDiagnostic & SentryMetricKit.CallStackTreeProviding
    ) {
        self.init(
            report: report,
            exceptionValue: exceptionValue,
            level: level,
            timestamp: payloadTimeStampBegin,
            metadata: Metadata(diagnostic),
            callStackTree: {
                try JSONDecoder().decode(SentryMXCallStackTree.self, from: diagnostic.callStackTree.jsonRepresentation())
            },
            rawJSON: {
                let diagnosticJSON = diagnostic.jsonRepresentation()
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: diagnosticJSON)
                    return try JSONSerialization.data(withJSONObject: jsonObject)
                } catch {
                    SentrySDKLog.warning("Failed to compact MetricKit diagnostic JSON: \(error)")
                    return diagnosticJSON
                }
            },
            rawFilename: "MXDiagnosticPayload.json"
        )
    }
}

extension SentryMXDiagnostic.Metadata {
    init(_ diagnostic: MXDiagnostic) {
        var pid: pid_t?
        if #available(iOS 17.0, macOS 14.0, *) {
            // MetricKit declares the metadata as nonnull, but a missing one bridges to a pid of 0.
            let diagnosticPid = diagnostic.metaData.pid
            pid = diagnosticPid == 0 ? nil : diagnosticPid
        }
        let osVersion = Self.parseOSVersion(diagnostic.metaData.osVersion)
        // MetricKit declares the versions as nonnull, but they bridge to empty strings when missing.
        self.init(
            pid: pid,
            appVersion: diagnostic.applicationVersion,
            appBuild: diagnostic.metaData.applicationBuildVersion,
            osVersion: osVersion?.version,
            osBuild: osVersion?.build
        )
    }

    /// Extracts version and build from the MetricKit format, for example
    /// `iPhone OS 18.6.2 (22G100)`.
    static func parseOSVersion(_ osVersion: String) -> (version: String, build: String?)? {
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
}

#endif // os(iOS) || os(macOS) || os(visionOS)
