// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) public final class SentryInternalSdkApi {

    /// The current SDK name.
    public var name: String {
        PrivateSentrySDKOnly.getSdkName()
    }

    /// The current SDK version string.
    public var versionString: String {
        PrivateSentrySDKOnly.getSdkVersionString()
    }

    /// Overrides the SDK name and version string.
    public func setName(_ name: String, version: String) {
        PrivateSentrySDKOnly.setSdkName(name, andVersionString: version)
    }

    /// Overrides the SDK name only.
    public func setName(_ name: String) {
        PrivateSentrySDKOnly.setSdkName(name)
    }

    /// Adds a package to the SDK's package list.
    public func addPackage(name: String, version: String) {
        PrivateSentrySDKOnly.addSdkPackage(name, version: version)
    }

    /// Extra context information provided by the SDK.
    public var extraContext: [String: Any] {
        PrivateSentrySDKOnly.getExtraContext() as? [String: Any] ?? [:]
    }

    /// The unique installation ID for this device/app combination.
    public var installationID: String {
        PrivateSentrySDKOnly.installationID
    }
}
// swiftlint:enable missing_docs
