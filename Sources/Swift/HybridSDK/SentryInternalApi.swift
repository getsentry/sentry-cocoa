// swiftlint:disable missing_docs
internal import _SentryPrivate
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
        & SentryInternalScopeApi.Dependencies
        & OptionsDeserializerProvider
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    typealias UIDependencies = BaseDependencies
        & SentryInternalPerformanceApi.Dependencies
        & SentryInternalScreenApi.Dependencies
        & SentryInternalScreenshotApi.Dependencies
        & SentryInternalReplayApi.Dependencies
    #if (os(iOS) || os(tvOS) || os(visionOS))
    typealias Dependencies = UIDependencies
        & SentryInternalViewHierarchyApi.Dependencies
    #else
    typealias Dependencies = UIDependencies
    #endif
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

    /// Access to current scope
    public let scope: SentryInternalScopeApi

    /// Serialization of data types
    public let serializer: SentryInternalSerializerApi

    private let hub: Hub
    private let optionsDeserializer: OptionsDeserializer

    /// Method swizzling for hybrid SDKs.
    public let swizzle: SentryInternalSwizzleApi

    /// App start measurement for hybrid SDKs.
    public let appStart: SentryInternalAppStartApi

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Frame tracking metrics for hybrid SDKs.
    public let performance: SentryInternalPerformanceApi

    /// Screen name tracking for hybrid SDKs.
    public let screen: SentryInternalScreenApi

    /// Session replay for hybrid SDKs.
    public let replay: SentryInternalReplayApi

    /// Screenshot capture for hybrid SDKs.
    public let screenshot: SentryInternalScreenshotApi

    #if (os(iOS) || os(tvOS) || os(visionOS))
    /// View hierarchy capture for hybrid SDKs.
    public let viewHierarchy: SentryInternalViewHierarchyApi
    #endif
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
#if !SENTRY_DISABLE_SENTRYCRASH_V10
        sentrycrash_ignore_next_signal(signum)
#else
        // KSCRASH_TODO(GH-8797): V10 cannot yet suppress the next signal on this thread, so this
        // downstream SPI is temporarily a no-op. Acceptance: SCV10-007 in
        // SENTRYCRASH_V10_MIGRATION_LEDGER.md.
        _ = signum
#endif
    }

    /// Returns the current SDK options, or a default instance if the SDK has not been started.
    public var options: Options {
        hub.options
    }

    /// Creates SDK options from a dictionary representation.
    public func options(fromDictionary dictionary: [String: Any]) throws -> Options {
        try optionsDeserializer.options(from: dictionary)
    }

    init(dependencies: Dependencies) {
        self.hub = dependencies.hub
        self.optionsDeserializer = dependencies.optionsDeserializer
        self.sdk = SentryInternalSdkApi(dependencies: dependencies)
        self.debug = SentryInternalDebugApi(provider: dependencies)
        self.breadcrumbs = SentryInternalBreadcrumbApi(dependencies: dependencies)
        self.user = SentryInternalUserApi(dependencies: dependencies)
        self.envelope = SentryInternalEnvelopeApi(dependencies: dependencies)
        self.scope = SentryInternalScopeApi(dependencies: dependencies)
        self.serializer = SentryInternalSerializerApi()
        self.swizzle = SentryInternalSwizzleApi()
        self.appStart = SentryInternalAppStartApi()
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        self.performance = SentryInternalPerformanceApi(dependencies: dependencies)
        self.screen = SentryInternalScreenApi(dependencies: dependencies)
        self.replay = SentryInternalReplayApi(dependencies: dependencies)
        self.screenshot = SentryInternalScreenshotApi(dependencies: dependencies)
        #if (os(iOS) || os(tvOS) || os(visionOS))
        self.viewHierarchy = SentryInternalViewHierarchyApi(dependencies: dependencies)
        #endif
#endif
#if !(os(watchOS) || os(tvOS) || os(visionOS))
        self.profiling = SentryInternalProfilingApi()
#endif
    }
}
// swiftlint:enable missing_docs
