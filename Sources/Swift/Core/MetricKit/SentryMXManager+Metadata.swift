#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Describes a MetricKit event with the app, OS and device metadata the diagnostic was recorded
/// with.
extension SentryMXManager {
    /// Whether the diagnostic was recorded by an earlier run of the app instead of the running
    /// process.
    ///
    /// A diagnostic only counts as the current run's when that is certain. MetricKit reports the
    /// recording process on iOS 17 and macOS 14 and later. Without that, a payload window that
    /// opened after the process started can only hold diagnostics of this run. Everything else is
    /// treated as an earlier run, so the running process's data is never attached by mistake.
    func isFromEarlierAppRun(diagnostic: MXDiagnostic, payloadTimeStampBegin: Date) -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            // MetricKit declares the metadata as nonnull, but a missing one bridges to a pid of 0.
            let pid = diagnostic.metaData.pid
            if pid != 0 {
                return pid != processIdentifier
            }
        }
        return payloadTimeStampBegin < processStartDate
    }

    /// Sets the release and the contexts of an event from an earlier app run.
    ///
    /// The client doesn't apply the scope to such events, so the event has to carry its contexts
    /// itself, reduced to the attributes known for the time the diagnostic was recorded. MetricKit
    /// can deliver a diagnostic after the app or the OS was updated, so the versions come from the
    /// diagnostic and not from the running app.
    func applyMetadata(of diagnostic: MXDiagnostic, to event: Event, runningScope: Scope) {
        applyRelease(
            appVersion: diagnostic.applicationVersion,
            appBuild: diagnostic.metaData.applicationBuildVersion,
            to: event
        )

        var context = event.context ?? [:]
        let contexts: [(key: String, value: [String: Any]?)] = [
            ("app", Self.diagnosticAppContext(for: diagnostic, runningApp: runningScope.getContextForKey("app"))),
            ("os", Self.diagnosticOSContext(for: diagnostic, runningOS: runningScope.getContextForKey("os"))),
            ("device", Self.diagnosticDeviceContext(runningDevice: runningScope.getContextForKey("device"))),
            // The runtime context says whether an iOS app runs on a Mac or through Mac Catalyst,
            // which can't change for the same app on the same device.
            ("runtime", runningScope.getContextForKey("runtime"))
        ]
        for (key, value) in contexts {
            if let value, !value.isEmpty {
                context[key] = value
            }
        }
        if !context.isEmpty {
            event.context = context
        }
    }

    /// Builds the app context from the attributes known for the time the diagnostic was recorded.
    /// Everything that depends on the running build or process, such as the build type or the app
    /// start time, is left out.
    static func diagnosticAppContext(for diagnostic: MXDiagnostic, runningApp: [String: Any]?) -> [String: Any] {
        var appContext: [String: Any] = [:]
        // The bundle identifier doesn't change between builds, so the running one still applies.
        if let appIdentifier = runningApp?["app_identifier"] {
            appContext["app_identifier"] = appIdentifier
        }
        // MetricKit declares these as nonnull, but they bridge to empty strings when missing.
        let appVersion = diagnostic.applicationVersion
        if !appVersion.isEmpty {
            appContext["app_version"] = appVersion
        }
        let appBuild = diagnostic.metaData.applicationBuildVersion
        if !appBuild.isEmpty {
            appContext["app_build"] = appBuild
        }
        return appContext
    }

    /// Builds the OS context from the attributes known for the time the diagnostic was recorded.
    /// The running kernel version and jailbreak state describe today's device, so they are left
    /// out. When MetricKit's OS string can't be parsed, the version and build are left out as
    /// well instead of pairing the diagnostic with the running OS.
    static func diagnosticOSContext(for diagnostic: MXDiagnostic, runningOS: [String: Any]?) -> [String: Any] {
        var osContext: [String: Any] = [:]
        // The OS name doesn't change on a device, so the running one still applies.
        if let name = runningOS?["name"] {
            osContext["name"] = name
        }
        if let osVersion = Self.parseOSVersion(diagnostic.metaData.osVersion) {
            osContext["version"] = osVersion.version
            if let build = osVersion.build {
                osContext["build"] = build
            }
        }
        return osContext
    }

    /// Keeps the device attributes that can't change between app runs on the same device.
    /// Everything the SDK samples while the app runs, such as free memory, the battery level or
    /// the low power mode, is left out.
    static func diagnosticDeviceContext(runningDevice: [String: Any]?) -> [String: Any]? {
        runningDevice?.filter { stableDeviceContextKeys.contains($0.key) }
    }

    private static let stableDeviceContextKeys: Set<String> = [
        "arch",
        "family",
        "model",
        "model_id",
        "simulator",
        "memory_size",
        "screen_height_pixels",
        "screen_width_pixels",
        "ios_app_on_macos",
        "mac_catalyst_app",
        "ios_app_on_visionos"
    ]

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
}

#endif
