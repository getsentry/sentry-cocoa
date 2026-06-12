// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
import UIKit

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalScreenApi {

    private let hubProvider: any HubProvider

    init(provider: any HubProvider) {
        self.hubProvider = provider
    }

    /// Sets the name of the current screen on the scope.
    public func setCurrent(_ screenName: String?) {
        hubProvider.hub.configureScope { scope in
            scope.currentScreen = screenName
        }
    }
}
#endif
// swiftlint:enable missing_docs
