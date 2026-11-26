import Foundation

/// The release name format the SDK uses when the app doesn't configure its own.
enum SentryReleaseName {
    static func format(appIdentifier: String, appVersion: String, appBuild: String) -> String {
        "\(appIdentifier)@\(appVersion)+\(appBuild)"
    }

    static func defaultName(bundleInfo: [String: Any]?) -> String? {
        guard let bundleInfo else { return nil }

        return format(
            appIdentifier: "\(bundleInfo["CFBundleIdentifier"] ?? "")",
            appVersion: "\(bundleInfo["CFBundleShortVersionString"] ?? "")",
            appBuild: "\(bundleInfo["CFBundleVersion"] ?? "")"
        )
    }
}
