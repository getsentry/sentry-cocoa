//
//  UIViewController+Extras.swift
//  Sentry
//
//  Created by Daniel Griesser on 24/11/2016.
//
//

import Foundation
import UIKit

internal class SentrySwizzle {
    
    static private func setNewIMPWithBlock<T>(_ block: T, forSelector selector: Selector, toClass classToSwizzle: AnyClass) {
        let method = class_getInstanceMethod(classToSwizzle, selector)
        
        #if swift(>=3.0)
            let imp = imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        #else
            let imp = imp_implementationWithBlock(unsafeBitCast(block, AnyObject.self))
        #endif
        
        if !class_addMethod(classToSwizzle, selector, imp, method_getTypeEncoding(method)) {
            method_setImplementation(method, imp)
        }
    }
    
    static private func swizzle(class classToSwizzle: AnyClass, selector: Selector) {
        objc_sync_enter(classToSwizzle)
        defer { objc_sync_exit(classToSwizzle) }
        
        let originalIMP = class_getMethodImplementation(classToSwizzle, selector)
        
        switch classToSwizzle {
        case is UIApplication.Type:
            typealias UIApplicationSendAction = @convention(c) (AnyObject, Selector, Selector, AnyObject?, AnyObject?, UIEvent?) -> Bool
            #if swift(>=3.0)
                let origIMPC = unsafeBitCast(originalIMP, to: UIApplicationSendAction.self)
            #else
                let origIMPC = unsafeBitCast(originalIMP, UIApplicationSendAction.self)
            #endif
            let block: @convention(block) (AnyObject, Selector, AnyObject?, AnyObject?, UIEvent?) -> Bool = {
                trackSendAction($1, to: $2, from: $3, for: $4)
                return origIMPC($0, selector, $1, $2, $3, $4)
            }
            setNewIMPWithBlock(block, forSelector: selector, toClass: classToSwizzle)
        case is UIViewController.Type:
            typealias UIViewControllerViewDidAppear = @convention(c) (AnyObject, Selector, Bool) -> Void
            #if swift(>=3.0)
                let origIMPC = unsafeBitCast(originalIMP, to: UIViewControllerViewDidAppear.self)
            #else
                let origIMPC = unsafeBitCast(originalIMP, UIViewControllerViewDidAppear.self)
            #endif
            let block: @convention(block) (AnyObject, Bool) -> Void = {
                if let viewController = $0 as? UIViewController {
                    trackViewDidAppear(viewController)
                }
                origIMPC($0, selector, $1)
            }
            setNewIMPWithBlock(block, forSelector: selector, toClass: classToSwizzle)
        default:
            break
        }
    }
    
    static func enableAutomaticBreadcrumbTracking() {
        struct Static {
            static var token: Int = 0
        }
        
        guard Static.token == 0 else { return }
        
        #if swift(>=3.0)
            Static.token = 1
            swizzle(class: UIApplication.self, selector: #selector(UIApplication.sendAction(_:to:from:for:)))
            swizzle(class: UIViewController.self, selector: #selector(UIViewController.viewDidAppear(_:)))
        #else
            dispatch_once(&Static.token) {
                swizzle(class: UIApplication.self, selector: #selector(UIApplication.sendAction(_:to:from:forEvent:)))
                swizzle(class: UIViewController.self, selector: #selector(UIViewController.viewDidAppear(_:)))
            }
        #endif
    }
    
    static private func trackSendAction(_ action: Selector, to target: AnyObject?, from sender: AnyObject?, for event: UIEvent?) {
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
        
        SentryClient.shared?.breadcrumbs.add(
            Breadcrumb(
                category: "action",
                message: "\(action)",
                type: "navigation",
                data: data
            )
        )
    }
    
    static private func trackViewDidAppear(_ controller: UIViewController) {
        SentryClient.shared?.breadcrumbs.add(
            Breadcrumb(
                category: "navigation",
                message: "ViewDidAppear",
                type: "navigation",
                data: ["controller": "\(controller)"]
            )
        )
    }
    
}
