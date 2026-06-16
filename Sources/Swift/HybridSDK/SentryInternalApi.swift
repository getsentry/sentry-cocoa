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

    typealias Dependencies = SentryInternalSdkApi.Dependencies
        & SentryInternalDebugApi.Dependencies
        & SentryInternalBreadcrumbApi.Dependencies
        & SentryInternalUserApi.Dependencies

    /// SDK metadata and configuration.
    public let sdk: SentryInternalSdkApi

    /// Debug image access for symbolication.
    public let debug: SentryInternalDebugApi

    /// Breadcrumb creation from dictionary representation.
    public let breadcrumbs: SentryInternalBreadcrumbApi

    /// User creation from dictionary representation.
    public let user: SentryInternalUserApi

    init(dependencies: Dependencies) {
        self.sdk = SentryInternalSdkApi(dependencies: dependencies)
        self.debug = SentryInternalDebugApi(provider: dependencies)
        self.breadcrumbs = SentryInternalBreadcrumbApi(dependencies: dependencies)
        self.user = SentryInternalUserApi(dependencies: dependencies)
    }
}
// swiftlint:enable missing_docs
