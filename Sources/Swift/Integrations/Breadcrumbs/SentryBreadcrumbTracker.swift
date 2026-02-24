// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

#if (os(macOS) || targetEnvironment(macCatalyst)) && !SENTRY_NO_UI_FRAMEWORK
import Cocoa
#endif

@objc @_spi(Private) public final class SentryBreadcrumbTracker: NSObject {
    
    private static let swizzleSendActionKey = "SentryBreadcrumbTrackerSwizzleSendAction"
    // Use a static variable to hold a unique pointer for the swizzle key
    // Similar to Objective-C's `static const void *key = &key;` pattern
    private static var swizzleViewDidAppearKeyStorage: UInt8 = 0
    private static var swizzleViewDidAppearKey: UnsafeRawPointer = {
        return withUnsafePointer(to: &swizzleViewDidAppearKeyStorage) { UnsafeRawPointer($0) }
    }()
    
    private weak var delegate: SentryBreadcrumbDelegate?
    private let reportAccessibilityIdentifier: Bool
    
    // Store notification observer tokens for cleanup
    private var notificationObservers: [NSObjectProtocol] = []
    
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
    
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    @objc
    func startSwizzle() {
        swizzleSendAction()
        swizzleViewDidAppear()
    }
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    
    @objc
    func stop() {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeSwizzleSendAction(forKey: Self.swizzleSendActionKey)
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        
        // Remove all notification observers
        let notificationCenter = NotificationCenter.default
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        delegate = nil
        stopTrackNetworkConnectivityChanges()
    }
    
    private func trackApplicationNotifications() {
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
        trackApplicationNotificationsUIKit()
#elseif os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        trackApplicationNotificationsMacOS()
#else // watchOS or other platforms
        SentrySDKLog.debug("NO UIKit, macOS and Catalyst -> [SentryBreadcrumbTracker trackApplicationNotifications] does nothing.")
#endif
    }
    
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    private func trackApplicationNotificationsUIKit() {
        let notificationCenter = NotificationCenter.default
        
        // not available for macOS
        let memoryWarningObserver = notificationCenter.addObserver(
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
        notificationObservers.append(memoryWarningObserver)
        
        let backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "background")
        }
        notificationObservers.append(backgroundObserver)
        
        let foregroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "foreground")
        }
        notificationObservers.append(foregroundObserver)
    }
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    
#if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
    private func trackApplicationNotificationsMacOS() {
        let notificationCenter = NotificationCenter.default
        
        // Will resign Active notification is the nearest one to
        // UIApplicationDidEnterBackgroundNotification
        let backgroundObserver = notificationCenter.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "background")
        }
        notificationObservers.append(backgroundObserver)
        
        let foregroundObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self = self else { return }
            self.addBreadcrumb(type: "navigation", category: "app.lifecycle", level: .info, dataKey: "state", dataValue: "foreground")
        }
        notificationObservers.append(foregroundObserver)
    }
#endif // os(macOS)
    
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
    
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
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
    
    @_spi(Private)
    public static func extractData(from view: UIView, includeAccessibilityIdentifier: Bool) -> [String: Any] {
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
        
        if let title = controller.navigationItem.title, !title.isEmpty {
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
        
        // Access view to ensure it's loaded (triggers loadView() if view is nil)
        let view = controller.view
        if let window = view?.window {
            info["window"] = window.description
            info["window_isKeyWindow"] = window.isKeyWindow ? "true" : "false"
            info["window_windowLevel"] = String(describing: window.windowLevel.rawValue)
            info["is_window_rootViewController"] = (window.rootViewController == controller) ? "true" : "false"
        }
        
        return info
    }
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
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
