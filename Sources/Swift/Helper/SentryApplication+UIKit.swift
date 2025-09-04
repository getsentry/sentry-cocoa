#if !os(macOS) && !os(watchOS) && !SENTRY_NO_UIKIT
import UIKit

@objc @_spi(Private) extension UIApplication: SentryApplication {

    @objc public func getWindows() -> [UIWindow]? {
        internal_getWindows()
    }
    
    @objc public func relevantViewControllersNames() -> [String]? {
        internal_relevantViewControllersNames()
    }
    
    @objc public var unsafeApplicationState: State {
        applicationState
    }
    
    @objc public var mainThread_isActive: Bool {
        unsafeApplicationState == .active
    }
}

extension SentryApplication {
    // This cannot be declared with @objc so until we delete more ObjC code it needs a separate
    // function than the objc visible one.
    public func internal_getWindows() -> [UIWindow]? {
        var windows = Set<UIWindow>()
        Dependencies.dispatchQueueWrapper.dispatchSyncOnMainQueue({ [weak self] in
            guard let self else { return }
            if #available(iOS 13.0, tvOS 13.0, *) {
                let scenes = connectedScenes
                for scene in scenes {
                    if scene.activationState == .foregroundActive {
                        if
                            let delegate = scene.delegate as? UIWindowSceneDelegate,
                            let window = delegate.window {
                            if let window {
                                windows.insert(window)
                            }
                        }
                    }
                }
            }

            if let window = delegate?.window {
                if let window {
                    windows.insert(window)
                }
            }
        }, timeout: 0.01)
        return Array(windows)
    }
    
    // This cannot be declared with @objc so until we delete more ObjC code it needs a separate
    // function than the objc visible one.
    public func internal_relevantViewControllersNames() -> [String]? {
        var result: [String]?
        Dependencies.dispatchQueueWrapper.dispatchSyncOnMainQueue({ [weak self] in
            guard let self else { return }
            let viewControllers = self.relevantviewControllers() ?? []
            result = viewControllers.map { SwiftDescriptor.getViewControllerClassName($0) }
        }, timeout: 0.01)
        return result
    }
    
    private func relevantviewControllers() -> [UIViewController]? {
        let windows = getWindows()
        guard !(windows?.isEmpty ?? true) else { return nil }
        
        return windows?.compactMap { relevantViewControllerFromWindow($0) }.flatMap { $0 }
    }
    
    private func relevantViewControllerFromWindow(_ window: UIWindow) -> [UIViewController]? {
        let viewController = window.rootViewController
        guard let viewController else { return nil }
        
        var result = [UIViewController]()
        result.append(viewController)
        var index = 0
        while index < result.count {
            let topVC = result[index]
            // If the view controller is presenting another one, usually in a modal form.
            if let presented = topVC.presentedViewController {
                if presented is UIAlertController {
                    break
                }
                result[index] = presented
                continue
            }
            
            // The top view controller is meant for navigation and not content
            if isContainerViewController(topVC) {
                if let contentViewController = relevantViewControllerFromContainer(topVC), contentViewController.count > 0 {
                    result.remove(at: index)
                    result.append(contentsOf: contentViewController)
                } else {
                    break
                }
                continue
            }
            
            var relevantChild: UIViewController?
            for childVC in topVC.children {
                // Sometimes a view controller is used as container for a navigation controller
                // If the navigation is occupying the whole view controller we will consider this the
                // case.
                if isContainerViewController(childVC), childVC.isViewLoaded, childVC.view.frame == topVC.view.bounds {
                    relevantChild = childVC
                    break
                }
            }
            if let relevantChild {
                result[index] = relevantChild
            }
            
            index += 1
        }
        return result
    }
    
    func relevantViewControllerFromContainer(_ vc: UIViewController) -> [UIViewController]? {
        if let navigationController = vc as? UINavigationController {
            return navigationController.topViewController.map { [$0] }
        }
        if let tabBarController = vc as? UITabBarController {
            let selectedIndex = tabBarController.selectedIndex
            if let vcs = tabBarController.viewControllers, vcs.count > selectedIndex {
                return [vcs[selectedIndex]]
            } else {
                return nil
            }
        }
        if let splitViewController = vc as? UISplitViewController {
            if splitViewController.viewControllers.count > 0 {
                return splitViewController.viewControllers
            }
        }
        
        if let pageViewController = vc as? UIPageViewController {
            if let vcs = pageViewController.viewControllers, vcs.count > 0 {
                return [vcs[0]]
            }
        }

        return nil
    }
    
    func isContainerViewController(_ vc: UIViewController) -> Bool {
        return vc is UINavigationController || vc is UITabBarController || vc is UISplitViewController || vc is UIPageViewController
    }
}
#endif
