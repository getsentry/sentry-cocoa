// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) public final class SentryInternalSdkApi {

    private let extraContextProvider: SentryExtraContextProvider

    init(provider: any ExtraContextProviderProvider) {
        self.extraContextProvider = provider.extraContextProvider
    }

    /// The current SDK name.
    public var name: String {
        SentryMeta.sdkName
    }

    /// The current SDK version string.
    public var versionString: String {
        SentryMeta.versionString
    }

    /// Overrides the SDK name and version string.
    public func setName(_ name: String, version: String) {
        SentryMeta.sdkName = name
        SentryMeta.versionString = version
    }

    /// Overrides the SDK name only.
    public func setName(_ name: String) {
        SentryMeta.sdkName = name
    }

    /// Adds a package to the SDK's package list.
    public func addPackage(name: String, version: String) {
        SentryExtraPackages.addPackageName(name, version: version)
    }

    /// Extra context information provided by the SDK.
    public var extraContext: [String: Any] {
        extraContextProvider.getExtraContext()
    }

    /// The unique installation ID for this device/app combination.
    public var installationID: String {
        PrivateSentrySDKOnly.installationID
    }
}
// swiftlint:enable missing_docs
