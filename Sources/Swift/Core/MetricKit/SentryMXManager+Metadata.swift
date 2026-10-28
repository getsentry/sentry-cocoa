#if os(iOS) || os(macOS) || os(visionOS)
import Foundation

/// Describes a MetricKit event with the app, OS and device metadata the diagnostic was recorded
/// with.
extension SentryMXManager {
    /// Whether the diagnostic was recorded by a previous process of the app instead of the running
    /// process.
    ///
    /// A diagnostic only counts as the current run's when that is certain. MetricKit reports the
    /// recording process on iOS 17 and macOS 14 and later. Without that, a diagnostic reported
    /// after the process started can only belong to this run. Everything else is
    /// treated as a previous process, so the running process's data is never attached by mistake.
    func isFromPreviousProcess(diagnostic: SentryMXDiagnostic) -> Bool {
        if let pid = diagnostic.metadata.pid {
            return pid != processIdentifier
        }
        return diagnostic.timestamp < processStartDate
    }

    /// Sets the release and the contexts of an event from a previous process.
    ///
    /// The client doesn't apply the scope to such events, so the event has to carry its contexts
    /// itself, reduced to the attributes known for the time the diagnostic was recorded. MetricKit
    /// can deliver a diagnostic after the app or the OS was updated, so the versions come from the
    /// diagnostic and not from the running app.
    func applyMetadata(of metadata: SentryMXDiagnostic.Metadata, to event: Event, runningScope: Scope) {
        applyRelease(appVersion: metadata.appVersion, appBuild: metadata.appBuild, to: event)

        var context = event.context ?? [:]
        let appContext = Self.diagnosticAppContext(for: metadata, runningApp: runningScope.getContextForKey("app"))
        if !appContext.isEmpty {
            context["app"] = appContext
        }
        let osContext = Self.diagnosticOSContext(for: metadata, runningOS: runningScope.getContextForKey("os"))
        if !osContext.isEmpty {
            context["os"] = osContext
        }
        if let deviceContext = Self.diagnosticDeviceContext(runningDevice: runningScope.getContextForKey("device")), !deviceContext.isEmpty {
            context["device"] = deviceContext
        }
        // The runtime context says whether an iOS app runs on a Mac or through Mac Catalyst,
        // which can't change for the same app on the same device.
        if let runtimeContext = runningScope.getContextForKey("runtime"), !runtimeContext.isEmpty {
            context["runtime"] = runtimeContext
        }
        if !context.isEmpty {
            event.context = context
        }
    }

    /// Builds the app context from the attributes known for the time the diagnostic was recorded.
    /// Everything that depends on the running build or process, such as the build type or the app
    /// start time, is left out.
    static func diagnosticAppContext(for metadata: SentryMXDiagnostic.Metadata, runningApp: [String: Any]?) -> [String: Any] {
        var appContext: [String: Any] = [:]
        // The bundle identifier doesn't change between builds, so the running one still applies.
        if let appIdentifier = runningApp?["app_identifier"] {
            appContext["app_identifier"] = appIdentifier
        }
        if !metadata.appVersion.isEmpty {
            appContext["app_version"] = metadata.appVersion
        }
        if !metadata.appBuild.isEmpty {
            appContext["app_build"] = metadata.appBuild
        }
        return appContext
    }

    /// Builds the OS context from the attributes known for the time the diagnostic was recorded.
    /// The running kernel version and jailbreak state describe today's device, so they are left
    /// out. When MetricKit doesn't report a parsable OS version, the version and build are left
    /// out as well instead of pairing the diagnostic with the running OS.
    static func diagnosticOSContext(for metadata: SentryMXDiagnostic.Metadata, runningOS: [String: Any]?) -> [String: Any] {
        var osContext: [String: Any] = [:]
        // The OS name doesn't change on a device, so the running one still applies.
        if let name = runningOS?["name"] {
            osContext["name"] = name
        }
        if let osVersion = metadata.osVersion {
            osContext["version"] = osVersion
            if let osBuild = metadata.osBuild {
                osContext["build"] = osBuild
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

    /// The device context keys that `SentryDefaultScopeContextEnricher.enrichScopeWithDeviceData`
    /// sets and that stay the same between app runs on the same device. The enricher also sets
    /// `free_memory`, `usable_memory` and `locale`, which can change between runs and are left
    /// out. Other integrations add mutable attributes, such as `low_power_mode` or
    /// `battery_level`, which are left out as well.
    ///
    /// When adding a key to the enricher, add it here when it can't change for the same device,
    /// and otherwise add it to the mutable keys in
    /// `SentryMXManagerMetadataTests.testDiagnosticDeviceContext_whenScopeIsEnriched_shouldDropOnlyMutableKeys`,
    /// which fails for keys that aren't listed in either place.
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
        guard let recordedReleaseName = releaseName(appVersion: appVersion, appBuild: appBuild) else {
            return
        }
        event.releaseName = recordedReleaseName
        event.dist = appBuild
    }

    /// The release name of the app version and build MetricKit recorded a report with, or `nil`
    /// when the running release already describes it or the release can't be reconstructed.
    func releaseName(appVersion: String, appBuild: String) -> String? {
        guard !appVersion.isEmpty, !appBuild.isEmpty else {
            return nil
        }

        let currentAppVersion = bundleInfo["CFBundleShortVersionString"] as? String
        let currentAppBuild = bundleInfo["CFBundleVersion"] as? String
        guard appVersion != currentAppVersion || appBuild != currentAppBuild else {
            // The release and dist the SDK applies already match the report.
            return nil
        }

        // MetricKit only knows the app version and build, so a custom release name of a
        // previous app version can't be reconstructed. Release and dist stay untouched then,
        // because a dist only has a meaning within its release.
        guard let appIdentifier = bundleInfo["CFBundleIdentifier"] as? String,
              let releaseName,
              releaseName == SentryReleaseName.defaultName(bundleInfo: bundleInfo) else {
            SentrySDKLog.debug("MetricKit report is from app version \(appVersion) (\(appBuild)), but the release name is custom, keeping the current release")
            return nil
        }

        return SentryReleaseName.format(appIdentifier: appIdentifier, appVersion: appVersion, appBuild: appBuild)
    }
}

#endif
