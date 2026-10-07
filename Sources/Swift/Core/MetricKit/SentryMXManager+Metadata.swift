#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import MetricKit

/// Describes a MetricKit event with the app and OS metadata the diagnostic was recorded with.
extension SentryMXManager {
    // MetricKit can deliver a diagnostic after the app or the OS was updated. Without this, the
    // client describes the event with the release of the running app instead of the release
    // the diagnostic was recorded on.
    func applyMetadata(of diagnostic: MXDiagnostic, to event: Event) {
        applyRelease(
            appVersion: diagnostic.applicationVersion,
            appBuild: diagnostic.metaData.applicationBuildVersion,
            to: event
        )
    }

    /// Builds the app context for a diagnostic from the attributes known for the time it was
    /// recorded. Everything that depends on the running build or process, such as the build
    /// type or the app start time, is left out. Returns `nil` when MetricKit reports neither an
    /// app version nor a build, which keeps the running app context untouched.
    static func diagnosticAppContext(for diagnostic: MXDiagnostic, runningApp: [String: Any]?) -> [String: Any]? {
        // MetricKit declares these as nonnull, but they bridge to empty strings when missing.
        let appVersion = diagnostic.applicationVersion
        let appBuild = diagnostic.metaData.applicationBuildVersion
        guard !appVersion.isEmpty || !appBuild.isEmpty else {
            return nil
        }

        var appContext: [String: Any] = [:]
        if !appVersion.isEmpty {
            appContext["app_version"] = appVersion
        }
        if !appBuild.isEmpty {
            appContext["app_build"] = appBuild
        }
        // The bundle identifier doesn't change between builds, so the running one still applies.
        if let appIdentifier = runningApp?["app_identifier"] {
            appContext["app_identifier"] = appIdentifier
        }
        return appContext
    }

    /// Builds the OS context for a diagnostic from the attributes known for the time it was
    /// recorded. The running kernel version and jailbreak state describe today's device, so they
    /// are left out. Returns `nil` when MetricKit's OS string can't be parsed, which keeps the
    /// running OS context untouched.
    static func diagnosticOSContext(for diagnostic: MXDiagnostic, runningOS: [String: Any]?) -> [String: Any]? {
        guard let osVersion = Self.parseOSVersion(diagnostic.metaData.osVersion) else {
            return nil
        }

        var osContext: [String: Any] = ["version": osVersion.version]
        if let build = osVersion.build {
            osContext["build"] = build
        }
        // The OS name doesn't change on a device, so the running one still applies.
        if let name = runningOS?["name"] {
            osContext["name"] = name
        }
        return osContext
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
}

#endif
