internal import _SentryPrivate

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
typealias AutoBreadcrumbTrackingIntegrationProvider = SentryUIDeviceWrapperProvider & FileManagerProvider & NotificationCenterProvider & ReplayIntegrationProviderProvider
#elseif (os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
typealias AutoBreadcrumbTrackingIntegrationProvider = FileManagerProvider & ReplayIntegrationProviderProvider
#else
typealias AutoBreadcrumbTrackingIntegrationProvider = FileManagerProvider
#endif

final class SentryAutoBreadcrumbTrackingIntegration<Dependencies: AutoBreadcrumbTrackingIntegrationProvider>: NSObject, SwiftIntegration, SentryBreadcrumbDelegate {
    private var breadcrumbTracker: SentryBreadcrumbTracker?

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    private var systemEventBreadcrumbs: SentrySystemEventBreadcrumbs?
    #endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoBreadcrumbTracking else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoBreadcrumbTracking is disabled.")
            return nil
        }

        guard let fileManager = dependencies.fileManager else {
            SentrySDKLog.fatal("File manager is not available")
            return nil
        }

        super.init()

        // Create breadcrumb tracker
#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
        let reportAccessibilityIdentifier = options.reportAccessibilityIdentifier
        #else
        let reportAccessibilityIdentifier = false
#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        let isSessionReplayConfigured = Self.isSessionReplayConfigured(options.sessionReplay)
        let replayIntegrationProvider = dependencies.replayIntegrationProvider
        let breadcrumbTracker = SentryBreadcrumbTracker(
            reportAccessibilityIdentifier: reportAccessibilityIdentifier,
            redactOptions: options.sessionReplay,
            shouldApplyRedaction: {
                isSessionReplayConfigured
                    || replayIntegrationProvider.getReplayIntegration()?.sessionReplay != nil
            },
            redactBuilderProvider: {
                replayIntegrationProvider.getReplayIntegration()?
                    .viewPhotographer.redactBuilderForTextExtraction
            }
        )
#else
        let breadcrumbTracker = SentryBreadcrumbTracker(
            reportAccessibilityIdentifier: reportAccessibilityIdentifier
        )
#endif
        self.breadcrumbTracker = breadcrumbTracker
        breadcrumbTracker.start(with: self)

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        if options.enableSwizzling {
            breadcrumbTracker.startSwizzle()
        }
        #endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

        #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
        let systemEventBreadcrumbs = SentrySystemEventBreadcrumbs(
            currentDeviceProvider: dependencies,
            fileManager: fileManager,
            notificationCenterWrapper: dependencies.notificationCenterWrapper
        )
        self.systemEventBreadcrumbs = systemEventBreadcrumbs
        systemEventBreadcrumbs.start(with: self)
        #endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private static func isSessionReplayConfigured(_ options: SentryReplayOptions) -> Bool {
        options.sessionSampleRate > 0 || options.onErrorSampleRate > 0
    }
#endif

    func uninstall() {
        breadcrumbTracker?.stop()
        breadcrumbTracker = nil
        
        #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
        systemEventBreadcrumbs?.stop()
        systemEventBreadcrumbs = nil
        #endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    }

    static var name: String {
        "SentryAutoBreadcrumbTrackingIntegration"
    }

    // MARK: - SentryBreadcrumbDelegate

    @objc(addBreadcrumb:)
    func add(_ crumb: Breadcrumb) {
        SentrySDKInternal.addBreadcrumb(crumb)
    }
}
