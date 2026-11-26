#if os(iOS) || os(macOS) || os(visionOS)
internal import _SentryPrivate
import Foundation

/// Reconstructs the release of the app version and build MetricKit recorded a report with.
///
/// MetricKit can deliver reports after the app was updated, so both diagnostics and metrics use
/// it to describe the release they were recorded with instead of the running one.
struct SentryMXReleaseResolver {
    /// The release name of the running app.
    let releaseName: String?
    let bundleInfo: [String: Any]

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
