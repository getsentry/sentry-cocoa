// swiftlint:disable missing_docs file_length
@_implementationOnly import _SentryPrivate
import Foundation

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalApi {

    // MARK: - Sub-object Accessors

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    public let replay = SentryInternalReplayApi()
    public let performance = SentryInternalPerformanceApi()
    public let screenshot = SentryInternalScreenshotApi()
    public let viewHierarchy = SentryInternalViewHierarchyApi()
    public let screen = SentryInternalScreenApi()
    #endif

    #if SENTRY_TARGET_PROFILING_SUPPORTED
    public let profiling = SentryInternalProfilingApi()
    #endif

    public let appStart = SentryInternalAppStartApi()
    public let envelope = SentryInternalEnvelopeApi()
    public let swizzle = SentryInternalSwizzleApi()

    // MARK: - Direct Methods

    /// Creates a `User` from a dictionary representation.
    public func userWithDictionary(_ dictionary: [String: Any]) -> User {
        PrivateSentrySDKOnly.user(with: dictionary)
    }

    /// Creates a `Breadcrumb` from a dictionary representation.
    public func breadcrumbWithDictionary(_ dictionary: [String: Any]) -> Breadcrumb {
        PrivateSentrySDKOnly.breadcrumb(with: dictionary)
    }

    /// Sets the current trace and span ID on the scope's propagation context.
    public func setTrace(_ traceId: SentryId, spanId: SpanId) {
        PrivateSentrySDKOnly.setTrace(traceId, spanId: spanId)
    }

    /// Sets a custom log output handler for intercepting SDK log messages.
    public func setLogOutput(_ output: @escaping (String) -> Void) {
        PrivateSentrySDKOnly.setLogOutput(output)
    }

    /// Tells the crash reporter to ignore the next occurrence of the given
    /// signal on the calling thread.
    public func ignoreNextSignal(_ signum: Int32) {
        PrivateSentrySDKOnly.ignoreNextSignal(signum)
    }

    /// Overrides the SDK name and version string.
    public func setSdkName(_ name: String, version: String) {
        PrivateSentrySDKOnly.setSdkName(name, andVersionString: version)
    }

    /// Overrides the SDK name only.
    public func setSdkName(_ name: String) {
        PrivateSentrySDKOnly.setSdkName(name)
    }

    /// The current SDK name.
    public var sdkName: String {
        PrivateSentrySDKOnly.getSdkName()
    }

    /// The current SDK version string.
    public var sdkVersionString: String {
        PrivateSentrySDKOnly.getSdkVersionString()
    }

    /// Adds a package to the SDK's package list.
    public func addSdkPackage(name: String, version: String) {
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

    /// The current SDK options, or default options if no client is configured.
    public var options: Options {
        PrivateSentrySDKOnly.options
    }

    /// Creates `Options` from a dictionary representation.
    /// - Throws: An error if the dictionary contains invalid option values.
    public func options(fromDictionary dictionary: [String: Any]) throws -> Options {
        try PrivateSentrySDKOnly.options(with: dictionary)
    }

    /// Retrieves all debug images currently loaded by the process.
    public var debugImages: [DebugMeta] {
        SentryDependencyContainer.sharedInstance().debugImageProvider.getDebugImagesFromCache()
    }

    /// Retrieves debug images for the given raw memory addresses.
    /// - Parameter addresses: Memory addresses to look up.
    /// - Returns: Debug images matching the provided addresses.
    public func debugImages(forAddresses addresses: [UInt64]) -> [DebugMeta] {
        let cache = SentryDependencyContainer.sharedInstance().binaryImageCache
        var result = [DebugMeta]()
        for address in addresses {
            guard let imageInfo = cache.imageByAddress(address) else { continue }
            let debugMeta = DebugMeta()
            debugMeta.imageAddress = String(format: "0x%016llx", imageInfo.address)
            debugMeta.imageSize = NSNumber(value: imageInfo.size)
            debugMeta.codeFile = imageInfo.name
            debugMeta.type = "macho"
            if let uuid = imageInfo.uuid {
                debugMeta.debugID = uuid
            }
            result.append(debugMeta)
        }
        return result
    }
}
// swiftlint:enable missing_docs file_length
