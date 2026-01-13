@_implementationOnly import _SentryPrivate

#if canImport(UIKit)
import UIKit
#endif

typealias AutoBreadcrumbTrackingIntegrationProvider = FileManagerProvider & NotificationCenterProvider

final class SentryAutoBreadcrumbTrackingIntegration<Dependencies: AutoBreadcrumbTrackingIntegrationProvider>: NSObject, SwiftIntegration, SentryBreadcrumbDelegate {
    private let options: Options
    private let fileManager: SentryFileManager
    private let notificationCenterWrapper: SentryNSNotificationCenterWrapper
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
        self.notificationCenterWrapper = dependencies.notificationCenterWrapper

        super.init()

        // Create breadcrumb tracker
        let breadcrumbTracker = SentryBreadcrumbTracker(reportAccessibilityIdentifier: options.reportAccessibilityIdentifier)
        self.breadcrumbTracker = breadcrumbTracker
        breadcrumbTracker.start(with: self)

        #if SENTRY_HAS_UIKIT
        if options.enableSwizzling {
            breadcrumbTracker.startSwizzle()
        }
        #endif // SENTRY_HAS_UIKIT

        #if os(iOS) && !SENTRY_NO_UIKIT
        // Create system event breadcrumbs for iOS
        // Note: SentrySystemEventBreadcrumbs is conditionally compiled, so we use performSelector
        guard let systemEventBreadcrumbsClass = NSClassFromString("SentrySystemEventBreadcrumbs") as? NSObject.Type,
              let allocated = systemEventBreadcrumbsClass.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let systemEventBreadcrumbs = allocated.perform(NSSelectorFromString("initWithFileManager:andNotificationCenterWrapper:"), with: fileManager, with: notificationCenterWrapper)?.takeUnretainedValue() as? SentrySystemEventBreadcrumbs else {
            SentrySDKLog.warning("Failed to create SentrySystemEventBreadcrumbs - class may not be available on this platform")
            return nil
        }
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
