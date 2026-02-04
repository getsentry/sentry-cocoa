// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

/// Helper class to provide typed access to hang tracking integration.
/// This bridges ObjC code to the Swift IntegrationRegistry.
@_spi(Private) @objc public final class SentryHangTrackingHelper: NSObject {
    
    @_spi(Private) @objc public static func getHangTrackerIntegration() -> SentryHangTrackerIntegrationObjC? {
        SentrySDKInternal.currentHub().integrationRegistry.getIntegration(SentryHangTrackerIntegrationObjC.self)
    }
}
// swiftlint:enable missing_docs
