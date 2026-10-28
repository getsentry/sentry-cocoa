internal import _SentryPrivate

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

#if os(iOS) && !targetEnvironment(macCatalyst) && !SENTRY_NO_UI_FRAMEWORK
typealias AutoBreadcrumbTrackingIntegrationProvider = SentryUIDeviceWrapperProvider & FileManagerProvider & NotificationCenterProvider & HingeObserverProvider
#elseif os(iOS) && !SENTRY_NO_UI_FRAMEWORK
typealias AutoBreadcrumbTrackingIntegrationProvider = SentryUIDeviceWrapperProvider & FileManagerProvider & NotificationCenterProvider
#else
typealias AutoBreadcrumbTrackingIntegrationProvider = FileManagerProvider
#endif

final class SentryAutoBreadcrumbTrackingIntegration<Dependencies: AutoBreadcrumbTrackingIntegrationProvider>: NSObject, SwiftIntegration, SentryBreadcrumbDelegate {
    private var breadcrumbTracker: SentryBreadcrumbTracker?

    #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    private var systemEventBreadcrumbs: SentrySystemEventBreadcrumbs?
    #if !targetEnvironment(macCatalyst)
    private var hingeBreadcrumbs: SentryHingeBreadcrumbs?
    #endif // !targetEnvironment(macCatalyst)
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
        let breadcrumbTracker = SentryBreadcrumbTracker(reportAccessibilityIdentifier: reportAccessibilityIdentifier)
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

        #if !targetEnvironment(macCatalyst)
        // Apple doesn't provide any easy way to detect if the device has a hinge,
        // but it will never report a hinge state change if the device doesn't have a hinge.
        let hingeBreadcrumbs = SentryHingeBreadcrumbs(hingeObserver: dependencies.hingeObserver)
        self.hingeBreadcrumbs = hingeBreadcrumbs
        hingeBreadcrumbs.start(with: self)
        #endif // !targetEnvironment(macCatalyst)
        #endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
    }

    func uninstall() {
        breadcrumbTracker?.stop()
        breadcrumbTracker = nil
        
        #if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
        systemEventBreadcrumbs?.stop()
        systemEventBreadcrumbs = nil
        #if !targetEnvironment(macCatalyst)
        hingeBreadcrumbs?.stop()
        hingeBreadcrumbs = nil
        #endif // !targetEnvironment(macCatalyst)
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
