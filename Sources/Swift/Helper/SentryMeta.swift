import Foundation

/// Identifies this SDK to Sentry. Hybrid SDKs override both values so events are attributed to
/// them instead of the Cocoa SDK.
@objc(SentryMeta) @_spi(Private) public final class SentryMeta: NSObject {
    /// The SDK version.
    ///
    /// `Utils/VersionBump` rewrites this during releases by matching the declaration below, so keep
    /// it on a single line and keep this the first version-shaped literal in the file.
    @objc public static var versionString = "9.24.0"

    /// The SDK name reported to Sentry, e.g. `sentry.cocoa`.
    @objc public static var sdkName = "sentry.cocoa"
}
