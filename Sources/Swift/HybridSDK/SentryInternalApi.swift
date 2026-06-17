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
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    typealias Dependencies = BaseDependencies
        & SentryInternalPerformanceApi.Dependencies
        & SentryInternalScreenshotApi.Dependencies
        & SentryInternalViewHierarchyApi.Dependencies
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

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Frame tracking metrics for hybrid SDKs.
    public let performance: SentryInternalPerformanceApi
#endif

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
    /// Screenshot capture for hybrid SDKs.
    public let screenshot: SentryInternalScreenshotApi

    /// View hierarchy capture for hybrid SDKs.
    public let viewHierarchy: SentryInternalViewHierarchyApi
#endif

    init(dependencies: Dependencies) {
        self.sdk = SentryInternalSdkApi(dependencies: dependencies)
        self.debug = SentryInternalDebugApi(provider: dependencies)
        self.breadcrumbs = SentryInternalBreadcrumbApi(dependencies: dependencies)
        self.user = SentryInternalUserApi(dependencies: dependencies)
        self.envelope = SentryInternalEnvelopeApi(dependencies: dependencies)
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        self.performance = SentryInternalPerformanceApi(dependencies: dependencies)
#endif
#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
        self.screenshot = SentryInternalScreenshotApi(dependencies: dependencies)
        self.viewHierarchy = SentryInternalViewHierarchyApi(dependencies: dependencies)
#endif
    }
}
// swiftlint:enable missing_docs
