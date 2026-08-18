// swiftlint:disable file_length

import Darwin
import Foundation
import Sentry
import UIKit

final class OS27PrewarmProbe: NSObject {
    static let shared = OS27PrewarmProbe()

    private let queue = DispatchQueue(label: "io.sentry.os27-prewarm-probe")
    private let earlySnapshot: [String: Any]
    private let launchID = UUID().uuidString.lowercased()
    private let launchCreatedAt = Date()
    private var events: [[String: Any]] = []
    private var sentryAppStartMeasurement: [String: Any]?
    private var sentrySpans: [[String: Any]] = []
    private var sentryTransactions: [[String: Any]] = []
    private var displayLink: CADisplayLink?
    private var reachedFirstDisplayLink = false

    override private init() {
        earlySnapshot = OS27PrewarmProbeEarly.snapshot()
        super.init()
    }

    var buildLabel: String {
        stringInfoValue(for: "OS27PrewarmBuildLabel") ?? "manual"
    }

    var sdkGeneration: String {
        stringInfoValue(for: "OS27PrewarmSDKGeneration") ?? "unknown"
    }

    var standaloneTracingEnabled: Bool {
        #if SDK_V10
            return true
        #else
            return boolInfoValue(for: "OS27PrewarmStandaloneTracing")
        #endif
    }

    var activePrewarmDetected: Bool {
        let keys = [
            "activePrewarmAtEarlyConstructor",
            "activePrewarmAtLoad",
            "activePrewarmAtLateConstructor"
        ]
        return keys.contains { (earlySnapshot[$0] as? NSNumber)?.boolValue == true }
    }

    var summaryText: String {
        let prewarm = activePrewarmDetected ? "YES" : "NO"
        return "Build: \(buildLabel)\nSDK generation: \(sdkGeneration)\nStandalone: \(standaloneTracingEnabled)\nActivePrewarm: \(prewarm)\nLaunch ID: \(launchID)"
    }

    func recordMain() {
        record(name: "main")
    }

    func record(
        name: String,
        applicationState: UIApplication.State? = nil,
        details: [String: Any] = [:],
        persistImmediately: Bool = false
    ) {
        let timestamp = Date()
        let continuousTime = mach_continuous_time()
        let activePrewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"

        queue.sync {
            var event: [String: Any] = [
                "activePrewarmEnvironment": activePrewarm,
                "continuousTime": continuousTime,
                "name": name,
                "timestamp": timestamp
            ]
            if let applicationState {
                event["applicationState"] = Self.string(for: applicationState)
            }
            if !details.isEmpty {
                event["details"] = details
            }
            if let processStart = earlySnapshot["processStartTimestamp"] as? Date {
                event["sinceProcessStartMs"] = timestamp.timeIntervalSince(processStart) * 1_000
            }
            if let earlyConstructor = earlySnapshot["earlyConstructorTimestamp"] as? Date {
                event["sinceEarlyConstructorMs"] = timestamp.timeIntervalSince(earlyConstructor) * 1_000
            }
            if let earlyContinuousTime = earlySnapshot["earlyConstructorContinuousTime"] as? NSNumber {
                event["sinceEarlyConstructorContinuousMs"] = Self.milliseconds(
                    from: earlyContinuousTime.uint64Value,
                    to: continuousTime
                )
            }
            events.append(event)

            if persistImmediately || reachedFirstDisplayLink {
                persistReportLocked()
            }
        }
    }

    func startFirstDisplayLinkTracking() {
        guard displayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(firstDisplayLinkFired))
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func captureSentryAppStartMeasurement() {
        guard let measurement = PrivateSentrySDKOnly.appStartMeasurement else { return }

        let type: String
        switch measurement.type {
        case .cold:
            type = "cold"
        case .warm:
            type = "warm"
        case .unknown:
            type = "unknown"
        @unknown default:
            type = "unknown"
        }

        var report: [String: Any] = [
            "appStartTimestamp": measurement.appStartTimestamp,
            "didFinishLaunchingTimestamp": measurement.didFinishLaunchingTimestamp,
            "durationMs": measurement.duration * 1_000,
            "isPreWarmed": measurement.isPreWarmed,
            "moduleInitializationTimestamp": measurement.moduleInitializationTimestamp,
            "runtimeInitSystemTimestamp": measurement.runtimeInitSystemTimestamp,
            "runtimeInitTimestamp": measurement.runtimeInitTimestamp,
            "sdkStartTimestamp": measurement.sdkStartTimestamp,
            "type": type
        ]
        if let measurementWithSpans = PrivateSentrySDKOnly.appStartMeasurementWithSpans() {
            report["measurementWithSpans"] = measurementWithSpans
        }

        queue.sync {
            sentryAppStartMeasurement = report
            persistReportLocked()
        }
    }

    func recordSentrySpan(_ span: Span) {
        guard span.operation == "ui.load" || span.operation.hasPrefix("app.start") else { return }

        var report: [String: Any] = [
            "capturedAt": Date(),
            "data": span.data,
            "operation": span.operation,
            "origin": span.origin,
            "serialized": span.serialize()
        ]
        if let startTimestamp = span.startTimestamp {
            report["startTimestamp"] = startTimestamp
        }
        if let timestamp = span.timestamp {
            report["timestamp"] = timestamp
        }
        if let startTimestamp = span.startTimestamp, let timestamp = span.timestamp {
            report["durationMs"] = timestamp.timeIntervalSince(startTimestamp) * 1_000
        }

        queue.sync {
            sentrySpans.append(report)
            persistReportLocked()
        }
    }

    func recordSentryTransaction(_ transaction: Transaction) {
        let serialized = transaction.serialize()
        var report: [String: Any] = [
            "capturedAt": Date(),
            "serialized": serialized,
            "transaction": transaction.transaction ?? "unknown"
        ]
        if let startTimestamp = transaction.startTimestamp {
            report["startTimestamp"] = startTimestamp
        }
        if let timestamp = transaction.timestamp {
            report["timestamp"] = timestamp
        }

        queue.sync {
            sentryTransactions.append(report)
            persistReportLocked()
        }
    }

    func currentReportURL() -> URL? {
        queue.sync {
            persistReportLocked()
            return reportURLLocked()
        }
    }

    @objc
    private func firstDisplayLinkFired() {
        displayLink?.invalidate()
        displayLink = nil
        queue.sync {
            reachedFirstDisplayLink = true
        }
        record(
            name: "firstDisplayLink",
            applicationState: UIApplication.shared.applicationState,
            persistImmediately: true
        )
        print("OS27_PREWARM_SUMMARY \(summaryText.replacingOccurrences(of: "\n", with: "; "))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OS27PrewarmProbe.shared.captureSentryAppStartMeasurement()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func persistReportLocked() {
        guard
            let url = reportURLLocked(),
            let data = try? JSONSerialization.data(
                withJSONObject: makeReportLocked(),
                options: [.prettyPrinted, .sortedKeys]
            )
        else {
            print("OS27_PREWARM_ERROR Failed to serialize launch report")
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: url.path
            )
        } catch {
            print("OS27_PREWARM_ERROR Failed to persist launch report: \(error)")
        }
    }

    private func makeReportLocked() -> [String: Any] {
        var rawReport: [String: Any] = [
            "activePrewarmDetected": activePrewarmDetected,
            "createdAt": launchCreatedAt,
            "derived": derivedValuesLocked(),
            "early": earlySnapshot,
            "events": events,
            "kind": "launch",
            "launchID": launchID,
            "metadata": metadata(),
            "schemaVersion": 1,
            "sentrySpans": sentrySpans,
            "sentryTransactions": sentryTransactions
        ]
        if let sentryAppStartMeasurement {
            rawReport["sentryAppStartMeasurement"] = sentryAppStartMeasurement
        }
        return Self.jsonValue(rawReport) as? [String: Any] ?? [:]
    }

    private func derivedValuesLocked() -> [String: Any] {
        var values: [String: Any] = [:]
        let processStart = earlySnapshot["processStartTimestamp"] as? Date

        if let processStart, let earlyConstructor = earlySnapshot["earlyConstructorTimestamp"] as? Date {
            values["processToEarlyConstructorMs"] = earlyConstructor.timeIntervalSince(processStart) * 1_000
        }
        if let processStart, let load = earlySnapshot["loadTimestamp"] as? Date {
            values["processToLoadMs"] = load.timeIntervalSince(processStart) * 1_000
        }

        let eventKeys = [
            "main": "processToMainMs",
            "application.didFinishLaunching.begin": "processToDidFinishBeginMs",
            "application.didFinishLaunching.end": "processToDidFinishEndMs",
            "scene.willConnect": "processToSceneWillConnectMs",
            "rootView.viewDidAppear": "processToViewDidAppearMs",
            "firstDisplayLink": "processToFirstDisplayLinkMs"
        ]
        if let processStart {
            for (eventName, resultKey) in eventKeys {
                if let timestamp = events.first(where: { $0["name"] as? String == eventName })?["timestamp"] as? Date {
                    values[resultKey] = timestamp.timeIntervalSince(processStart) * 1_000
                }
            }
        }

        return values
    }

    private func metadata() -> [String: Any] {
        let processInfo = ProcessInfo.processInfo
        let info = Bundle.main.infoDictionary ?? [:]
        let keys = [
            "CFBundleShortVersionString",
            "CFBundleVersion",
            "DTPlatformBuild",
            "DTPlatformVersion",
            "DTSDKBuild",
            "DTSDKName",
            "DTXcode",
            "DTXcodeBuild",
            "GIT_BRANCH",
            "GIT_COMMIT_HASH",
            "GIT_STATUS_CLEAN"
        ]
        var build: [String: Any] = [:]
        for key in keys {
            if let value = info[key] {
                build[key] = value
            }
        }

        #if targetEnvironment(simulator)
            let targetEnvironment = "simulator"
        #else
            let targetEnvironment = "device"
        #endif

        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)

        return [
            "build": build,
            "buildLabel": buildLabel,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unknown",
            "continuousTimebaseDenominator": timebase.denom,
            "continuousTimebaseNumerator": timebase.numer,
            "deviceModel": Self.deviceModel(),
            "lowPowerModeEnabled": processInfo.isLowPowerModeEnabled,
            "operatingSystemVersion": processInfo.operatingSystemVersionString,
            "processArguments": processInfo.arguments,
            "sdkGeneration": sdkGeneration,
            "standaloneTracingEnabled": standaloneTracingEnabled,
            "targetEnvironment": targetEnvironment,
            "thermalState": processInfo.thermalState.rawValue
        ]
    }

    private func reportURLLocked() -> URL? {
        artifactDirectoryLocked()?.appendingPathComponent("launch-\(launchID).json")
    }

    private func artifactDirectoryLocked() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = documents.appendingPathComponent("OS27Prewarm", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: directory.path
            )
            return directory
        } catch {
            print("OS27_PREWARM_ERROR Failed to create artifact directory: \(error)")
            return nil
        }
    }

    private func stringInfoValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    private func boolInfoValue(for key: String) -> Bool {
        guard let value = stringInfoValue(for: key)?.lowercased() else { return false }
        return ["1", "true", "yes"].contains(value)
    }

    private static func jsonValue(_ value: Any) -> Any {
        switch value {
        case let date as Date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        case let data as Data:
            return data.base64EncodedString()
        case let url as URL:
            return url.absoluteString
        case let dictionary as [String: Any]:
            return dictionary.mapValues(jsonValue)
        case let dictionary as [AnyHashable: Any]:
            return Dictionary(uniqueKeysWithValues: dictionary.map { (String(describing: $0.key), jsonValue($0.value)) })
        case let array as [Any]:
            return array.map(jsonValue)
        case is NSNull, is NSString, is NSNumber, is String, is Bool, is Int, is UInt, is Double, is Float:
            return value
        default:
            return String(describing: value)
        }
    }

    private static func string(for state: UIApplication.State) -> String {
        switch state {
        case .active:
            return "active"
        case .background:
            return "background"
        case .inactive:
            return "inactive"
        @unknown default:
            return "unknown"
        }
    }

    private static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
        guard end >= start else { return 0 }
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        guard timebase.denom != 0 else { return 0 }
        let nanoseconds = Double(end - start) * Double(timebase.numer) / Double(timebase.denom)
        return nanoseconds / 1_000_000
    }

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return "unknown" }
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

// swiftlint:enable file_length
