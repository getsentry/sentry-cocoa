// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides session replay access for hybrid SDKs.
public struct SentryInternalReplayApi {

    typealias Dependencies = HubProviderProvider & ReplayIntegrationProviderProvider

    private let hubProvider: HubProvider
    private let replayIntegrationProvider: ReplayIntegrationProvider

    init(dependencies: Dependencies) {
        self.hubProvider = dependencies.hubProvider
        self.replayIntegrationProvider = dependencies.replayIntegrationProvider
    }

    /// Configures the session replay with a custom breadcrumb converter
    /// and/or screenshot provider.
    @_spi(Private)
    public func configure(
        breadcrumbConverter: SentryReplayBreadcrumbConverter?,
        screenshotProvider: SentryViewScreenshotProvider?
    ) {
        replayIntegrationProvider.getReplayIntegration()?.configureReplayWith(
            breadcrumbConverter,
            screenshotProvider: screenshotProvider
        )
    }

    /// Captures a replay event. Returns `true` if the replay was captured.
    @discardableResult
    public func capture() -> Bool {
        replayIntegrationProvider.getReplayIntegration()?.captureReplay() ?? false
    }

    /// The current replay ID, or `nil` if no replay is active.
    public var replayId: String? {
        var result: String?
        hubProvider.configureScope { scope in
            result = scope.replayId
        }
        return result
    }

    /// Adds classes to the replay ignore list.
    public func addIgnoreClasses(_ classes: [AnyClass]) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.addIgnoreClasses(classes: classes)
    }

    /// Adds classes to the replay redact list.
    public func addRedactClasses(_ classes: [AnyClass]) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.addRedactClasses(classes: classes)
    }

    /// Sets the container class whose subviews are ignored during replay.
    public func setIgnoreContainerClass(_ containerClass: AnyClass) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.setIgnoreContainerClass(containerClass)
    }

    /// Sets the container class whose subviews are redacted during replay.
    public func setRedactContainerClass(_ containerClass: AnyClass) {
        replayIntegrationProvider.getReplayIntegration()?.viewPhotographer.setRedactContainerClass(containerClass)
    }

    /// Sets tags on the current replay session.
    public func setTags(_ tags: [String: Any]) {
        replayIntegrationProvider.getReplayIntegration()?.setReplayTags(tags)
    }
}

#endif
// swiftlint:enable missing_docs
