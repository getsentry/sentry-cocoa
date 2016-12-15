//
//  UIViewController+Extras.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/11/2016.
//
//

import Foundation
import UIKit

internal class SentrySwizzle {
    static func enableAutomaticBreadcrumbTracking() {
        struct Static {
            static var token: Int = 0
        }
        
        guard Static.token == 0 else { return }
        
        #if swift(>=3.0)
            sentrySwizzle(UIViewController.self, #selector(UIViewController.viewDidAppear(_:)), #selector(UIViewController.sentryClient_viewDidAppear(_:)))
            sentrySwizzle(UIApplication.self, #selector(UIApplication.sendAction(_:to:from:for:)), #selector(UIApplication.sentryClient_sendAction(_:to:from:for:)))
            Static.token = 1
        #else
            dispatch_once(&Static.token) {
                let originalSelector = #selector(UIApplication.sendAction(_:to:from:forEvent:))
                let swizzledSelector = #selector(UIApplication.sentryClient_sendAction(_:to:from:for:))
                let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector)
                let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector)
                
                let didAddMethod = class_addMethod(UIApplication.self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
                
                if didAddMethod {
                    class_replaceMethod(UIApplication.self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
                } else {
                    method_exchangeImplementations(originalMethod, swizzledMethod)
                }
                
                let originalSelectorUIViewController = #selector(UIViewController.viewDidAppear(_:))
                let swizzledSelectorUIViewController = #selector(UIViewController.sentryClient_viewDidAppear(_:))
                
                let originalMethodUIViewController = class_getInstanceMethod(UIViewController.self, originalSelectorUIViewController)
                let swizzledMethodUIViewController = class_getInstanceMethod(UIViewController.self, swizzledSelectorUIViewController)
                
                let didAddMethodUIViewController = class_addMethod(
                    UIViewController.self,
                    originalSelectorUIViewController,
                    method_getImplementation(swizzledMethodUIViewController),
                    method_getTypeEncoding(swizzledMethodUIViewController)
                )
                
                if didAddMethodUIViewController {
                    class_replaceMethod(UIViewController.self, swizzledSelectorUIViewController, method_getImplementation(originalMethodUIViewController), method_getTypeEncoding(originalMethodUIViewController))
                } else {
                    method_exchangeImplementations(originalMethodUIViewController, swizzledMethodUIViewController)
                }
            }
        #endif
    }
}

extension UIApplication {
    @objc func sentryClient_sendAction(_ action: Selector, to target: AnyObject?, from sender: AnyObject?, for event: UIEvent?) -> Bool {
        var data: [String: String] = [:]
        #if swift(>=3.0)
            if let touches = event?.allTouches {
                for touch in touches.enumerated() {
                    if touch.element.phase == .cancelled || touch.element.phase == .ended {
                        if let view = touch.element.view {
                            data = ["view": "\(view)"]
                        }
                    }
                }
            }
        #else
            if let touches = event?.allTouches() {
                for touch in touches.enumerate() {
                    if touch.element.phase == .Cancelled || touch.element.phase == .Ended {
                        if let view = touch.element.view {
                            data =  ["view": "\(view)"]
                        }
                    }
                }
            }
        #endif
        
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "action",
                                                        message: "\(action)",
                                                        type: "navigation",
                                                        data: data))
        
        return sentryClient_sendAction(action, to: target, from: sender, for: event)
    }
}

extension UIViewController {
    func sentryClient_viewDidAppear(_ animated: Bool) {
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation",
                                                        message: "ViewDidAppear",
                                                        type: "navigation",
                                                        data: ["controller": "\(self)"]))
        
        sentryClient_viewDidAppear(animated)
    }
}

#if swift(>=3.0)
    fileprivate let sentrySwizzle: (AnyClass, Selector, Selector) -> () = { object, originalSelector, swizzledSelector in
        let originalMethod = class_getInstanceMethod(object, originalSelector)
        let swizzledMethod = class_getInstanceMethod(object, swizzledSelector)
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
#endif
