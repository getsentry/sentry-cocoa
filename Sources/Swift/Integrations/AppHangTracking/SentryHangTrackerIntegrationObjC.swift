// swiftlint:disable missing_docs
@_spi(Private) @objc public final class SentryHangTrackerIntegrationObjC: NSObject, SwiftIntegration {

    private let integration: SentryHangTrackingIntegration<SentryDependencyContainer>

    init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard let integration = SentryHangTrackingIntegration(with: options, dependencies: dependencies) else {
            return nil
        }
        self.integration = integration
    }

    @objc public func pauseAppHangTracking() {
        integration.pauseAppHangTracking()
    }

    @objc public func resumeAppHangTracking() {
        integration.resumeAppHangTracking()
    }

    static var name: String {
        SentryHangTrackingIntegration<SentryDependencyContainer>.name
    }

    public func uninstall() {
        integration.uninstall()
    }
}
// swiftlint:enable missing_docs
