// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

#if SENTRY_TARGET_MACOS_HAS_UI
import Cocoa
#endif

@objc
@_spi(Private)
public final class SentryBreadcrumbTracker: NSObject {
    
    private static let swizzleSendActionKey = "SentryBreadcrumbTrackerSwizzleSendAction"
    // Use a static variable to hold a unique pointer for the swizzle key
    // Similar to Objective-C's `static const void *key = &key;` pattern
    private static var swizzleViewDidAppearKeyStorage: UInt8 = 0
    private static var swizzleViewDidAppearKey: UnsafeRawPointer = {
        return withUnsafePointer(to: &swizzleViewDidAppearKeyStorage) { UnsafeRawPointer($0) }
    }()
    
    private weak var delegate: SentryBreadcrumbDelegate?
    private let reportAccessibilityIdentifier: Bool
    
    @objc(initReportAccessibilityIdentifier:)
    init(reportAccessibilityIdentifier: Bool) {
        self.reportAccessibilityIdentifier = reportAccessibilityIdentifier
        super.init()
    }
    
    deinit {
        SentryDependencyContainer.sharedInstance().reachability.remove(self)
    }
    
    @objc(startWithDelegate:)
    func start(with delegate: SentryBreadcrumbDelegate) {
        self.delegate = delegate
        addEnabledCrumb()
        trackApplicationNotifications()
        trackNetworkConnectivityChanges()
    }
    
#if SENTRY_HAS_UIKIT
    @objc
    func startSwizzle() {
        swizzleSendAction()
        swizzleViewDidAppear()
    }
#endif // SENTRY_HAS_UIKIT
    
    @objc
    func stop() {
        // All breadcrumbs are guarded by checking the client of the current hub, which we remove when
        // uninstalling the SDK. Therefore, we don't clean up everything.
#if SENTRY_HAS_UIKIT
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeSwizzleSendAction(forKey: Self.swizzleSendActionKey)
#endif // SENTRY_HAS_UIKIT
        delegate = nil
        stopTrackNetworkConnectivityChanges()
    }
    
    private func trackApplicationNotifications() {
#if SENTRY_HAS_UIKIT
        trackApplicationNotificationsUIKit()
#elseif SENTRY_TARGET_MACOS_HAS_UI
        trackApplicationNotificationsMacOS()
#else // TARGET_OS_WATCH
        SentrySDKLog.debug("NO UIKit, OSX and Catalyst -> [SentryBreadcrumbTracker trackApplicationNotifications] does nothing.")
#endif // !TARGET_OS_WATCH
    }
    
#if SENTRY_HAS_UIKIT
    private func trackApplicationNotificationsUIKit() {
        let notificationCenter = NotificationCenter.default
        
        // not available for macOS
        _ = notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            let crumb = Breadcrumb(level: .warning, category: "device.event")
            crumb.type = "system"
            crumb.data = ["action": "LOW_MEMORY"]
            crumb.message = "Low memory"
            self.delegate?.add(crumb)
        }
        
        _ = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "background")
        }
        
        _ = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "foreground")
        }
    }
#endif // SENTRY_HAS_UIKIT
    
#if SENTRY_TARGET_MACOS_HAS_UI
    private func trackApplicationNotificationsMacOS() {
        let notificationCenter = NotificationCenter.default
        
        // Will resign Active notification is the nearest one to
        // UIApplicationDidEnterBackgroundNotification
        _ = notificationCenter.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "background")
        }
        
        _ = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "foreground")
        }
    }
#endif // SENTRY_TARGET_MACOS_HAS_UI
    
    private func trackNetworkConnectivityChanges() {
        SentryDependencyContainer.sharedInstance().reachability.add(self)
    }
    
    private func stopTrackNetworkConnectivityChanges() {
        SentryDependencyContainer.sharedInstance().reachability.remove(self)
    }
    
    private func addBreadcrumb(type: String, category: String, level: SentryLevel, dataKey: String, dataValue: String) {
        let crumb = Breadcrumb(level: level, category: category)
        crumb.type = type
        crumb.data = [dataKey: dataValue]
        delegate?.add(crumb)
    }
    
    private func addEnabledCrumb() {
        let crumb = Breadcrumb(level: .info, category: "started")
        crumb.type = "debug"
        crumb.message = "Breadcrumb Tracking"
        delegate?.add(crumb)
    }
    
#if SENTRY_HAS_UIKIT
    private static func avoidSender(_ sender: Any?, forTarget target: Any?, action: String) -> Bool {
        guard let sender = sender, let target = target else {
            return true
        }
        
        if let textField = sender as? UITextField {
            // This is required to avoid creating breadcrumbs for every key pressed in a text field.
            // Textfield may invoke many types of event, in order to check if is a
            // `UIControlEventEditingChanged` we need to compare the current action to all events
            // attached to the control. This may cause a false negative if the developer is using the
            // same action for different events, but this trade off is acceptable because using the same
            // action for `.editingChanged` and another event is not supposed to happen.
            let actions = textField.actions(forTarget: target, forControlEvent: .editingChanged)
            return actions?.contains(action) ?? false
        }
        return false
    }
    
    private func swizzleSendAction() {
        SentryDependencyContainer.sharedInstance().swizzleWrapper.swizzleSendAction(
            { [weak self] action, target, sender, event in
                guard let self = self else { return }
                
                if Self.avoidSender(sender, forTarget: target, action: action) {
                    return
                }
                
                var data: [String: Any]?
                if let event = event {
                    for touch in event.allTouches ?? [] {
                        if let view = touch.view,
                           touch.phase == .cancelled || touch.phase == .ended {
                            data = Self.extractData(from: view, includeAccessibilityIdentifier: self.reportAccessibilityIdentifier)
                        }
                    }
                }
                
                let crumb = Breadcrumb(level: .info, category: "touch")
                crumb.type = "user"
                crumb.message = action
                crumb.data = data
                self.delegate?.add(crumb)
            },
            forKey: Self.swizzleSendActionKey
        )
    }
    
    private func swizzleViewDidAppear() {
        SentrySwizzleWrapperHelper.swizzleViewDidAppear(
            { [weak self] viewController in
                guard let self = self else { return }
                
                let crumb = Breadcrumb(level: .info, category: "ui.lifecycle")
                crumb.type = "navigation"
                crumb.data = Self.fetchInfo(about: viewController)
                self.delegate?.add(crumb)
            },
            forKey: Self.swizzleViewDidAppearKey
        )
    }
    
    private static func extractData(from view: UIView, includeAccessibilityIdentifier: Bool) -> [String: Any] {
        var result: [String: Any] = ["view": String(describing: view)]
        
        if view.tag > 0 {
            result["tag"] = view.tag
        }
        
        if includeAccessibilityIdentifier,
           let identifier = view.accessibilityIdentifier,
           !identifier.isEmpty {
            result["accessibilityIdentifier"] = identifier
        }
        
        if let button = view as? UIButton,
           let title = button.currentTitle,
           !title.isEmpty {
            result["title"] = title
        }
        
        return result
    }
    
    private static func fetchInfo(about controller: UIViewController) -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["screen"] = SwiftDescriptor.getViewControllerClassName(controller)
        
        if !controller.navigationItem.title.isEmpty {
            info["title"] = controller.navigationItem.title
        } else if let title = controller.title, !title.isEmpty {
            info["title"] = title
        }
        
        info["beingPresented"] = controller.isBeingPresented ? "true" : "false"
        
        if let presentingViewController = controller.presentingViewController {
            info["presentingViewController"] = SwiftDescriptor.getViewControllerClassName(presentingViewController)
        }
        
        if let parentViewController = controller.parent {
            info["parentViewController"] = SwiftDescriptor.getViewControllerClassName(parentViewController)
        }
        
        if let window = controller.view.window {
            info["window"] = window.description
            info["window_isKeyWindow"] = window.isKeyWindow ? "true" : "false"
            info["window_windowLevel"] = String(window.windowLevel.rawValue)
            info["is_window_rootViewController"] = (window.rootViewController == controller) ? "true" : "false"
        }
        
        return info
    }
#endif // SENTRY_HAS_UIKIT
}

extension SentryBreadcrumbTracker: SentryReachabilityObserver {
    @objc
    public func connectivityChanged(_ connected: Bool, typeDescription: String) {
        let crumb = Breadcrumb(level: .info, category: "device.connectivity")
        crumb.type = "connectivity"
        crumb.data = ["connectivity": typeDescription]
        delegate?.add(crumb)
    }
}
// swiftlint:enable missing_docs
