@_implementationOnly import _SentryPrivate
import Foundation

/**
 * Describes the Sentry SDK and its configuration used to capture and transmit an event.
 * @note Both name and version are required.
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@_spi(Private) @objc public final class SentrySdkInfo: NSObject, Codable {
    
    @objc public static func global() -> Self {
        if let options = SentrySDKInternal.currentHub().getClient()?.getOptions() {
            let enabledFeatures = SentryDependencyContainerSwiftHelper.enabledFeatures(options)
            return Self(withEnabledFeatures: enabledFeatures, sendDefaultPii: SentryDependencyContainerSwiftHelper.sendDefaultPii(options))
        }
        return Self(withEnabledFeatures: [], sendDefaultPii: false)
    }
    
    /**
     * The name of the SDK. Examples: sentry.cocoa, sentry.cocoa.vapor, ...
     */
    @objc public let name: String
    
    /**
     * The version of the SDK. It should have the Semantic Versioning format MAJOR.MINOR.PATCH, without
     * any prefix (no v or anything else in front of the major version number). Examples:
     * 0.1.0, 1.0.0, 2.0.0-beta0
     */
    @objc public let version: String
    
    /**
     * A list of names identifying enabled integrations. The list should
     * have all enabled integrations, including default integrations. Default
     * integrations are included because different SDK releases may contain different
     * default integrations.
     */
    @objc public let integrations: [String]
    
    /**
     * A list of feature names identifying enabled SDK features. This list
     * should contain all enabled SDK features. On some SDKs, enabling a feature in the
     * options also adds an integration. We encourage tracking such features with either
     * integrations or features but not both to reduce the payload size.
     */
    @objc public let features: [String]
    
    /**
     * A list of packages that were installed as part of this SDK or the
     * activated integrations. Each package consists of a name in the format
     * source:identifier and version.
     */
    @objc public let packages: [[String: String]]
    
    /**
     * A set of settings as part of this SDK.
     */
    @objc public let settings: SentrySDKSettings
    
    @objc public convenience init(withOptions options: Options?) {
        let features = SentryEnabledFeaturesBuilder.getEnabledFeatures(options: options)
        self.init(withEnabledFeatures: features, sendDefaultPii: options?.sendDefaultPii ?? false)
    }

    @objc public convenience init(withEnabledFeatures features: [String], sendDefaultPii: Bool) {
        let integrations = SentrySDKInternal.currentHub().trimmedInstalledIntegrationNames()
        var packages = SentryExtraPackages.getPackages()
        let sdkPackage = SentrySdkPackage.global()
        if let sdkPackage {
            packages.insert(sdkPackage)
        }
        self.init(
            name: SentryMeta.sdkName,
            version: SentryMeta.versionString,
            integrations: integrations,
            features: features,
            packages: Array(packages),
            settings: SentrySDKSettings(sendDefaultPii: sendDefaultPii))
    }
    
    @objc public static func decode(dictionary: [AnyHashable: Any]) -> SentrySdkInfo {
        if let data = try? JSONSerialization.data(withJSONObject: dictionary), let info = try? JSONDecoder.snakeCase.decode(SentrySdkInfo.self, from: data) {
            return info
        }
        return SentrySdkInfo(name: "", version: "", integrations: [], features: [], packages: [], settings: SentrySDKSettings())
    }
    
    @objc public func serialize() -> NSDictionary {
        if let data = try? JSONEncoder.snakeCase.encode(self) {
            return (try? JSONSerialization.jsonObject(with: data) as? NSDictionary) ?? [:]
        }
        return [:]
    }
    
    @objc public init(name: String?, version: String?, integrations: [String]?, features: [String]?, packages: [[String: String]]?, settings: SentrySDKSettings) {
        self.name = name ?? ""
        self.version = version ?? ""
        self.integrations = integrations ?? []
        self.features = features ?? []
        self.packages = packages ?? []
        self.settings = settings
    }
}
