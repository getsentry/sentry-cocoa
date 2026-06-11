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
@_spi(Private) public final class SentryInternalReplayApi {

    /// Configures session replay with a different breadcrumb converter
    /// and/or screenshot provider.
    /// Passing nil keeps the previous value.
    public func configure(
        breadcrumbConverter: SentryReplayBreadcrumbConverter?,
        screenshotProvider: SentryViewScreenshotProvider?
    ) {
        PrivateSentrySDKOnly.configureSessionReplay(
            with: breadcrumbConverter,
            screenshotProvider: screenshotProvider
        )
    }

    /// Captures a replay. Returns `true` if a replay integration is
    /// installed and the capture succeeded.
    @discardableResult
    public func capture() -> Bool {
        guard let integration = getReplayIntegration() else { return false }
        return integration.captureReplay()
    }

    /// The current replay ID, or `nil` if no replay session is active.
    public var replayId: String? {
        PrivateSentrySDKOnly.getReplayId()
    }

    /// Adds classes whose views should be ignored during replay recording.
    public func addIgnoreClasses(_ classes: [AnyClass]) {
        PrivateSentrySDKOnly.addReplayIgnoreClasses(classes)
    }

    /// Adds classes whose views should be redacted during replay recording.
    public func addRedactClasses(_ classes: [AnyClass]) {
        PrivateSentrySDKOnly.addReplayRedactClasses(classes)
    }

    /// Sets the container class used to determine which views to ignore.
    public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        PrivateSentrySDKOnly.setIgnoreContainerClass(containerClass)
    }

    /// Sets the container class used to determine which views to redact.
    public func setRedactContainerClass(_ containerClass: AnyClass) {
        PrivateSentrySDKOnly.setRedactContainerClass(containerClass)
    }

    /// Sets custom tags on the replay session.
    public func setTags(_ tags: [String: Any]) {
        PrivateSentrySDKOnly.setReplayTags(tags)
    }

    // MARK: - Private

    private func getReplayIntegration() -> SentrySessionReplayIntegration? {
        let integrations = SentrySDKInternal.currentHub().installedIntegrations
        for integration in integrations {
            if let replay = integration as? SentrySessionReplayIntegration {
                return replay
            }
        }
        return nil
    }
}
#endif
// swiftlint:enable missing_docs
