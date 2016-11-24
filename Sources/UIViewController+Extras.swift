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
        
        swizzlinger(self)
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
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            let swizzledSelector = #selector(UIApplication.sentryClient_sendEvent(_:))
    
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
    
    func sentryClient_sendEvent(_ event: UIEvent) {
        #if swift(>=3.0)
        if let touches = event.allTouches {
            for touch in touches.enumerated() {
                if touch.element.phase == .cancelled || touch.element.phase == .ended {
                    print("\(touch.element.view)")
                    if let view = touch.element.view {
                        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation",
                                                                        message: "Tap",
                                                                        type: "navigation",
                                                                        data: ["View": "\(view)"]))
                    }
                }
            }
        }
        #else
            if let touches = event.allTouches() {
                for touch in touches.enumerate() {
                    if touch.element.phase == .Cancelled || touch.element.phase == .Ended {
                        print("\(touch.element.view)")
                        if let view = touch.element.view {
                            SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation",
                                                                            message: "Tap",
                                                                            type: "navigation",
                                                                            data: ["View": "\(view)"]))
                        }
                    }
                }
            }
        #endif
        sentryClient_sendEvent(event)
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
    
        swizzling(self)
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
        print("Tracked view controller: \(className)")
        SentryClient.shared?.breadcrumbs.add(Breadcrumb(category: "navigation",
                                                        message: "ViewDidAppear",
                                                        type: "navigation",
                                                        data: ["Controller": "\(className)"]))
        
        print("\(SentryClient.shared?.breadcrumbs.serialized)")
        sentryClient_viewDidAppear(animated)
    }
}

#if swift(>=3.0)
fileprivate let swizzling: (UIViewController.Type) -> () = { viewController in
    let originalSelector = #selector(UIViewController.viewDidAppear(_:))
    let swizzledSelector = #selector(UIViewController.sentryClient_viewDidAppear(_:))
    
    let originalMethod = class_getInstanceMethod(viewController, originalSelector)
    let swizzledMethod = class_getInstanceMethod(viewController, swizzledSelector)
    
    let didAddMethod = class_addMethod(viewController, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    
    if didAddMethod {
        class_replaceMethod(viewController, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
    
fileprivate let swizzlinger: (UIApplication.Type) -> () = { application in
    let originalSelector = #selector(UIApplication.sendEvent(_:))
    let swizzledSelector = #selector(UIApplication.sentryClient_sendEvent(_:))
    
    let originalMethod = class_getInstanceMethod(application, originalSelector)
    let swizzledMethod = class_getInstanceMethod(application, swizzledSelector)
    
    let didAddMethod = class_addMethod(application, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    
    if didAddMethod {
        class_replaceMethod(application, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
#endif
