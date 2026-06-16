// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides screen name tracking for hybrid SDKs.
public struct SentryInternalScreenApi {

    typealias Dependencies = HubProviderProvider

    private let hubProvider: HubProvider

    init(dependencies: Dependencies) {
        self.hubProvider = dependencies.hubProvider
    }

    /// Sets the current screen name on the SDK scope.
    public func setCurrent(_ screenName: String?) {
        hubProvider.configureScope { scope in
            scope.currentScreen = screenName
        }
    }
}

#endif
// swiftlint:enable missing_docs
