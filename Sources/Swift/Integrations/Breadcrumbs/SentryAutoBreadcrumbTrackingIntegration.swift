@_implementationOnly import _SentryPrivate

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS) && !SENTRY_NO_UIKIT
typealias AutoBreadcrumbTrackingIntegrationProvider = UICurrentDeviceProvider & FileManagerProvider & NotificationCenterProvider
#else
typealias AutoBreadcrumbTrackingIntegrationProvider = UICurrentDeviceProvider & FileManagerProvider
#endif

final class SentryAutoBreadcrumbTrackingIntegration<Dependencies: AutoBreadcrumbTrackingIntegrationProvider>: NSObject, SwiftIntegration, SentryBreadcrumbDelegate {
    private let options: Options
    private let fileManager: SentryFileManager
    private var breadcrumbTracker: SentryBreadcrumbTracker?

    #if os(iOS) && !SENTRY_NO_UIKIT
    private var systemEventBreadcrumbs: SentrySystemEventBreadcrumbs?
    #endif // os(iOS) && !SENTRY_NO_UIKIT

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAutoBreadcrumbTracking else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableAutoBreadcrumbTracking is disabled.")
            return nil
        }

        guard let fileManager = dependencies.fileManager else {
            SentrySDKLog.fatal("File manager is not available")
            return nil
        }

        self.options = options
        self.fileManager = fileManager

        super.init()

        // Create breadcrumb tracker
#if os(iOS) && !SENTRY_NO_UIKIT
        let reportAccessibilityIdentifier = options.reportAccessibilityIdentifier
        #else
        let reportAccessibilityIdentifier = false
#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
        let breadcrumbTracker = SentryBreadcrumbTracker(reportAccessibilityIdentifier: reportAccessibilityIdentifier)
        self.breadcrumbTracker = breadcrumbTracker
        breadcrumbTracker.start(with: self)

        #if SENTRY_HAS_UIKIT
        if options.enableSwizzling {
            breadcrumbTracker.startSwizzle()
        }
        #endif // SENTRY_HAS_UIKIT

        #if os(iOS) && !SENTRY_NO_UIKIT
        let systemEventBreadcrumbs = SentrySystemEventBreadcrumbs(
            currentDeviceProvider: dependencies,
            fileManager: fileManager,
            notificationCenterWrapper: dependencies.notificationCenterWrapper
        )
        self.systemEventBreadcrumbs = systemEventBreadcrumbs
        systemEventBreadcrumbs.start(with: self)
        #endif // os(iOS) && !SENTRY_NO_UIKIT
    }

    func uninstall() {
        breadcrumbTracker?.stop()
        breadcrumbTracker = nil
        
        #if os(iOS) && !SENTRY_NO_UIKIT
        systemEventBreadcrumbs?.stop()
        systemEventBreadcrumbs = nil
        #endif // os(iOS) && !SENTRY_NO_UIKIT
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
