import Foundation

extension SentrySDK {

    /// Entry point for APIs intended for Sentry hybrid SDKs.
    public static var `internal`: SentryInternalApi {
        SentryInternalApi(dependencies: SentryDependencyContainer.sharedInstance())
    }
}
