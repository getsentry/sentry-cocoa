//
//  UIViewController+Extras.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/11/2016.
//
//

import Foundation
import UIKit

extension UIApplication {
    #if swift(>=3.0)
    open override class func initialize() {
        struct Static {
            static var token: Int = 0
        }
        
        // make sure this isn't a subclass
        if self !== UIApplication.self {
            return
        }
        
        sentrySwizzle(self, #selector(UIApplication.sendAction(_:to:from:for:)), #selector(UIApplication.sentryClient_sendAction(_:to:from:for:)))
    }
    #else
    public override class func initialize() {
        struct Static {
            static var token: Int = 0
        }
    
        // make sure this isn't a subclass
        if self !== UIApplication.self {
            return
        }
    
        dispatch_once(&Static.token) {
            let originalSelector = #selector(UIApplication.sendAction(_:to:from:for:))
            let swizzledSelector = #selector(UIApplication.sentryClient_sendAction(_:to:from:for:))
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
    
            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }
    #endif
    
    func sentryClient_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        var data: [String: String] = [:]
        #if swift(>=3.0)
            if let touches = event?.allTouches {
                for touch in touches.enumerated() {
                    if touch.element.phase == .cancelled || touch.element.phase == .ended {
                        if let view = touch.element.view {
                            data = ["View": "\(view)"]
                        }
                    }
                }
            }
        #else
            if let touches = event?.allTouches() {
                for touch in touches.enumerate() {
                    if touch.element.phase == .Cancelled || touch.element.phase == .Ended {
                        if let view = touch.element.view {
                            data =  ["View": "\(view)"]
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
    
    #if swift(>=3.0)
    var className: String {
        return String(describing: type(of: self))
    }
    #else
    var className: String {
        return String(self.dynamicType)
    }
    #endif
    
}

extension UIViewController {
    
    #if swift(>=3.0)
    open override class func initialize() {
        struct Static {
            static var token: Int = 0
        }
    
        // make sure this isn't a subclass
        if self !== UIViewController.self {
            return
        }
    
        sentrySwizzle(self, #selector(UIViewController.viewDidAppear(_:)), #selector(UIViewController.sentryClient_viewDidAppear(_:)))
    }
    #else
    public override class func initialize() {
        struct Static {
            static var token: Int = 0
        }
    
        // make sure this isn't a subclass
        if self !== UIViewController.self {
            return
        }
    
        dispatch_once(&Static.token) {
            let originalSelector = #selector(UIViewController.viewDidAppear(_:))
            let swizzledSelector = #selector(UIViewController.sentryClient_viewDidAppear(_:))
            
            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            
            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }
    #endif
    
    func sentryClient_viewDidAppear(_ animated: Bool) {
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation",
                                                        message: "ViewDidAppear",
                                                        type: "navigation",
                                                        data: ["Controller": "\(className)"]))
        
        sentryClient_viewDidAppear(animated)
    }
}

#if swift(>=3.0)
    fileprivate let sentrySwizzle: (AnyClass, Selector, Selector) -> () = { object, originalSelector, swizzledSelector in
        let originalMethod = class_getInstanceMethod(object, originalSelector)
        let swizzledMethod = class_getInstanceMethod(object, swizzledSelector)
        
        let didAddMethod = class_addMethod(object, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(object, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
#endif
