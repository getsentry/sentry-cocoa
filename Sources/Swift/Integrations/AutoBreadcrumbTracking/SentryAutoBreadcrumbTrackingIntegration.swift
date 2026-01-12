@_implementationOnly import _SentryPrivate

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
        let systemEventBreadcrumbs = SentrySystemEventBreadcrumbs(
            fileManager: fileManager,
            andNotificationCenterWrapper: notificationCenterWrapper
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

    func add(_ crumb: SentryBreadcrumb) {
        SentrySDKInternal.addBreadcrumb(crumb)
    }
}
