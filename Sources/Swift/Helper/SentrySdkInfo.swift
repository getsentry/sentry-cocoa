@_implementationOnly import _SentryPrivate

/**
 * Describes the Sentry SDK and its configuration used to capture and transmit an event.
 * @note Both name and version are required.
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@_spi(Private) @objc public final class SentrySdkInfo: NSObject, SentrySerializable {
    
    @objc public static func global() -> Self {
        Self(withOptions: SentrySDK.currentHub().getClient()?.options)
    }
    
    /**
     * The name of the SDK. Examples: sentry.cocoa, sentry.cocoa.vapor, ...
     */
    let name: String
    
    /**
     * The version of the SDK. It should have the Semantic Versioning format MAJOR.MINOR.PATCH, without
     * any prefix (no v or anything else in front of the major version number). Examples:
     * 0.1.0, 1.0.0, 2.0.0-beta0
     */
    let version: String
    
    /**
     * A list of names identifying enabled integrations. The list should
     * have all enabled integrations, including default integrations. Default
     * integrations are included because different SDK releases may contain different
     * default integrations.
     */
    let integrations: NSArray
    
    /**
     * A list of feature names identifying enabled SDK features. This list
     * should contain all enabled SDK features. On some SDKs, enabling a feature in the
     * options also adds an integration. We encourage tracking such features with either
     * integrations or features but not both to reduce the payload size.
     */
    let features: [String]
    
    /**
     * A list of packages that were installed as part of this SDK or the
     * activated integrations. Each package consists of a name in the format
     * source:identifier and version.
     */
    let packages: NSArray
    
    @objc public convenience init(withOptions options: Options?) {
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        let integrations = SentrySDK.currentHub().trimmedInstalledIntegrationNames()
        #if SENTRY_HAS_UIKIT
            if options.enablePreWarmedAppStartTracing {
                integrations.add("PreWarmedAppStartTracing")
            }
        #endif
        let packages = SentryExtraPackages.getPackages()
        let sdkPackage = SentrySdkPackage.global()
        if let sdkPackage {
            packages.add(sdkPackage)
        }
        self.init(
            name: SentryMeta.sdkName,
            version: SentryMeta.versionString,
            integrations: integrations,
            features: features,
            packages: packages.allObjects as NSArray)
    }
    
    init(name: String?, version: String?, integrations: NSArray?, features: [String]?, packages: NSArray?) {
        self.name = name ?? ""
        self.version = version ?? ""
        self.integrations = integrations ?? []
        self.features = features ?? []
        self.packages = packages ?? []
    }
    
    // swiftlint:disable cyclomatic_complexity
    @objc
    public convenience init(dict: [String: Any]) {
        var name = ""
        var version = ""
        var integrations = Set<String>()
        var features = Set<String>()
        var packages = Set<[String: String]>()

        if let nameValue = dict["name"] as? String {
            name = nameValue
        }

        if let versionValue = dict["version"] as? String {
            version = versionValue
        }

        if let integrationArray = dict["integrations"] as? [Any] {
            for item in integrationArray {
                if let integration = item as? String {
                    integrations.insert(integration)
                }
            }
        }

        if let featureArray = dict["features"] as? [Any] {
            for item in featureArray {
                if let feature = item as? String {
                    features.insert(feature)
                }
            }
        }

        if let packageArray = dict["packages"] as? [Any] {
            for item in packageArray {
                if let package = item as? [String: Any],
                   let name = package["name"] as? String,
                   let version = package["version"] as? String {
                    packages.insert(["name": name, "version": version])
                }
            }
        }

        self.init(
            name: name,
            version: version,
            integrations: Array(integrations) as NSArray,
            features: Array(features),
            packages: Array(packages) as NSArray
        )
    }
    // swiftlint:enable cyclomatic_complexity
    
    public func serialize() -> [String: Any] {
        [
            "name": self.name,
            "version": self.version,
            "integrations": self.integrations,
            "features": self.features,
            "packages": self.packages
        ]
    }
}
