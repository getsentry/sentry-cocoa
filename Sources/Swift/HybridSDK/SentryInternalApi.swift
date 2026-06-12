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

    private let clientProvider: any ClientProvider

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    public let replay: SentryInternalReplayApi
    public let performance: SentryInternalPerformanceApi
    public let screenshot: SentryInternalScreenshotApi
    public let viewHierarchy: SentryInternalViewHierarchyApi
    public let screen: SentryInternalScreenApi
    #endif

    #if SENTRY_TARGET_PROFILING_SUPPORTED
    public let profiling = SentryInternalProfilingApi()
    #endif

    public let appStart = SentryInternalAppStartApi()
    public let envelope: SentryInternalEnvelopeApi
    public let swizzle = SentryInternalSwizzleApi()
    public let sdk: SentryInternalSdkApi
    public let debug: SentryInternalDebugApi
    public let breadcrumbs = SentryInternalBreadcrumbApi()
    public let user = SentryInternalUserApi()

    init() {
        let container = SentryDependencyContainer.sharedInstance()
        self.clientProvider = container
        self.debug = SentryInternalDebugApi(provider: container)
        self.envelope = SentryInternalEnvelopeApi(provider: container)
        self.sdk = SentryInternalSdkApi(provider: container)
        #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
        self.performance = SentryInternalPerformanceApi(provider: container)
        self.replay = SentryInternalReplayApi(provider: container)
        self.screenshot = SentryInternalScreenshotApi(provider: container)
        self.viewHierarchy = SentryInternalViewHierarchyApi(provider: container)
        self.screen = SentryInternalScreenApi(provider: container)
        #endif
    }

    // MARK: - Direct Methods

    /// Sets the current trace and span ID on the scope's propagation context.
    public func setTrace(_ traceId: SentryId, spanId: SpanId) {
        PrivateSentrySDKOnly.setTrace(traceId, spanId: spanId)
    }

    /// Sets a custom log output handler for intercepting SDK log messages.
    public func setLogOutput(_ output: @escaping (String) -> Void) {
        SentrySDKLog.setOutput(output)
    }

    /// Tells the crash reporter to ignore the next occurrence of the given
    /// signal on the calling thread.
    public func ignoreNextSignal(_ signum: Int32) {
        sentrycrash_ignore_next_signal(signum)
    }

    /// The current SDK options, or default options if no client is configured.
    public var options: Options {
        clientProvider.client?.getOptions() as? Options ?? Options()
    }

    /// Creates `Options` from a dictionary representation.
    /// - Throws: An error if the dictionary contains invalid option values.
    public func options(fromDictionary dictionary: [String: Any]) throws -> Options {
        guard let result = try SentryOptionsInternal.options(fromDict: dictionary) as? Options else {
            throw NSError(
                domain: "sentry",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create options from dictionary"]
            )
        }
        return result
    }
}
// swiftlint:enable missing_docs file_length
