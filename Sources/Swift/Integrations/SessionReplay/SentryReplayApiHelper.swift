// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Helper class to provide typed access to session replay integration.
/// This bridges ObjC code to the Swift IntegrationRegistry.
@_spi(Private) @objc public final class SentryReplayApiHelper: NSObject {
    
    @_spi(Private) @objc public static func getSessionReplayIntegration() -> SentrySessionReplayIntegration? {
        SentrySDKInternal.currentHub().integrationRegistry.getIntegration(SentrySessionReplayIntegration.self)
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
