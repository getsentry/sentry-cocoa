// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
public struct SentryInternalApi {

    typealias BaseDependencies = SentryInternalSdkApi.Dependencies
        & SentryInternalDebugApi.Dependencies
        & SentryInternalBreadcrumbApi.Dependencies
        & SentryInternalUserApi.Dependencies
        & SentryInternalEnvelopeApi.Dependencies
        & HubProvider
        & ClientProvider
        & OptionsDeserializerProvider
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    typealias Dependencies = BaseDependencies
        & SentryInternalPerformanceApi.Dependencies
        & SentryInternalScreenshotApi.Dependencies
        & SentryInternalViewHierarchyApi.Dependencies
        & SentryInternalScreenApi.Dependencies
        & SentryInternalReplayApi.Dependencies
#elseif os(visionOS) && !SENTRY_NO_UI_FRAMEWORK
    typealias Dependencies = BaseDependencies
        & SentryInternalPerformanceApi.Dependencies
#else
    typealias Dependencies = BaseDependencies
#endif

    /// SDK metadata and configuration.
    public let sdk: SentryInternalSdkApi

    /// Debug image access for symbolication.
    public let debug: SentryInternalDebugApi

    /// Breadcrumb creation from dictionary representation.
    public let breadcrumbs: SentryInternalBreadcrumbApi

    /// User creation from dictionary representation.
    public let user: SentryInternalUserApi

    /// Envelope store, capture, and deserialization for hybrid SDKs.
    public let envelope: SentryInternalEnvelopeApi

    private let hub: Hub
    private let clientProvider: any ClientProvider
    private let optionsDeserializer: OptionsDeserializer

    /// Method swizzling for hybrid SDKs.
    public let swizzle: SentryInternalSwizzleApi

    /// App start measurement for hybrid SDKs.
    public let appStart: SentryInternalAppStartApi

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Frame tracking metrics for hybrid SDKs.
    public let performance: SentryInternalPerformanceApi
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Screenshot capture for hybrid SDKs.
    public let screenshot: SentryInternalScreenshotApi

    /// View hierarchy capture for hybrid SDKs.
    public let viewHierarchy: SentryInternalViewHierarchyApi

    /// Screen name tracking for hybrid SDKs.
    public let screen: SentryInternalScreenApi

    /// Session replay for hybrid SDKs.
    public let replay: SentryInternalReplayApi
#endif

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    /// Profiling for hybrid SDKs.
    public let profiling: SentryInternalProfilingApi
#endif

    /// Sets the current trace and span on the scope's propagation context.
    public func setTrace(_ traceId: SentryId, spanId: SpanId) {
        hub.setTrace(traceId, spanId: spanId)
    }

    /// Sets a custom log output handler for SDK log messages.
    public func setLogOutput(_ output: ((String) -> Void)?) {
        SentrySDKLog.setOutput(output)
    }

    /// Tells the crash reporter to ignore the next occurrence of the given signal on the calling thread.
    public func ignoreNextSignal(_ signum: Int32) {
        sentrycrash_ignore_next_signal(signum)
    }

    /// Returns the current SDK options, or a default instance if the SDK has not been started.
    public var options: Options {
        clientProvider.client?.options as? Options ?? Options()
    }

    /// Creates SDK options from a dictionary representation.
    public func options(fromDictionary dictionary: [String: Any]) throws -> Options {
        try optionsDeserializer.options(from: dictionary)
    }

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
        self.clientProvider = dependencies
        self.optionsDeserializer = dependencies.optionsDeserializer
        self.sdk = SentryInternalSdkApi(dependencies: dependencies)
        self.debug = SentryInternalDebugApi(provider: dependencies)
        self.breadcrumbs = SentryInternalBreadcrumbApi(dependencies: dependencies)
        self.user = SentryInternalUserApi(dependencies: dependencies)
        self.envelope = SentryInternalEnvelopeApi(dependencies: dependencies)
        self.swizzle = SentryInternalSwizzleApi()
        self.appStart = SentryInternalAppStartApi()
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        self.performance = SentryInternalPerformanceApi(dependencies: dependencies)
#endif
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        self.screenshot = SentryInternalScreenshotApi(dependencies: dependencies)
        self.viewHierarchy = SentryInternalViewHierarchyApi(dependencies: dependencies)
        self.screen = SentryInternalScreenApi(dependencies: dependencies)
        self.replay = SentryInternalReplayApi(dependencies: dependencies)
#endif
#if !(os(watchOS) || os(tvOS) || os(visionOS))
        self.profiling = SentryInternalProfilingApi()
#endif
    }
}
// swiftlint:enable missing_docs
