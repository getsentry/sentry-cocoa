// swiftlint:disable missing_docs
import Foundation

/// Provides access to SDK metadata such as name, version, packages, and installation context.
public struct SentryInternalSdkApi {

    typealias Dependencies = ExtraContextProviderProvider
        & SdkMetadataProviderProvider
        & SdkPackagesProviderProvider
        & InstallationIdProviderProvider

    private let extraContextProvider: SentryExtraContextProvider
    private let sdkMetadataProvider: SdkMetadataProvider
    private let sdkPackagesProvider: SdkPackagesProvider
    private let installationIdProvider: InstallationIdProvider

    init(dependencies: Dependencies) {
        self.extraContextProvider = dependencies.extraContextProvider
        self.sdkMetadataProvider = dependencies.sdkMetadataProvider
        self.sdkPackagesProvider = dependencies.sdkPackagesProvider
        self.installationIdProvider = dependencies.installationIdProvider
    }

    /// The SDK name reported in event payloads.
    public var name: String {
        get { sdkMetadataProvider.sdkName }
        nonmutating set { sdkMetadataProvider.sdkName = newValue }
    }

    /// The SDK version string reported in event payloads.
    public var versionString: String {
        get { sdkMetadataProvider.sdkVersion }
        nonmutating set { sdkMetadataProvider.sdkVersion = newValue }
    }

    /// Sets both the SDK name and version in a single call.
    public func setName(_ name: String, version: String) {
        sdkMetadataProvider.sdkName = name
        sdkMetadataProvider.sdkVersion = version
    }

    /// Registers an additional SDK package dependency.
    public func addPackage(name: String, version: String) {
        sdkPackagesProvider.addPackage(name: name, version: version)
    }

    /// Additional context provided by the SDK for event enrichment.
    public var extraContext: [String: Any] {
        extraContextProvider.getExtraContext()
    }

    /// A unique identifier for this SDK installation, persisted across app launches.
    public var installationID: String {
        installationIdProvider.installationID
    }
}
// swiftlint:enable missing_docs
